import {
  FieldPath,
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentData,
  type Query,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {reportReasons} from "../feed/interactions";
import {
  deliverGroupInvitationAcceptedNotification,
  deliverGroupInvitationNotification,
  deliverGroupJoinAcceptedNotification,
  deliverGroupJoinRequestNotification,
  resolveGroupJoinRequestNotifications,
} from "../notifications/groupNotifications";
import {requireUid} from "../messaging/conversationAccess";
import {
  activeMemberRole,
  activeProfileSnapshot,
  assertActiveGroup,
  assertNotBlocked,
  canListGroupInDiscovery,
  canViewGroupDocument,
  groupRef,
  invitationInboxRef,
  invitationRef,
  joinRequestRef,
  listManagerUids,
  memberDocument,
  memberRef,
  membershipInboxDocument,
  membershipInboxRef,
  requireActiveMember,
  requireManager,
  softRemoveMemberInTx,
} from "./groupsAccess";
import {
  asRecord,
  canRemoveMember,
  groupChannelContracts,
  isManagerRole,
  nextMemberCount,
  normalizeJoinPolicy,
  optionalString,
  parseCreateGroupInput,
  parseCreateSessionInput,
  parseDecision,
  parseIsoDate,
  parseUpdateGroupInput,
  requiredString,
  type GroupJoinPolicy,
  type GroupMemberRole,
  type GroupPrivacy,
} from "./groupsPolicy";

function publicGroupPayload(
  groupId: string,
  data: DocumentData,
  extras: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    groupId,
    name: data.name,
    description: data.description,
    category: data.category,
    privacy: data.privacy,
    joinPolicy: data.joinPolicy,
    status: data.status,
    memberCount: data.memberCount,
    capacity: data.capacity ?? 0,
    ownerId: data.ownerId,
    location: data.location ?? {},
    avatarUrl: data.avatarUrl ?? null,
    coverUrl: data.coverUrl ?? null,
    createdAt: data.createdAt?.toDate?.()?.toISOString?.() ?? null,
    updatedAt: data.updatedAt?.toDate?.()?.toISOString?.() ?? null,
    ...extras,
  };
}

function memberPayload(doc: QueryDocumentSnapshot) {
  const snap = asRecord(doc.get("userSnapshot"));
  return {
    userId: doc.id,
    role: doc.get("role"),
    status: doc.get("status"),
    joinedAt: doc.get("joinedAt")?.toDate?.()?.toISOString?.() ?? null,
    displayName: String(snap.displayName ?? ""),
    username: String(snap.username ?? ""),
    avatarUrl: snap.avatarUrl ?? null,
  };
}

