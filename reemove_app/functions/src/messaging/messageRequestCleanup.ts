import {
  getFirestore,
  type Firestore,
} from "firebase-admin/firestore";

import {collections} from "../core/schema";
import {resolvePendingMessageRequestNotifications} from "../notifications/messageRequestNotifications";

export function messageRequestId(requesterId: string, targetId: string): string {
  return `${requesterId}--${targetId}`;
}

/**
 * Deletes pending message requests in either direction (used on block).
 * Kept separate from callable handlers so followGraph does not pull messaging onCall modules.
 */
export async function purgeMessageRequestsBetween(
  database: Firestore,
  userA: string,
  userB: string,
): Promise<void> {
  const ids = [
    messageRequestId(userA, userB),
    messageRequestId(userB, userA),
  ];
  const batch = database.batch();
  for (const id of ids) {
    batch.delete(database.collection(collections.messageRequests).doc(id));
  }
  await batch.commit();
  await Promise.all([
    resolvePendingMessageRequestNotifications(userA, userB),
    resolvePendingMessageRequestNotifications(userB, userA),
  ]);
}

export function messageRequestsCollection(database: Firestore = getFirestore()) {
  return database.collection(collections.messageRequests);
}
