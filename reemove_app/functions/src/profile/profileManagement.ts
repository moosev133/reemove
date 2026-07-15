import {getAuth} from "firebase-admin/auth";
import {
  getFirestore,
  Timestamp,
  type DocumentData,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {safeDocumentId} from "../feed/contentPolicy";
import {
  callableProfile,
  parsePrivacy,
  parseProfileUpdate,
  recordValue,
  safeString,
  type ProfilePrivacyInput,
} from "./profilePolicy";

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

function privacyDocument(
  uid: string,
  value: ProfilePrivacyInput,
  now: Timestamp,
): Record<string, unknown> {
  return {
    uid,
    ...value,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

async function assertOwnedProfileAsset(
  uid: string,
  storagePath: string | undefined,
  expectedPrefix: string,
): Promise<void> {
  if (!storagePath || !storagePath.startsWith(expectedPrefix)) {
    throw new HttpsError(
      "invalid-argument",
      "The selected profile image is invalid.",
    );
  }
  try {
    const [metadata] = await getStorage().bucket().file(storagePath).getMetadata();
    if (metadata.metadata?.ownerId !== uid ||
        metadata.metadata?.schemaVersion !== "1" ||
        !String(metadata.contentType ?? "").startsWith("image/")) {
      throw new HttpsError(
        "permission-denied",
        "The selected profile image is not owned by this account.",
      );
    }
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "failed-precondition",
      "The selected profile image could not be verified.",
    );
  }
}

async function validateChangedMedia(
  uid: string,
  current: DocumentSnapshot<DocumentData>,
  nextUrl: string | undefined,
  storagePath: string | undefined,
  urlField: "avatarUrl" | "coverUrl",
  prefix: string,
): Promise<void> {
  const existing = current.get(urlField);
  if (nextUrl === undefined || nextUrl === existing) return;
  await assertOwnedProfileAsset(uid, storagePath, prefix);
}

export const updateProfile = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseProfileUpdate(request.data);
  await consumeRateLimit(uid, {
    key: "update_profile",
    maxAttempts: 30,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const userRef = database.collection(collections.users).doc(uid);
  const privateRef = userRef.collection("private").doc("profile");
  const settingsRef = userRef.collection("private").doc("profile_settings");
  const current = await userRef.get();
  if (!current.exists || current.get("moderationState") !== "active") {
    throw new HttpsError("failed-precondition", "Your profile is unavailable.");
  }
  await Promise.all([
    validateChangedMedia(
      uid,
      current,
      input.avatarUrl,
      input.avatarStoragePath,
      "avatarUrl",
      `users/${uid}/avatar/`,
    ),
    validateChangedMedia(
      uid,
      current,
      input.coverUrl,
      input.coverStoragePath,
      "coverUrl",
      `users/${uid}/cover/`,
    ),
  ]);

  await database.runTransaction(async (transaction) => {
    const [profile, privateProfile] = await Promise.all([
      transaction.get(userRef),
      transaction.get(privateRef),
    ]);
    if (!profile.exists) {
      throw new HttpsError("not-found", "Your profile is unavailable.");
    }
    const now = Timestamp.now();
    const oldNormalized = String(profile.get("usernameNormalized") ?? "");
    const usernameChanged = input.usernameNormalized !== undefined &&
      input.usernameNormalized !== oldNormalized;
    if (usernameChanged) {
      const changedAt = privateProfile.get("usernameChangedAt");
      if (changedAt instanceof Timestamp) {
        const nextAllowed = changedAt.toMillis() + 14 * 24 * 60 * 60 * 1000;
        if (nextAllowed > Date.now()) {
          throw new HttpsError(
            "failed-precondition",
            "Usernames can be changed once every 14 days.",
          );
        }
      }
      const newReservation = database.collection(collections.usernames)
        .doc(input.usernameNormalized!);
      const reservation = await transaction.get(newReservation);
      if (reservation.exists && reservation.get("uid") !== uid) {
        throw new HttpsError("already-exists", "That username is already taken.");
      }
      transaction.set(newReservation, {
        uid,
        username: input.username,
        createdAt: reservation.get("createdAt") ?? now,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
      if (oldNormalized) {
        transaction.delete(
          database.collection(collections.usernames).doc(oldNormalized),
        );
      }
      transaction.set(privateRef, {
        uid,
        usernameChangedAt: now,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    }

    transaction.update(userRef, {
      "displayName": input.displayName,
      "bio": input.bio,
      "avatarUrl": input.avatarUrl ?? null,
      "coverUrl": input.coverUrl ?? null,
      "websiteUrl": input.websiteUrl ?? null,
      "primarySportId": input.primarySportId ?? null,
      "favoriteSportIds": input.favoriteSportIds,
      "goals": input.goals,
      "visibility": input.visibility,
      "followApprovalPolicy": input.privacy.followApprovalPolicy,
      "professionalDetails": input.professionalDetails,
      ...(usernameChanged ? {
        "username": input.username,
        "usernameNormalized": input.usernameNormalized,
      } : {}),
      "updatedAt": now,
    });
    transaction.set(
      settingsRef,
      privacyDocument(uid, input.privacy, now),
      {merge: true},
    );
  });

  await writeAuditEvent({
    actorId: uid,
    action: "profile.updated",
    targetType: "user",
    targetId: uid,
  });
  return {profile: callableProfile(await userRef.get())};
});

export const updateProfilePrivacy = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const privacy = parsePrivacy(data.privacy);
    const database = getFirestore();
    const userRef = database.collection(collections.users).doc(uid);
    const settingsRef = userRef.collection("private").doc("profile_settings");
    const now = Timestamp.now();
    const batch = database.batch();
    batch.set(
      settingsRef,
      privacyDocument(uid, privacy, now),
      {merge: true},
    );
    batch.update(userRef, {
      followApprovalPolicy: privacy.followApprovalPolicy,
      updatedAt: now,
    });
    await batch.commit();
    return {updated: true};
  },
);

function verificationType(value: unknown): "athlete" | "trainer" | "business" {
  if (value === "athlete" || value === "trainer" || value === "business") {
    return value;
  }
  throw new HttpsError("invalid-argument", "Verification type is invalid.");
}

interface VerificationEvidence {
  storagePath: string;
  label: string;
}

function verificationEvidence(value: unknown): VerificationEvidence[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > 6) {
    throw new HttpsError(
      "invalid-argument",
      "Attach between one and six verification documents.",
    );
  }
  return value.map((item) => {
    const data = recordValue(item);
    return {
      storagePath: safeString(data.storagePath, "Evidence path", 500, 1),
      label: safeString(data.label, "Evidence label", 80, 1),
    };
  });
}

export const submitVerificationRequest = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const requestedType = verificationType(data.requestedType);
    const legalName = safeString(data.legalName, "Legal name", 120, 2);
    const summary = safeString(data.summary, "Verification summary", 1500, 20);
    const evidence = verificationEvidence(data.evidence);
    await consumeRateLimit(uid, {
      key: "verification_request",
      maxAttempts: 5,
      windowSeconds: 30 * 24 * 60 * 60,
    });
    await Promise.all(evidence.map((item) => assertOwnedProfileAsset(
      uid,
      item.storagePath,
      `verification/${uid}/`,
    )));
    const database = getFirestore();
    const requestRef = database.collection(collections.verificationRequests)
      .doc(uid);
    const existing = await requestRef.get();
    if (existing.exists && existing.get("status") === "pending") {
      throw new HttpsError(
        "already-exists",
        "A verification request is already under review.",
      );
    }
    const now = Timestamp.now();
    await requestRef.set({
      uid,
      requestedType,
      status: "pending",
      legalName,
      summary,
      evidence,
      submittedAt: now,
      reviewedAt: null,
      rejectionReason: null,
      createdAt: existing.get("createdAt") ?? now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    await writeAuditEvent({
      actorId: uid,
      action: "profile.verification_submitted",
      targetType: "verification_request",
      targetId: uid,
    });
    return {requestId: uid};
  },
);

export const cancelVerificationRequest = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const requestId = safeDocumentId(data.requestId, "requestId");
    if (requestId !== uid) {
      throw new HttpsError("permission-denied", "This request is unavailable.");
    }
    const ref = getFirestore().collection(collections.verificationRequests)
      .doc(uid);
    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.get("status") !== "pending") {
        throw new HttpsError("not-found", "This request is unavailable.");
      }
      transaction.update(ref, {
        status: "canceled",
        updatedAt: Timestamp.now(),
      });
    });
    return {canceled: true};
  },
);