export const createGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseCreateGroupInput(request.data);
  await consumeRateLimit(uid, {
    key: "create_group",
    maxAttempts: 10,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const profile = await activeProfileSnapshot(database, uid);
  const now = Timestamp.now();
  const reference = database.collection(collections.groups).doc();
  const memberChatId = database.collection(collections.conversations).doc().id;
  const announcementsId = database.collection(collections.conversations).doc().id;
  const batch = database.batch();
  batch.create(reference, {
    name: input.name,
    description: input.description,
    category: input.category,
    privacy: input.privacy,
    joinPolicy: input.joinPolicy,
    location: input.location,
    capacity: input.capacity,
    ...(input.avatarUrl ? {avatarUrl: input.avatarUrl} : {}),
    ...(input.coverUrl ? {coverUrl: input.coverUrl} : {}),
    ownerId: uid,
    memberCount: 1,
    status: "active",
    moderationState: "active",
    memberChatConversationId: memberChatId,
    announcementsConversationId: announcementsId,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  batch.create(
    reference.collection("members").doc(uid),
    memberDocument(profile, "owner", now),
  );
  batch.set(membershipInboxRef(database, uid, reference.id), {
    groupId: reference.id,
    role: "owner",
    status: "active",
    joinedAt: now,
    updatedAt: now,
    groupSnapshot: {
      name: input.name,
      privacy: input.privacy,
      avatarUrl: input.avatarUrl ?? null,
      category: input.category,
      memberCount: 1,
    },
    schemaVersion: currentSchemaVersion,
  });
  for (const channel of groupChannelContracts()) {
    const conversationId = channel.type === "member_chat" ?
      memberChatId :
      announcementsId;
    batch.set(reference.collection("channels").doc(channel.type), {
      type: channel.type,
      conversationId,
      supportedMediaModes: channel.supportedMediaModes,
      publishRoles: channel.publishRoles,
      readRoles: channel.readRoles,
      // Phase C2: disappearing / view-once media behavior.
      phase: "c1_contract",
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
  }
  await batch.commit();
  await writeAuditEvent({
    actorId: uid,
    action: "groups.created",
    targetType: "group",
    targetId: reference.id,
    metadata: {privacy: input.privacy, joinPolicy: input.joinPolicy},
  });
  return {groupId: reference.id};
});

export const updateGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseUpdateGroupInput(request.data);
  await consumeRateLimit(uid, {
    key: "update_group",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const reference = groupRef(database, input.groupId);
  await database.runTransaction(async (transaction) => {
    const [group, member] = await Promise.all([
      transaction.get(reference),
      transaction.get(memberRef(database, input.groupId, uid)),
    ]);
    assertActiveGroup(group);
    const role = activeMemberRole(member);
    if (!role || !isManagerRole(role)) {
      throw new HttpsError("permission-denied", "Owner or admin access is required.");
    }
    const privacySensitive =
      input.privacy !== undefined ||
      input.joinPolicy !== undefined ||
      input.status !== undefined;
    if (privacySensitive && role !== "owner") {
      throw new HttpsError(
        "permission-denied",
        "Only the owner can change privacy, join policy, or status.",
      );
    }
    const now = Timestamp.now();
    const privacy = (input.privacy ??
      String(group.get("privacy"))) as GroupPrivacy;
    const joinPolicy = normalizeJoinPolicy(
      privacy,
      (input.joinPolicy ?? String(group.get("joinPolicy"))) as GroupJoinPolicy,
    );
    const patch: Record<string, unknown> = {updatedAt: now};
    if (input.name !== undefined) patch.name = input.name;
    if (input.description !== undefined) patch.description = input.description;
    if (input.category !== undefined) patch.category = input.category;
    if (input.location !== undefined) patch.location = input.location;
    if (input.capacity !== undefined) patch.capacity = input.capacity;
    if (input.avatarUrl !== undefined) {
      patch.avatarUrl = input.avatarUrl === null ?
        FieldValue.delete() :
        input.avatarUrl;
    }
    if (input.coverUrl !== undefined) {
      patch.coverUrl = input.coverUrl === null ?
        FieldValue.delete() :
        input.coverUrl;
    }
    if (input.privacy !== undefined) patch.privacy = privacy;
    if (input.joinPolicy !== undefined || input.privacy !== undefined) {
      patch.joinPolicy = joinPolicy;
    }
    if (input.status !== undefined) patch.status = input.status;
    transaction.update(reference, patch);
  });
  await writeAuditEvent({
    actorId: uid,
    action: "groups.updated",
    targetType: "group",
    targetId: input.groupId,
  });
  return {ok: true};
});

export const getGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  const database = getFirestore();
  const [group, member] = await Promise.all([
    groupRef(database, groupId).get(),
    memberRef(database, groupId, uid).get(),
  ]);
  assertActiveGroup(group);
  const role = activeMemberRole(member);
  const privacy = String(group.get("privacy") ?? "public") as GroupPrivacy;
  if (!canViewGroupDocument(privacy, role !== null)) {
    throw new HttpsError("not-found", "This group is unavailable.");
  }
  const ownerId = String(group.get("ownerId") ?? "");
  if (ownerId) {
    try {
      await assertNotBlocked(database, uid, ownerId);
    } catch {
      throw new HttpsError("not-found", "This group is unavailable.");
    }
  }
  const membershipStatus = role ?? (
    (await joinRequestRef(database, groupId, uid).get()).exists ?
      "pending" :
      "none"
  );
  return {
    group: publicGroupPayload(groupId, group.data() ?? {}, {
      viewerRole: role,
      membershipStatus,
      memberChatConversationId: role ?
        group.get("memberChatConversationId") ?? null :
        null,
      announcementsConversationId: role ?
        group.get("announcementsConversationId") ?? null :
        null,
    }),
  };
});

export const listDiscoverableGroups = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  await activeProfileSnapshot(getFirestore(), uid);
  const body = asRecord(request.data);
  const limit = Math.min(
    Math.max(Number(body.limit ?? 20) || 20, 1),
    40,
  );
  const category = typeof body.category === "string" ?
    body.category.trim() :
    "";
  let cursor: {id?: string; at?: Timestamp} = {};
  if (body.cursorId !== undefined || body.cursorAt !== undefined) {
    const cursorId = requiredString(body.cursorId, "cursorId", 128);
    if (typeof body.cursorAt !== "string") {
      throw new HttpsError("invalid-argument", "Cursor is invalid.");
    }
    const date = new Date(body.cursorAt);
    if (Number.isNaN(date.getTime())) {
      throw new HttpsError("invalid-argument", "Cursor is invalid.");
    }
    cursor = {id: cursorId, at: Timestamp.fromDate(date)};
  }
  let query: Query<DocumentData> = getFirestore().collection(collections.groups)
    .where("privacy", "==", "public")
    .where("status", "==", "active")
    .where("moderationState", "==", "active");
  if (category) {
    query = query.where("category", "==", category);
  }
  query = query.orderBy("createdAt", "desc").orderBy(FieldPath.documentId());
  if (cursor.id && cursor.at) {
    query = query.startAfter(cursor.at, cursor.id);
  }
  const snapshot = await query.limit(limit + 1).get();
  const page = snapshot.docs.slice(0, limit);
  const last = page.at(-1);
  return {
    groups: page
      .filter((doc) => canListGroupInDiscovery(
        String(doc.get("privacy")) as GroupPrivacy,
      ))
      .map((doc) => publicGroupPayload(doc.id, doc.data())),
    hasMore: snapshot.docs.length > limit,
    ...(last ? {
      nextCursor: {
        documentId: last.id,
        createdAt: (last.get("createdAt") as Timestamp).toDate().toISOString(),
      },
    } : {}),
  };
});

