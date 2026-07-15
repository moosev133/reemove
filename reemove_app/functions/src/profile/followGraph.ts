import {
  FieldPath,
  getFirestore,
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {normalizeUsername} from "../account/usernamePolicy";
import {safeDocumentId} from "../feed/contentPolicy";
import {
  recordValue,
  sanitizedCallableProfile,
  type ProfileAudience,
} from "./profilePolicy";

type RelationshipState =
  "self" |
  "none" |
  "following" |
  "followedBy" |
  "mutual" |
  "requestSent" |
  "requestReceived" |
  "blocked" |
  "blockedBy";

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

function profileIdFrom(data: unknown): string {
  return safeDocumentId(recordValue(data).profileId, "profileId");
}

function followRequestId(requesterId: string, targetId: string): string {
  return `${requesterId}--${targetId}`;
}

function relationshipRefs(
  database: Firestore,
  viewerId: string,
  profileId: string,
): {
  viewerFollowing: DocumentReference<DocumentData>;
  profileFollowers: DocumentReference<DocumentData>;
  profileFollowing: DocumentReference<DocumentData>;
  viewerFollowers: DocumentReference<DocumentData>;
  sentRequest: DocumentReference<DocumentData>;
  receivedRequest: DocumentReference<DocumentData>;
  viewerBlock: DocumentReference<DocumentData>;
  profileBlock: DocumentReference<DocumentData>;
} {
  return {
    viewerFollowing: database.doc(
      `users/${viewerId}/following/${profileId}`,
    ),
    profileFollowers: database.doc(
      `users/${profileId}/followers/${viewerId}`,
    ),
    profileFollowing: database.doc(
      `users/${profileId}/following/${viewerId}`,
    ),
    viewerFollowers: database.doc(
      `users/${viewerId}/followers/${profileId}`,
    ),
    sentRequest: database.collection("follow_requests")
      .doc(followRequestId(viewerId, profileId)),
    receivedRequest: database.collection("follow_requests")
      .doc(followRequestId(profileId, viewerId)),
    viewerBlock: database.doc(`users/${viewerId}/blocks/${profileId}`),
    profileBlock: database.doc(`users/${profileId}/blocks/${viewerId}`),
  };
}

async function privacyFor(
  database: Firestore,
  profileId: string,
): Promise<Record<string, unknown>> {
  const snapshot = await database.doc(
    `users/${profileId}/private/profile_settings`,
  ).get();
  return snapshot.data() ?? {};
}

function audienceAllows(
  audience: ProfileAudience,
  isFollowing: boolean,
): boolean {
  if (audience === "everyone") return true;
  if (audience === "followers") return isFollowing;
  return false;
}

async function relationshipPayload(
  database: Firestore,
  viewerId: string,
  profileId: string,
): Promise<Record<string, unknown>> {
  if (viewerId === profileId) {
    return {
      viewerId,
      profileId,
      state: "self" satisfies RelationshipState,
      canMessage: false,
      canViewFollowers: true,
    };
  }
  const refs = relationshipRefs(database, viewerId, profileId);
  const [
    viewerFollowing,
    profileFollowing,
    sentRequest,
    receivedRequest,
    viewerBlock,
    profileBlock,
    privacy,
    profile,
  ] = await Promise.all([
    refs.viewerFollowing.get(),
    refs.profileFollowing.get(),
    refs.sentRequest.get(),
    refs.receivedRequest.get(),
    refs.viewerBlock.get(),
    refs.profileBlock.get(),
    privacyFor(database, profileId),
    database.collection(collections.users).doc(profileId).get(),
  ]);

  let state: RelationshipState = "none";
  if (viewerBlock.exists) state = "blocked";
  else if (profileBlock.exists) state = "blockedBy";
  else if (viewerFollowing.exists && profileFollowing.exists) state = "mutual";
  else if (viewerFollowing.exists) state = "following";
  else if (profileFollowing.exists) state = "followedBy";
  else if (sentRequest.exists) state = "requestSent";
  else if (receivedRequest.exists) state = "requestReceived";

  const messageAudience = (privacy.messageAudience === "followers" ||
    privacy.messageAudience === "noOne") ?
    privacy.messageAudience : "everyone";
  const showFollowerLists = privacy.showFollowerLists !== false;
  const visibility = String(profile.get("visibility") ?? "private");
  const canViewProfile = profile.exists &&
    profile.get("moderationState") === "active" &&
    (viewerId === profileId || visibility === "public" ||
      (visibility === "followers" && viewerFollowing.exists));
  return {
    viewerId,
    profileId,
    state,
    canMessage: canViewProfile && state !== "blocked" &&
      state !== "blockedBy" &&
      audienceAllows(messageAudience, viewerFollowing.exists),
    canViewFollowers: canViewProfile && showFollowerLists,
    ...(sentRequest.exists ? {
      requestedAt: (sentRequest.get("createdAt") as Timestamp)
        .toDate().toISOString(),
    } : {}),
  };
}

function edgeData(userId: string, now: Timestamp): Record<string, unknown> {
  return {
    userId,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

async function assertActiveProfile(
  snapshot: DocumentSnapshot<DocumentData>,
): Promise<void> {
  if (!snapshot.exists || snapshot.get("moderationState") !== "active") {
    throw new HttpsError("not-found", "This profile is unavailable.");
  }
}

async function resolveVisibleProfileId(
  database: Firestore,
  data: Record<string, unknown>,
): Promise<string> {
  if (typeof data.profileId === "string" && data.profileId.trim()) {
    return safeDocumentId(data.profileId, "profileId");
  }
  if (typeof data.username !== "string" || !data.username.trim()) {
    throw new HttpsError(
      "invalid-argument",
      "A profile ID or username is required.",
    );
  }
  const normalized = normalizeUsername(data.username);
  const reservation = await database.collection(collections.usernames)
    .doc(safeDocumentId(normalized, "username")).get();
  const uid = reservation.get("uid");
  if (!reservation.exists || typeof uid !== "string" || !uid) {
    throw new HttpsError("not-found", "This profile is unavailable.");
  }
  return uid;
}

async function sanitizedProfileForViewer(
  database: Firestore,
  viewerId: string,
  profileId: string,
): Promise<Record<string, unknown>> {
  const profileRef = database.collection(collections.users).doc(profileId);
  const [profile, viewerBlock, profileBlock, follower, privacy] =
    await Promise.all([
      profileRef.get(),
      database.doc(`users/${viewerId}/blocks/${profileId}`).get(),
      database.doc(`users/${profileId}/blocks/${viewerId}`).get(),
      database.doc(`users/${profileId}/followers/${viewerId}`).get(),
      privacyFor(database, profileId),
    ]);
  if (!profile.exists || profile.get("moderationState") !== "active" ||
      viewerBlock.exists || profileBlock.exists) {
    throw new HttpsError("not-found", "This profile is unavailable.");
  }
  const visibility = String(profile.get("visibility") ?? "private");
  const canView = viewerId === profileId || visibility === "public" ||
    (visibility === "followers" && follower.exists);
  if (!canView) {
    throw new HttpsError("permission-denied", "This profile is private.");
  }
  return sanitizedCallableProfile(profile, privacy, viewerId === profileId);
}

export const getPublicProfile = onCall(
  callableOptions,
  async (request) => {
    const viewerId = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const database = getFirestore();
    const profileId = await resolveVisibleProfileId(database, data);
    return {
      profile: await sanitizedProfileForViewer(database, viewerId, profileId),
    };
  },
);

export const getProfileRelationship = onCall(
  callableOptions,
  async (request) => {
    const viewerId = requireUid(request.auth?.uid);
    const profileId = profileIdFrom(request.data);
    const database = getFirestore();
    const profile = await database.collection(collections.users)
      .doc(profileId).get();
    await assertActiveProfile(profile);
    return relationshipPayload(database, viewerId, profileId);
  },
);

export const followProfile = onCall(callableOptions, async (request) => {
  const viewerId = requireUid(request.auth?.uid);
  const profileId = profileIdFrom(request.data);
  if (viewerId === profileId) {
    throw new HttpsError("invalid-argument", "You cannot follow yourself.");
  }
  await consumeRateLimit(viewerId, {
    key: "follow_profile",
    maxAttempts: 150,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  const refs = relationshipRefs(database, viewerId, profileId);
  const viewerRef = database.collection(collections.users).doc(viewerId);
  const profileRef = database.collection(collections.users).doc(profileId);

  await database.runTransaction(async (transaction) => {
    const [viewer, profile, existing, viewerBlock, profileBlock, requestDoc] =
      await Promise.all([
        transaction.get(viewerRef),
        transaction.get(profileRef),
        transaction.get(refs.viewerFollowing),
        transaction.get(refs.viewerBlock),
        transaction.get(refs.profileBlock),
        transaction.get(refs.sentRequest),
      ]);
    await assertActiveProfile(viewer);
    await assertActiveProfile(profile);
    if (viewerBlock.exists || profileBlock.exists) {
      throw new HttpsError(
        "failed-precondition",
        "This connection is unavailable.",
      );
    }
    if (existing.exists || requestDoc.exists) return;

    const approvalPolicy = profile.get("followApprovalPolicy") ===
      "approvalRequired" || profile.get("visibility") !== "public";
    const now = Timestamp.now();
    if (approvalPolicy) {
      transaction.create(refs.sentRequest, {
        requesterId: viewerId,
        targetId: profileId,
        status: "pending",
        createdAt: now,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      });
      return;
    }

    transaction.create(refs.viewerFollowing, edgeData(profileId, now));
    transaction.create(refs.profileFollowers, edgeData(viewerId, now));
    transaction.update(viewerRef, {
      followingCount: Math.max(0, Number(viewer.get("followingCount") ?? 0)) + 1,
      updatedAt: now,
    });
    transaction.update(profileRef, {
      followersCount: Math.max(0, Number(profile.get("followersCount") ?? 0)) + 1,
      updatedAt: now,
    });
  });

  await writeAuditEvent({
    actorId: viewerId,
    action: "profile.follow_requested",
    targetType: "user",
    targetId: profileId,
  });
  return relationshipPayload(database, viewerId, profileId);
});

export const unfollowProfile = onCall(callableOptions, async (request) => {
  const viewerId = requireUid(request.auth?.uid);
  const profileId = profileIdFrom(request.data);
  if (viewerId === profileId) {
    throw new HttpsError("invalid-argument", "You cannot unfollow yourself.");
  }
  const database = getFirestore();
  const refs = relationshipRefs(database, viewerId, profileId);
  const viewerRef = database.collection(collections.users).doc(viewerId);
  const profileRef = database.collection(collections.users).doc(profileId);

  await database.runTransaction(async (transaction) => {
    const [viewer, profile, edge, requestDoc] = await Promise.all([
      transaction.get(viewerRef),
      transaction.get(profileRef),
      transaction.get(refs.viewerFollowing),
      transaction.get(refs.sentRequest),
    ]);
    if (requestDoc.exists) transaction.delete(refs.sentRequest);
    if (!edge.exists) return;
    transaction.delete(refs.viewerFollowing);
    transaction.delete(refs.profileFollowers);
    if (viewer.exists) {
      transaction.update(viewerRef, {
        followingCount: Math.max(
          0,
          Number(viewer.get("followingCount") ?? 0) - 1,
        ),
        updatedAt: Timestamp.now(),
      });
    }
    if (profile.exists) {
      transaction.update(profileRef, {
        followersCount: Math.max(
          0,
          Number(profile.get("followersCount") ?? 0) - 1,
        ),
        updatedAt: Timestamp.now(),
      });
    }
  });
  return relationshipPayload(database, viewerId, profileId);
});

export const cancelFollowRequest = onCall(
  callableOptions,
  async (request) => {
    const viewerId = requireUid(request.auth?.uid);
    const profileId = profileIdFrom(request.data);
    const database = getFirestore();
    await database.collection("follow_requests")
      .doc(followRequestId(viewerId, profileId)).delete();
    return relationshipPayload(database, viewerId, profileId);
  },
);

export const respondToFollowRequest = onCall(
  callableOptions,
  async (request) => {
    const targetId = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const requesterId = safeDocumentId(data.profileId, "profileId");
    const response = data.response;
    if (response !== "accept" && response !== "decline") {
      throw new HttpsError("invalid-argument", "Response is invalid.");
    }
    const database = getFirestore();
    const requestRef = database.collection("follow_requests")
      .doc(followRequestId(requesterId, targetId));
    const requesterRef = database.collection(collections.users).doc(requesterId);
    const targetRef = database.collection(collections.users).doc(targetId);
    const refs = relationshipRefs(database, requesterId, targetId);

    await database.runTransaction(async (transaction) => {
      const [requestDoc, requester, target, existing, requesterBlock, targetBlock] =
        await Promise.all([
          transaction.get(requestRef),
          transaction.get(requesterRef),
          transaction.get(targetRef),
          transaction.get(refs.viewerFollowing),
          transaction.get(refs.viewerBlock),
          transaction.get(refs.profileBlock),
        ]);
      if (!requestDoc.exists || requestDoc.get("status") !== "pending") {
        throw new HttpsError("not-found", "This follow request is unavailable.");
      }
      transaction.delete(requestRef);
      if (response === "decline" || existing.exists) return;
      await assertActiveProfile(requester);
      await assertActiveProfile(target);
      if (requesterBlock.exists || targetBlock.exists) {
        throw new HttpsError(
          "failed-precondition",
          "This connection is unavailable.",
        );
      }
      const now = Timestamp.now();
      transaction.create(refs.viewerFollowing, edgeData(targetId, now));
      transaction.create(refs.profileFollowers, edgeData(requesterId, now));
      transaction.update(requesterRef, {
        followingCount:
          Math.max(0, Number(requester.get("followingCount") ?? 0)) + 1,
        updatedAt: now,
      });
      transaction.update(targetRef, {
        followersCount:
          Math.max(0, Number(target.get("followersCount") ?? 0)) + 1,
        updatedAt: now,
      });
    });

    await writeAuditEvent({
      actorId: targetId,
      action: response === "accept" ?
        "profile.follow_request_accepted" :
        "profile.follow_request_declined",
      targetType: "user",
      targetId: requesterId,
    });
    return relationshipPayload(database, targetId, requesterId);
  },
);

export const removeFollower = onCall(callableOptions, async (request) => {
  const profileId = requireUid(request.auth?.uid);
  const followerId = profileIdFrom(request.data);
  const database = getFirestore();
  const refs = relationshipRefs(database, followerId, profileId);
  const followerRef = database.collection(collections.users).doc(followerId);
  const profileRef = database.collection(collections.users).doc(profileId);

  await database.runTransaction(async (transaction) => {
    const [follower, profile, edge] = await Promise.all([
      transaction.get(followerRef),
      transaction.get(profileRef),
      transaction.get(refs.viewerFollowing),
    ]);
    if (!edge.exists) return;
    transaction.delete(refs.viewerFollowing);
    transaction.delete(refs.profileFollowers);
    if (follower.exists) {
      transaction.update(followerRef, {
        followingCount: Math.max(
          0,
          Number(follower.get("followingCount") ?? 0) - 1,
        ),
        updatedAt: Timestamp.now(),
      });
    }
    if (profile.exists) {
      transaction.update(profileRef, {
        followersCount: Math.max(
          0,
          Number(profile.get("followersCount") ?? 0) - 1,
        ),
        updatedAt: Timestamp.now(),
      });
    }
  });
  return {removed: true};
});

function parsedCursor(data: Record<string, unknown>): {
  id?: string;
  at?: Timestamp;
} {
  if (data.cursorId === undefined || data.cursorAt === undefined) return {};
  const id = safeDocumentId(data.cursorId, "cursorId");
  if (typeof data.cursorAt !== "string") {
    throw new HttpsError("invalid-argument", "Cursor is invalid.");
  }
  const date = new Date(data.cursorAt);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", "Cursor is invalid.");
  }
  return {id, at: Timestamp.fromDate(date)};
}

async function profileDocuments(
  database: Firestore,
  ids: string[],
): Promise<Map<string, DocumentSnapshot<DocumentData>>> {
  const uniqueIds = [...new Set(ids)];
  const snapshots = await database.getAll(
    ...uniqueIds.map((id) => database.collection(collections.users).doc(id)),
  );
  return new Map(snapshots.map((item) => [item.id, item]));
}

export const listProfileConnections = onCall(
  callableOptions,
  async (request) => {
    const viewerId = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const profileId = safeDocumentId(data.profileId, "profileId");
    const type = data.type;
    if (type !== "followers" && type !== "following" && type !== "requests") {
      throw new HttpsError("invalid-argument", "Connection type is invalid.");
    }
    const limitValue = typeof data.limit === "number" ?
      Math.trunc(data.limit) : 30;
    const limit = Math.min(50, Math.max(1, limitValue));
    const database = getFirestore();
    const relationship = await relationshipPayload(
      database,
      viewerId,
      profileId,
    );
    if (viewerId !== profileId && relationship.canViewFollowers !== true) {
      throw new HttpsError(
        "permission-denied",
        "This connection list is private.",
      );
    }
    if (type === "requests" && viewerId !== profileId) {
      throw new HttpsError(
        "permission-denied",
        "Follow requests are private.",
      );
    }
    if (type !== "requests" &&
        viewerId !== profileId &&
        relationship.canViewFollowers !== true) {
      throw new HttpsError(
        "permission-denied",
        "This connection list is private.",
      );
    }
    const cursor = parsedCursor(data);
    let documents: QueryDocumentSnapshot<DocumentData>[];
    if (type === "requests") {
      let query = database.collection("follow_requests")
        .where("targetId", "==", profileId)
        .where("status", "==", "pending")
        .orderBy("createdAt", "desc")
        .orderBy(FieldPath.documentId())
        .limit(limit + 1);
      if (cursor.id && cursor.at) {
        query = query.startAfter(cursor.at, cursor.id);
      }
      documents = (await query.get()).docs;
    } else {
      let query = database.collection(collections.users)
        .doc(profileId)
        .collection(type)
        .orderBy("createdAt", "desc")
        .orderBy(FieldPath.documentId())
        .limit(limit + 1);
      if (cursor.id && cursor.at) {
        query = query.startAfter(cursor.at, cursor.id);
      }
      documents = (await query.get()).docs;
    }
    const page = documents.slice(0, limit);
    const ids = page.map((item) => type === "requests" ?
      String(item.get("requesterId") ?? "") : item.id);
    const profiles = await profileDocuments(database, ids);
    const items = await Promise.all(ids.map(async (id) => {
      const profile = profiles.get(id);
      if (!profile?.exists || profile.get("moderationState") !== "active") {
        return undefined;
      }
      const privacy = await privacyFor(database, id);
      return sanitizedCallableProfile(profile, privacy, viewerId === id);
    }));
    const last = page.at(-1);
    return {
      items: items.filter(
        (item): item is {
          profile: Record<string, unknown>;
          blockedAt: string;
        } => item !== undefined,
      ),
      hasMore: documents.length > limit,
      ...(last ? {
        nextCursor: {
          documentId: last.id,
          createdAt: (last.get("createdAt") as Timestamp)
            .toDate().toISOString(),
        },
      } : {}),
    };
  },
);

export const listBlockedProfiles = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = recordValue(request.data ?? {});
    const limitValue = typeof data.limit === "number" ?
      Math.trunc(data.limit) : 100;
    const limit = Math.min(100, Math.max(1, limitValue));
    const database = getFirestore();
    const blocks = await database.collection(collections.users)
      .doc(uid)
      .collection("blocks")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();
    const profiles = await profileDocuments(
      database,
      blocks.docs.map((item) => item.id),
    );
    const items = await Promise.all(blocks.docs.map(async (block) => {
      const profile = profiles.get(block.id);
      if (!profile?.exists) return undefined;
      const privacy = await privacyFor(database, block.id);
      return {
        profile: sanitizedCallableProfile(profile, privacy, false),
        blockedAt: (block.get("createdAt") as Timestamp)
          .toDate().toISOString(),
      };
    }));
    return {
      items: items.filter(
        (item): item is {
          profile: Record<string, unknown>;
          blockedAt: string;
        } => item !== undefined,
      ),
    };
  },
);

export const unblockUser = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const profileId = profileIdFrom(request.data);
  const database = getFirestore();
  const batch = database.batch();
  batch.delete(database.doc(`users/${uid}/blocks/${profileId}`));
  batch.delete(database.doc(`users/${profileId}/blocked_by/${uid}`));
  await batch.commit();
  await writeAuditEvent({
    actorId: uid,
    action: "safety.user_unblocked",
    targetType: "user",
    targetId: profileId,
  });
  return {unblocked: true};
});

