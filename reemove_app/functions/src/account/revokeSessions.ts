import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections} from "../core/schema";
import {requireRecentAuthentication} from "./recentAuthentication";

export const revokeSessions = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before managing sessions.");
  }

  requireRecentAuthentication(request.auth?.token.auth_time);

  await consumeRateLimit(uid, {
    key: "revoke_sessions",
    maxAttempts: 5,
    windowSeconds: 60 * 60,
  });

  const auth = getAuth();
  await auth.revokeRefreshTokens(uid);
  const user = await auth.getUser(uid);
  const revokedAt = user.tokensValidAfterTime ?
    Timestamp.fromDate(new Date(user.tokensValidAfterTime)) : Timestamp.now();
  const database = getFirestore();
  await database
    .collection(collections.users)
    .doc(uid)
    .collection("private")
    .doc("profile")
    .set({
      sessionsRevokedAt: revokedAt,
      updatedAt: Timestamp.now(),
    }, {merge: true});

  await writeAuditEvent({
    actorId: uid,
    action: "auth.sessions_revoked",
    targetType: "user",
    targetId: uid,
    metadata: {revokedAt: revokedAt.toDate().toISOString()},
  });

  return {revokedAt: revokedAt.toMillis()};
});