export const listMyGroups = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const limit = Math.min(
    Math.max(Number(asRecord(request.data).limit ?? 40) || 40, 1),
    100,
  );
  const snapshot = await getFirestore()
    .collection(`users/${uid}/group_memberships`)
    .where("status", "==", "active")
    .orderBy("joinedAt", "desc")
    .limit(limit)
    .get();
  return {
    groups: snapshot.docs.map((doc) => ({
      groupId: doc.id,
      role: doc.get("role"),
      joinedAt: doc.get("joinedAt")?.toDate?.()?.toISOString?.() ?? null,
      groupSnapshot: doc.get("groupSnapshot") ?? {},
    })),
  };
});

export const requestJoinGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  await consumeRateLimit(uid, {
    key: "request_join_group",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const profile = await activeProfileSnapshot(database, uid);
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  await assertNotBlocked(database, uid, String(group.get("ownerId")));
  const privacy = String(group.get("privacy")) as GroupPrivacy;
  const joinPolicy = String(group.get("joinPolicy"));
  if (privacy === "hidden" || joinPolicy === "inviteOnly") {
    throw new HttpsError("permission-denied", "This group is invite only.");
  }
  // Public and private groups (that are not inviteOnly) can accept join
  // requests; private groups are typically discovered via invite/link.
  const result = await database.runTransaction(async (transaction) => {
    const [fresh, member, pending] = await Promise.all([
      transaction.get(group.ref),
      transaction.get(memberRef(database, groupId, uid)),
      transaction.get(joinRequestRef(database, groupId, uid)),
    ]);
    assertActiveGroup(fresh);
    if (activeMemberRole(member)) return {status: "member" as const};
    if (pending.exists && pending.get("status") === "pending") {
      return {status: "pending" as const};
    }
    const now = Timestamp.now();
    if (joinPolicy === "open") {
      const count = Number(fresh.get("memberCount") ?? 0);
      const capacity = Number(fresh.get("capacity") ?? 0);
      if (capacity > 0 && count >= capacity) {
        throw new HttpsError("resource-exhausted", "This group is full.");
      }
      transaction.set(
        memberRef(database, groupId, uid),
        memberDocument(profile, "member", now),
      );
      transaction.set(
        membershipInboxRef(database, uid, groupId),
        membershipInboxDocument(groupId, "member", fresh, now),
      );
      transaction.update(fresh.ref, {
        memberCount: nextMemberCount(count, 1),
        updatedAt: now,
      });
      if (pending.exists) transaction.delete(pending.ref);
      return {status: "member" as const};
    }
    transaction.set(joinRequestRef(database, groupId, uid), {
      requesterId: uid,
      status: "pending",
      userSnapshot: profile,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    return {status: "pending" as const};
  });

  if (result.status === "pending") {
    const managers = await listManagerUids(database, groupId);
    await Promise.all(managers.map((managerId) =>
      deliverGroupJoinRequestNotification({
        groupId,
        groupName: String(group.get("name") ?? "a group"),
        requesterId: uid,
        recipientId: managerId,
      }).catch(() => undefined),
    ));
  }
  await writeAuditEvent({
    actorId: uid,
    action: result.status === "pending" ?
      "groups.join_requested" :
      "groups.joined",
    targetType: "group",
    targetId: groupId,
  });
  return result;
});

export const cancelJoinRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  const database = getFirestore();
  const ref = joinRequestRef(database, groupId, uid);
  const snap = await ref.get();
  if (snap.exists) {
    await ref.delete();
    const managers = await listManagerUids(database, groupId);
    await Promise.all(managers.map((managerId) =>
      resolveGroupJoinRequestNotifications(managerId, groupId, uid)
        .catch(() => undefined),
    ));
  }
  return {ok: true};
});

