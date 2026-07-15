import {getAuth} from "firebase-admin/auth";
import type {Auth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import type {Firestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {writeAuditEvent} from "../core/audit";
import {callableOptions, primaryRegion} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {requireRecentAuthentication} from "./recentAuthentication";

const retryBatchSize = 100;

function isUserNotFound(error: unknown): boolean {
  return typeof error === "object" &&
    error !== null &&
    "code" in error &&
    String((error as {code?: unknown}).code) === "auth/user-not-found";
}

async function disableAuthUser(auth: Auth, uid: string): Promise<void> {
  try {
    await auth.updateUser(uid, {disabled: true});
  } catch (error: unknown) {
    if (!isUserNotFound(error)) throw error;
  }
}

async function deleteAuthUser(auth: Auth, uid: string): Promise<void> {
  try {
    await auth.deleteUser(uid);
  } catch (error: unknown) {
    if (!isUserNotFound(error)) throw error;
  }
}

async function completeAccountDeletion(
  database: Firestore,
  auth: Auth,
  uid: string,
  username: string | null,
): Promise<void> {
  const userRef = database.collection(collections.users).doc(uid);
  const deletionRef = database.collection(collections.accountDeletions).doc(uid);

  await database.recursiveDelete(userRef);

  if (username !== null) {
    const usernameRef = database.collection(collections.usernames).doc(username);
    const reservation = await usernameRef.get();
    if (reservation.get("uid") === uid) {
      await usernameRef.delete();
    }
  }

  await deleteAuthUser(auth, uid);
  const completedAt = Timestamp.now();
  await deletionRef.set({
    status: "completed",
    completedAt,
    updatedAt: completedAt,
    error: null,
  }, {merge: true});
  await writeAuditEvent({
    actorId: uid,
    action: "auth.account_deletion_completed",
    targetType: "user",
    targetId: uid,
  });
}

async function markDeletionFailed(
  database: Firestore,
  uid: string,
  error: unknown,
): Promise<void> {
  const now = Timestamp.now();
  await database.collection(collections.accountDeletions).doc(uid).set({
    status: "failed",
    error: error instanceof Error ? error.message : String(error),
    updatedAt: now,
  }, {merge: true});
  await writeAuditEvent({
    actorId: uid,
    action: "auth.account_deletion_failed",
    targetType: "user",
    targetId: uid,
  });
}

export const deleteAccount = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before deleting an account.");
  }
  requireRecentAuthentication(request.auth?.token.auth_time);
  await consumeRateLimit(uid, {
    key: "delete_account",
    maxAttempts: 3,
    windowSeconds: 24 * 60 * 60,
  });

  const database = getFirestore();
  const auth = getAuth();
  const userRef = database.collection(collections.users).doc(uid);
  const deletionRef = database.collection(collections.accountDeletions).doc(uid);
  const snapshot = await userRef.get();
  const usernameValue = snapshot.exists ? snapshot.get("usernameNormalized") : null;
  const username = typeof usernameValue === "string" ? usernameValue : null;
  const now = Timestamp.now();

  await deletionRef.set({
    uid,
    username,
    status: "processing",
    requestedAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  }, {merge: true});
  await writeAuditEvent({
    actorId: uid,
    action: "auth.account_deletion_requested",
    targetType: "user",
    targetId: uid,
  });

  try {
    // Prevent new sessions while retaining a server-retryable identity until
    // Firestore and username cleanup has completed.
    await disableAuthUser(auth, uid);
    await completeAccountDeletion(database, auth, uid, username);
    return {deleted: true};
  } catch (error: unknown) {
    await markDeletionFailed(database, uid, error);
    throw new HttpsError(
      "internal",
      "Account deletion has been queued for automatic retry.",
    );
  }
});

export const retryAccountDeletions = onSchedule({
  schedule: "every 6 hours",
  region: primaryRegion,
  timeZone: "UTC",
  retryCount: 3,
  maxInstances: 1,
}, async () => {
  const database = getFirestore();
  const auth = getAuth();
  const pending = await database
    .collection(collections.accountDeletions)
    .where("status", "in", ["processing", "failed"])
    .limit(retryBatchSize)
    .get();

  for (const document of pending.docs) {
    const uid = document.id;
    const usernameValue = document.get("username");
    const username = typeof usernameValue === "string" ? usernameValue : null;
    const attemptAt = Timestamp.now();
    await document.ref.set({
      status: "processing",
      lastRetryAt: attemptAt,
      updatedAt: attemptAt,
    }, {merge: true});

    try {
      await disableAuthUser(auth, uid);
      await completeAccountDeletion(database, auth, uid, username);
    } catch (error: unknown) {
      await markDeletionFailed(database, uid, error);
    }
  }
});