export async function removeRelationshipForBlock(
  database: Firestore,
  blockerId: string,
  blockedId: string,
): Promise<void> {
  const blockerRef = database.collection(collections.users).doc(blockerId);
  const blockedRef = database.collection(collections.users).doc(blockedId);
  const forward = relationshipRefs(database, blockerId, blockedId);
  const reverse = relationshipRefs(database, blockedId, blockerId);
  await database.runTransaction(async (transaction) => {
    const [blocker, blocked, blockerFollows, blockedFollows] =
      await Promise.all([
        transaction.get(blockerRef),
        transaction.get(blockedRef),
        transaction.get(forward.viewerFollowing),
        transaction.get(reverse.viewerFollowing),
      ]);
    const now = Timestamp.now();
    if (blockerFollows.exists) {
      transaction.delete(forward.viewerFollowing);
      transaction.delete(forward.profileFollowers);
      if (blocker.exists) {
        transaction.update(blockerRef, {
          followingCount: Math.max(
            0,
            Number(blocker.get("followingCount") ?? 0) - 1,
          ),
          updatedAt: now,
        });
      }
      if (blocked.exists) {
        transaction.update(blockedRef, {
          followersCount: Math.max(
            0,
            Number(blocked.get("followersCount") ?? 0) - 1,
          ),
          updatedAt: now,
        });
      }
    }
    if (blockedFollows.exists) {
      transaction.delete(reverse.viewerFollowing);
      transaction.delete(reverse.profileFollowers);
      if (blocked.exists) {
        transaction.update(blockedRef, {
          followingCount: Math.max(
            0,
            Number(blocked.get("followingCount") ?? 0) - 1,
          ),
          updatedAt: now,
        });
      }
      if (blocker.exists) {
        transaction.update(blockerRef, {
          followersCount: Math.max(
            0,
            Number(blocker.get("followersCount") ?? 0) - 1,
          ),
          updatedAt: now,
        });
      }
    }
    transaction.delete(forward.sentRequest);
    transaction.delete(forward.receivedRequest);
  });
}
