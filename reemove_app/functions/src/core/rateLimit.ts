import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {collections, currentSchemaVersion} from "./schema";

export type RateLimitPolicy = {
  key: string;
  maxAttempts: number;
  windowSeconds: number;
};

export async function consumeRateLimit(
  uid: string,
  policy: RateLimitPolicy,
): Promise<void> {
  const database = getFirestore();
  const documentId = `${uid}_${policy.key}`;
  const reference = database.collection(collections.rateLimits).doc(documentId);
  const now = Timestamp.now();
  const windowMilliseconds = policy.windowSeconds * 1000;

  await database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const previousWindow = snapshot.exists ?
      snapshot.get("windowStartedAt") : undefined;
    const previousCount = snapshot.exists ? snapshot.get("count") : undefined;
    const windowStartedAt = previousWindow instanceof Timestamp ?
      previousWindow : now;
    const count = typeof previousCount === "number" ? previousCount : 0;
    const windowExpired = now.toMillis() - windowStartedAt.toMillis() >=
      windowMilliseconds;

    if (!windowExpired && count >= policy.maxAttempts) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many account requests. Try again later.",
      );
    }

    transaction.set(reference, {
      uid,
      action: policy.key,
      count: windowExpired ? 1 : count + 1,
      windowStartedAt: windowExpired ? now : windowStartedAt,
      expiresAt: Timestamp.fromMillis(now.toMillis() + windowMilliseconds * 2),
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  });
}