export const reviewVerificationRequest = onCall(
  callableOptions,
  async (request) => {
    const reviewerId = requireUid(request.auth?.uid);
    if (request.auth?.token.admin !== true) {
      throw new HttpsError("permission-denied", "Administrator access required.");
    }
    const data = recordValue(request.data);
    const uid = safeDocumentId(data.profileId, "profileId");
    const decision = data.decision;
    if (decision !== "approve" && decision !== "reject") {
      throw new HttpsError("invalid-argument", "Review decision is invalid.");
    }
    const rejectionReason = decision === "reject" ?
      safeString(data.rejectionReason, "Rejection reason", 500, 5) : undefined;
    const database = getFirestore();
    const requestRef = database.collection(collections.verificationRequests)
      .doc(uid);
    const userRef = database.collection(collections.users).doc(uid);
    let requestedType = "none";
    let alreadyReviewed = false;
    await database.runTransaction(async (transaction) => {
      const [verification, user] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(userRef),
      ]);
      if (!verification.exists) {
        throw new HttpsError("not-found", "This request is unavailable.");
      }
      if (!user.exists) {
        throw new HttpsError("not-found", "This profile is unavailable.");
      }
      requestedType = String(verification.get("requestedType") ?? "none");
      const expectedStatus = decision === "approve" ? "approved" : "rejected";
      const currentStatus = String(verification.get("status") ?? "");
      if (currentStatus === expectedStatus) {
        alreadyReviewed = true;
        return;
      }
      if (currentStatus !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This request was already reviewed with a different decision.",
        );
      }
      const now = Timestamp.now();
      transaction.update(requestRef, {
        status: expectedStatus,
        reviewedBy: reviewerId,
        reviewedAt: now,
        rejectionReason: rejectionReason ?? null,
        updatedAt: now,
      });
      if (decision === "approve") {
        transaction.update(userRef, {
          isVerified: true,
          verificationType: requestedType,
          role: requestedType,
          updatedAt: now,
        });
      }
    });
    if (decision === "approve") {
      const auth = getAuth();
      const user = await auth.getUser(uid);
      if (user.customClaims?.verified !== true ||
          user.customClaims?.verificationType !== requestedType) {
        await auth.setCustomUserClaims(uid, {
          ...(user.customClaims ?? {}),
          verified: true,
          verificationType: requestedType,
        });
      }
    }
    if (!alreadyReviewed) {
      await writeAuditEvent({
        actorId: reviewerId,
        action: `profile.verification_${decision}d`,
        targetType: "user",
        targetId: uid,
      });
    }
    return {reviewed: true, alreadyReviewed};
  },
);

