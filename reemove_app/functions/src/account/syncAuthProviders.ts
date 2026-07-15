import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections} from "../core/schema";

export const syncAuthProviders = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before syncing providers.");
  }

  await consumeRateLimit(uid, {
    key: "sync_auth_providers",
    maxAttempts: 20,
    windowSeconds: 60 * 60,
  });

  const authUser = await getAuth().getUser(uid);
  const providerIds = authUser.providerData
    .map((provider) => provider.providerId)
    .sort();
  const database = getFirestore();
  const privateProfile = database
    .collection(collections.users)
    .doc(uid)
    .collection("private")
    .doc("profile");
  const snapshot = await privateProfile.get();
  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Create your ReeMove profile before syncing providers.",
    );
  }

  const previous = snapshot.get("providerIds");
  const previousIds = Array.isArray(previous) ?
    previous.map(String).sort() : [];
  const now = Timestamp.now();
  await privateProfile.set({
    providerIds,
    lastSignInAt: now,
    updatedAt: now,
  }, {merge: true});

  if (JSON.stringify(previousIds) !== JSON.stringify(providerIds)) {
    await writeAuditEvent({
      actorId: uid,
      action: "auth.providers_changed",
      targetType: "user",
      targetId: uid,
      metadata: {providerIds},
    });
  }

  return {providerIds};
});