export const respondToJoinRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const requesterId = requiredString(body.requesterId, "requesterId", 128);
  const decision = parseDecision(request.data);
  await consumeRateLimit(uid, {
    key: "respond_group_join_request",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  await requireManager(database, groupId, uid);
  await assertNotBlocked(database, uid, requesterId);
  const profile = await activeProfileSnapshot(database, requesterId);
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  await database.runTransaction(async (transaction) => {
    const [fresh, requestSnap, member] = await Promise.all([
      transaction.get(group.ref),
      transaction.get(joinRequestRef(database, groupId, requesterId)),
      transaction.get(memberRef(database, groupId, requesterId)),
    ]);
    if (!requestSnap.exists || requestSnap.get("status") !== "pending") {
      throw new HttpsError("failed-precondition", "This request is no longer pending.");
    }
    const now = Timestamp.now();
    if (decision === "decline") {
      transaction.delete(requestSnap.ref);
      return;
    }
    if (activeMemberRole(member)) {
      transaction.delete(requestSnap.ref);
      return;
    }
    const count = Number(fresh.get("memberCount") ?? 0);
    const capacity = Number(fresh.get("capacity") ?? 0);
    if (capacity > 0 && count >= capacity) {
      throw new HttpsError("resource-exhausted", "This group is full.");
    }
    transaction.set(
      memberRef(database, groupId, requesterId),
      memberDocument(profile, "member", now),
    );
    transaction.set(
      membershipInboxRef(database, requesterId, groupId),
      membershipInboxDocument(groupId, "member", fresh, now),
    );
    transaction.update(fresh.ref, {
      memberCount: nextMemberCount(count, 1),
      updatedAt: now,
    });
    transaction.delete(requestSnap.ref);
  });
  if (decision === "accept") {
    await deliverGroupJoinAcceptedNotification({
      groupId,
      groupName: String(group.get("name") ?? "a group"),
      actorId: uid,
      requesterId,
    }).catch(() => undefined);
  }
  const managers = await listManagerUids(database, groupId);
  await Promise.all(managers.map((managerId) =>
    resolveGroupJoinRequestNotifications(managerId, groupId, requesterId)
      .catch(() => undefined),
  ));
  await writeAuditEvent({
    actorId: uid,
    action: decision === "accept" ?
      "groups.join_accepted" :
      "groups.join_declined",
    targetType: "group",
    targetId: groupId,
    metadata: {requesterId},
  });
  return {ok: true};
});