async function updateSnapshotCollections(
  database: Firestore,
  uid: string,
  snapshot: Record<string, unknown>,
): Promise<void> {
  const [posts, stories] = await Promise.all([
    database.collection(collections.posts)
      .where("authorId", "==", uid)
      .orderBy("publishedAt", "desc")
      .limit(500)
      .get(),
    database.collection(collections.stories)
      .where("authorId", "==", uid)
      .orderBy("createdAt", "desc")
      .limit(200)
      .get(),
  ]);
  const documents = [...posts.docs, ...stories.docs];
  for (let offset = 0; offset < documents.length; offset += 400) {
    const batch = database.batch();
    for (const document of documents.slice(offset, offset + 400)) {
      batch.update(document.ref, {
        authorSnapshot: snapshot,
        updatedAt: Timestamp.now(),
      });
    }
    await batch.commit();
  }
}

export const syncProfileSnapshots = onDocumentUpdated(
  {
    document: "users/{uid}",
    region: callableOptions.region,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    const uid = event.params.uid;
    if (!before?.exists || !after?.exists) return;
    const keys = [
      "username",
      "displayName",
      "avatarUrl",
      "isVerified",
      "verificationType",
    ];
    if (keys.every((key) => before.get(key) === after.get(key))) return;
    await updateSnapshotCollections(getFirestore(), uid, {
      id: uid,
      username: String(after.get("username") ?? ""),
      displayName: String(after.get("displayName") ?? "Athlete"),
      ...(after.get("avatarUrl") ? {
        avatarUrl: String(after.get("avatarUrl")),
      } : {}),
      isVerified: after.get("isVerified") === true,
      verificationType: String(after.get("verificationType") ?? "none"),
    });
  },
);