export const inviteToGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const inviteeId = requiredString(body.inviteeId, "inviteeId", 128);
  if (uid === inviteeId) {
    throw new HttpsError("invalid-argument", "You cannot invite yourself.");
  }
  await consumeRateLimit(uid, {
    key: "invite_to_group",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  await requireManager(database, groupId, uid);
  await assertNotBlocked(database, uid, inviteeId);
  const following = await database
    .doc(`users/${inviteeId}/following/${uid}`)
    .get();
  if (!following.exists) {
    throw new HttpsError(
      "failed-precondition",
      "You can only invite users who follow you.",
    );
  }
  const invitee = await activeProfileSnapshot(database, inviteeId);
  const inviter = await activeProfileSnapshot(database, uid);
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  const created = await database.runTransaction(async (transaction) => {
    const [member, invite] = await Promise.all([
      transaction.get(memberRef(database, groupId, inviteeId)),
      transaction.get(invitationRef(database, groupId, inviteeId)),
    ]);
    if (activeMemberRole(member)) return false;
    if (invite.exists && invite.get("status") === "pending") return false;
    const now = Timestamp.now();
    transaction.set(invitationRef(database, groupId, inviteeId), {
      inviteeId,
      inviterId: uid,
      status: "pending",
      inviteeSnapshot: invitee,
      inviterSnapshot: inviter,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.set(invitationInboxRef(database, inviteeId, groupId), {
      groupId,
      inviterId: uid,
      status: "pending",
      groupSnapshot: {
        name: group.get("name"),
        privacy: group.get("privacy"),
        avatarUrl: group.get("avatarUrl") ?? null,
      },
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    return true;
  });
  if (created) {
    await deliverGroupInvitationNotification({
      groupId,
      groupName: String(group.get("name") ?? "a group"),
      inviterId: uid,
      inviteeId,
    }).catch(() => undefined);
  }
  await writeAuditEvent({
    actorId: uid,
    action: "groups.invitation_created",
    targetType: "group",
    targetId: groupId,
    metadata: {inviteeId, created},
  });
  return {created};
});

export const respondToGroupInvitation = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const body = asRecord(request.data);
    const groupId = requiredString(body.groupId, "groupId", 128);
    const decision = parseDecision(request.data);
    await consumeRateLimit(uid, {
      key: "respond_group_invitation",
      maxAttempts: 60,
      windowSeconds: 60 * 60,
    });
    const database = getFirestore();
    const profile = await activeProfileSnapshot(database, uid);
    const group = await groupRef(database, groupId).get();
    assertActiveGroup(group);
    const inviterId = await database.runTransaction(async (transaction) => {
      const [invite, member, fresh] = await Promise.all([
        transaction.get(invitationRef(database, groupId, uid)),
        transaction.get(memberRef(database, groupId, uid)),
        transaction.get(group.ref),
      ]);
      if (!invite.exists || invite.get("status") !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This invitation is no longer pending.",
        );
      }
      const invitedBy = String(invite.get("inviterId") ?? "");
      const now = Timestamp.now();
      transaction.delete(invite.ref);
      transaction.delete(invitationInboxRef(database, uid, groupId));
      if (decision === "decline") return invitedBy;
      if (activeMemberRole(member)) return invitedBy;
      const count = Number(fresh.get("memberCount") ?? 0);
      const capacity = Number(fresh.get("capacity") ?? 0);
      if (capacity > 0 && count >= capacity) {
        throw new HttpsError("resource-exhausted", "This group is full.");
      }
      transaction.set(
        memberRef(database, groupId, uid),
        memberDocument(profile, "member", now),
      );
      transaction.set(
        membershipInboxRef(database, uid, groupId),
        membershipInboxDocument(groupId, "member", fresh, now),
      );
      transaction.update(fresh.ref, {
        memberCount: nextMemberCount(count, 1),
        updatedAt: now,
      });
      return invitedBy;
    });
    if (decision === "accept" && inviterId) {
      await deliverGroupInvitationAcceptedNotification({
        groupId,
        groupName: String(group.get("name") ?? "a group"),
        inviterId,
        inviteeId: uid,
      }).catch(() => undefined);
    }
    await writeAuditEvent({
      actorId: uid,
      action: decision === "accept" ?
        "groups.invitation_accepted" :
        "groups.invitation_declined",
      targetType: "group",
      targetId: groupId,
    });
    return {ok: true};
  },
);

export const cancelGroupInvitation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const inviteeId = requiredString(body.inviteeId, "inviteeId", 128);
  const database = getFirestore();
  const invite = await invitationRef(database, groupId, inviteeId).get();
  if (!invite.exists) return {ok: true};
  const inviterId = String(invite.get("inviterId") ?? "");
  if (inviterId !== uid) {
    await requireManager(database, groupId, uid);
  }
  await invite.ref.delete();
  await invitationInboxRef(database, inviteeId, groupId).delete();
  return {ok: true};
});

export const removeGroupMember = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const memberId = requiredString(body.memberId, "memberId", 128);
  const database = getFirestore();
  const actorRole = await requireManager(database, groupId, uid);
  await database.runTransaction(async (transaction) => {
    const [group, target] = await Promise.all([
      transaction.get(groupRef(database, groupId)),
      transaction.get(memberRef(database, groupId, memberId)),
    ]);
    assertActiveGroup(group);
    const targetRole = activeMemberRole(target);
    if (!targetRole) return;
    if (!canRemoveMember(actorRole, targetRole)) {
      throw new HttpsError(
        "permission-denied",
        "You cannot remove this member.",
      );
    }
    softRemoveMemberInTx(
      transaction,
      database,
      group,
      target,
      memberId,
      Timestamp.now(),
    );
  });
  await writeAuditEvent({
    actorId: uid,
    action: "groups.member_removed",
    targetType: "group",
    targetId: groupId,
    metadata: {memberId},
  });
  return {ok: true};
});

export const setGroupMemberRole = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const memberId = requiredString(body.memberId, "memberId", 128);
  const role = requiredString(body.role, "role", 16) as GroupMemberRole;
  if (role !== "admin" && role !== "member") {
    throw new HttpsError("invalid-argument", "role must be admin or member.");
  }
  const database = getFirestore();
  const actorRole = await requireActiveMember(database, groupId, uid);
  if (actorRole !== "owner") {
    throw new HttpsError("permission-denied", "Only the owner can change roles.");
  }
  if (memberId === uid) {
    throw new HttpsError("failed-precondition", "Transfer ownership instead.");
  }
  await database.runTransaction(async (transaction) => {
    const target = await transaction.get(memberRef(database, groupId, memberId));
    const targetRole = activeMemberRole(target);
    if (!targetRole || targetRole === "owner") {
      throw new HttpsError("failed-precondition", "Member is unavailable.");
    }
    const now = Timestamp.now();
    transaction.update(target.ref, {role, updatedAt: now});
    transaction.set(
      membershipInboxRef(database, memberId, groupId),
      {role, updatedAt: now},
      {merge: true},
    );
  });
  await writeAuditEvent({
    actorId: uid,
    action: "groups.role_changed",
    targetType: "group",
    targetId: groupId,
    metadata: {memberId, role},
  });
  return {ok: true};
});

export const transferGroupOwnership = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const body = asRecord(request.data);
    const groupId = requiredString(body.groupId, "groupId", 128);
    const newOwnerId = requiredString(body.newOwnerId, "newOwnerId", 128);
    if (uid === newOwnerId) {
      throw new HttpsError("invalid-argument", "Already the owner.");
    }
    const database = getFirestore();
    await database.runTransaction(async (transaction) => {
      const [group, actor, target] = await Promise.all([
        transaction.get(groupRef(database, groupId)),
        transaction.get(memberRef(database, groupId, uid)),
        transaction.get(memberRef(database, groupId, newOwnerId)),
      ]);
      assertActiveGroup(group);
      if (activeMemberRole(actor) !== "owner") {
        throw new HttpsError("permission-denied", "Only the owner can transfer.");
      }
      if (!activeMemberRole(target)) {
        throw new HttpsError("failed-precondition", "New owner must be a member.");
      }
      const now = Timestamp.now();
      transaction.update(group.ref, {ownerId: newOwnerId, updatedAt: now});
      transaction.update(actor.ref, {role: "admin", updatedAt: now});
      transaction.update(target.ref, {role: "owner", updatedAt: now});
      transaction.set(
        membershipInboxRef(database, uid, groupId),
        {role: "admin", updatedAt: now},
        {merge: true},
      );
      transaction.set(
        membershipInboxRef(database, newOwnerId, groupId),
        {role: "owner", updatedAt: now},
        {merge: true},
      );
    });
    await writeAuditEvent({
      actorId: uid,
      action: "groups.ownership_transferred",
      targetType: "group",
      targetId: groupId,
      metadata: {newOwnerId},
    });
    return {ok: true};
  },
);

export const leaveGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  const database = getFirestore();
  await database.runTransaction(async (transaction) => {
    const [group, member] = await Promise.all([
      transaction.get(groupRef(database, groupId)),
      transaction.get(memberRef(database, groupId, uid)),
    ]);
    if (!group.exists || !member.exists) return;
    if (activeMemberRole(member) === "owner") {
      throw new HttpsError(
        "failed-precondition",
        "Transfer ownership or delete the group before leaving.",
      );
    }
    if (!activeMemberRole(member)) return;
    softRemoveMemberInTx(
      transaction,
      database,
      group,
      member,
      uid,
      Timestamp.now(),
    );
  });
  await writeAuditEvent({
    actorId: uid,
    action: "groups.left",
    targetType: "group",
    targetId: groupId,
  });
  return {ok: true};
});

export const deleteGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  const database = getFirestore();
  await database.runTransaction(async (transaction) => {
    const [group, member] = await Promise.all([
      transaction.get(groupRef(database, groupId)),
      transaction.get(memberRef(database, groupId, uid)),
    ]);
    assertActiveGroup(group);
    if (activeMemberRole(member) !== "owner") {
      throw new HttpsError("permission-denied", "Only the owner can delete.");
    }
    transaction.update(group.ref, {
      status: "deleted",
      updatedAt: Timestamp.now(),
    });
  });
  await writeAuditEvent({
    actorId: uid,
    action: "groups.deleted",
    targetType: "group",
    targetId: groupId,
  });
  return {ok: true};
});

export const listGroupMembers = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  const database = getFirestore();
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  const privacy = String(group.get("privacy")) as GroupPrivacy;
  const role = await memberRef(database, groupId, uid).get()
    .then(activeMemberRole);
  if (privacy !== "public" && !role) {
    throw new HttpsError("permission-denied", "Members list is private.");
  }
  const snapshot = await groupRef(database, groupId)
    .collection("members")
    .where("status", "==", "active")
    .limit(100)
    .get();
  return {
    members: snapshot.docs
      .filter((doc) => doc.get("removedAt") === null || doc.get("removedAt") === undefined)
      .map(memberPayload),
  };
});

export const listGroupJoinRequests = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
    await requireManager(getFirestore(), groupId, uid);
    const snapshot = await groupRef(getFirestore(), groupId)
      .collection("join_requests")
      .where("status", "==", "pending")
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    return {
      requests: snapshot.docs.map((doc) => {
        const snap = asRecord(doc.get("userSnapshot"));
        return {
          requesterId: doc.id,
          createdAt: doc.get("createdAt")?.toDate?.()?.toISOString?.() ?? null,
          displayName: String(snap.displayName ?? ""),
          username: String(snap.username ?? ""),
          avatarUrl: snap.avatarUrl ?? null,
        };
      }),
    };
  },
);

export const listMyGroupInvitations = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const snapshot = await getFirestore()
      .collection(`users/${uid}/group_invitations`)
      .where("status", "==", "pending")
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    return {
      invitations: snapshot.docs.map((doc) => ({
        groupId: doc.id,
        inviterId: doc.get("inviterId"),
        createdAt: doc.get("createdAt")?.toDate?.()?.toISOString?.() ?? null,
        groupSnapshot: doc.get("groupSnapshot") ?? {},
      })),
    };
  },
);

export const createGroupSession = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseCreateSessionInput(request.data);
  await requireManager(getFirestore(), input.groupId, uid);
  await consumeRateLimit(uid, {
    key: "create_group_session",
    maxAttempts: 40,
    windowSeconds: 24 * 60 * 60,
  });
  const now = Timestamp.now();
  const ref = groupRef(getFirestore(), input.groupId).collection("sessions").doc();
  await ref.create({
    title: input.title,
    activity: input.activity,
    description: input.description,
    startAt: Timestamp.fromDate(input.startAt),
    endAt: Timestamp.fromDate(input.endAt),
    location: input.location,
    capacity: input.capacity,
    status: "scheduled",
    createdBy: uid,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  await writeAuditEvent({
    actorId: uid,
    action: "groups.session_created",
    targetType: "group_session",
    targetId: `${input.groupId}:${ref.id}`,
  });
  return {sessionId: ref.id};
});

export const updateGroupSession = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const sessionId = requiredString(body.sessionId, "sessionId", 128);
  await requireManager(getFirestore(), groupId, uid);
  const patch: Record<string, unknown> = {updatedAt: Timestamp.now()};
  if (body.title !== undefined) {
    patch.title = requiredString(body.title, "title", 120);
  }
  if (body.activity !== undefined) {
    patch.activity = requiredString(body.activity, "activity", 64);
  }
  if (body.description !== undefined) {
    patch.description = optionalString(body.description, "description", 2000);
  }
  if (body.startAt !== undefined) {
    patch.startAt = Timestamp.fromDate(parseIsoDate(body.startAt, "startAt"));
  }
  if (body.endAt !== undefined) {
    patch.endAt = Timestamp.fromDate(parseIsoDate(body.endAt, "endAt"));
  }
  if (body.capacity !== undefined) {
    const capacity = Number(body.capacity);
    if (!Number.isInteger(capacity) || capacity < 0 || capacity > 10000) {
      throw new HttpsError("invalid-argument", "capacity is invalid.");
    }
    patch.capacity = capacity;
  }
  if (body.location !== undefined) {
    patch.location = asRecord(body.location);
  }
  await groupRef(getFirestore(), groupId)
    .collection("sessions")
    .doc(sessionId)
    .update(patch);
  return {ok: true};
});

export const cancelGroupSession = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const sessionId = requiredString(body.sessionId, "sessionId", 128);
  await requireManager(getFirestore(), groupId, uid);
  await groupRef(getFirestore(), groupId)
    .collection("sessions")
    .doc(sessionId)
    .update({status: "cancelled", updatedAt: Timestamp.now()});
  await writeAuditEvent({
    actorId: uid,
    action: "groups.session_cancelled",
    targetType: "group_session",
    targetId: `${groupId}:${sessionId}`,
  });
  return {ok: true};
});

export const listGroupSessions = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  const database = getFirestore();
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  const privacy = String(group.get("privacy")) as GroupPrivacy;
  const role = activeMemberRole(
    await memberRef(database, groupId, uid).get(),
  );
  if (privacy !== "public" && !role) {
    throw new HttpsError("permission-denied", "Schedule is private.");
  }
  // Public non-members get the upcoming/past schedule preview; members always
  // see the full schedule regardless of group privacy.
  const snapshot = await groupRef(database, groupId)
    .collection("sessions")
    .where("status", "in", ["scheduled", "cancelled", "completed"])
    .orderBy("startAt", "asc")
    .limit(50)
    .get();
  return {
    sessions: snapshot.docs.map((doc) => ({
      sessionId: doc.id,
      title: doc.get("title"),
      activity: doc.get("activity"),
      description: doc.get("description") ?? "",
      startAt: doc.get("startAt")?.toDate?.()?.toISOString?.() ?? null,
      endAt: doc.get("endAt")?.toDate?.()?.toISOString?.() ?? null,
      location: doc.get("location") ?? {},
      capacity: doc.get("capacity") ?? 0,
      status: doc.get("status"),
      createdBy: doc.get("createdBy"),
    })),
  };
});

export const getGroupChannels = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const groupId = requiredString(asRecord(request.data).groupId, "groupId", 128);
  await requireActiveMember(getFirestore(), groupId, uid);
  const snapshot = await groupRef(getFirestore(), groupId)
    .collection("channels")
    .limit(10)
    .get();
  return {
    channels: snapshot.docs.map((doc) => ({
      channelId: doc.id,
      ...doc.data(),
      // Explicit C2 marker for clients.
      viewOnceSupported: false,
      keepInChatSupported: true,
      normalMediaSupported: true,
    })),
    contracts: groupChannelContracts(),
  };
});

export const reportGroup = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const reason = requiredString(body.reason, "reason", 64);
  const details = typeof body.details === "string" ? body.details.trim() : "";
  if (!reportReasons.has(reason) || details.length > 2000) {
    throw new HttpsError("invalid-argument", "The report is invalid.");
  }
  await consumeRateLimit(uid, {
    key: "content_report",
    maxAttempts: 30,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const group = await groupRef(database, groupId).get();
  if (!group.exists) {
    throw new HttpsError("not-found", "This group is unavailable.");
  }
  const reportRef = database.collection("reports").doc();
  const now = Timestamp.now();
  await reportRef.create({
    reporterId: uid,
    targetType: "group",
    targetId: groupId,
    reason,
    ...(details ? {details} : {}),
    status: "open",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  await writeAuditEvent({
    actorId: uid,
    action: "content.report_created",
    targetType: "group",
    targetId: groupId,
    metadata: {reportId: reportRef.id, reason},
  });
  return {reportId: reportRef.id};
});
