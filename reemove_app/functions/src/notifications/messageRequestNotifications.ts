import {createHash} from "node:crypto";

import {
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";

import {collections, currentSchemaVersion} from "../core/schema";
import {createAndDeliverNotification} from "./notificationService";

export function messageRequestPendingEventId(
  requesterId: string,
  targetId: string,
): string {
  return `message_request_pending_${requesterId}_${targetId}`;
}

export function messageRequestAcceptedEventId(
  requesterId: string,
  targetId: string,
): string {
  return `message_request_accepted_${requesterId}_${targetId}`;
}

function eventDocId(eventId: string): string {
  return createHash("sha256").update(eventId).digest("hex");
}

export async function clearStaleMessageRequestPendingEvent(
  targetId: string,
  requesterId: string,
): Promise<{cleared: boolean; reason?: string}> {
  if (!targetId || !requesterId) return {cleared: false};
  const database = getFirestore();
  const eventId = messageRequestPendingEventId(requesterId, targetId);
  const eventRef = database.doc(
    `users/${targetId}/notification_events/${eventDocId(eventId)}`,
  );
  const event = await eventRef.get();
  if (!event.exists) return {cleared: false, reason: "missing_event"};

  const notificationId = String(event.get("notificationId") ?? "");
  if (!notificationId) {
    await eventRef.delete();
    return {cleared: true, reason: "event_without_notification"};
  }

  const notification = await database.doc(
    `users/${targetId}/notifications/${notificationId}`,
  ).get();
  if (!notification.exists) {
    await eventRef.delete();
    return {cleared: true, reason: "notification_missing"};
  }
  if (notification.get("deletedAt") instanceof Timestamp) {
    await eventRef.delete();
    return {cleared: true, reason: "notification_soft_deleted"};
  }
  const status = String(notification.get("data")?.status ?? "");
  if (status === "resolved" || status === "accepted" || status === "declined") {
    await eventRef.delete();
    return {cleared: true, reason: `notification_status_${status}`};
  }
  if (notification.get("kind") !== "message_request") {
    await eventRef.delete();
    return {cleared: true, reason: "notification_wrong_kind"};
  }
  return {cleared: false, reason: "active_pending_notification"};
}

export async function deliverMessageRequestInboxNotification(
  requesterId: string,
  targetId: string,
): Promise<{created: boolean; notificationId?: string}> {
  if (!requesterId || !targetId || requesterId === targetId) {
    return {created: false};
  }
  const database = getFirestore();
  const requestId = `${requesterId}--${targetId}`;
  const pendingRequest = await database.collection(collections.messageRequests)
    .doc(requestId)
    .get();
  if (!pendingRequest.exists || pendingRequest.get("status") !== "pending") {
    return {created: false};
  }
  await clearStaleMessageRequestPendingEvent(targetId, requesterId);

  const requester = await database.collection(collections.users)
    .doc(requesterId).get();
  const username = String(requester.get("username") ?? "Someone");
  const displayName = String(requester.get("displayName") ?? username);
  const delivered = await createAndDeliverNotification({
    eventId: messageRequestPendingEventId(requesterId, targetId),
    recipientId: targetId,
    actorId: requesterId,
    category: "activity",
    kind: "message_request",
    title: "Message request",
    body: `${displayName} (@${username}) wants to message you.`,
    route: `/profile/user/${encodeURIComponent(username.toLowerCase())}`,
    groupKey: `message_request_pending:${requesterId}`,
    entityType: "user",
    entityId: requesterId,
    data: {
      profileId: requesterId,
      requesterId,
      targetId,
      requestId,
      status: "pending",
      source: "message_request_pending",
    },
  });

  const stillPending = await database.collection(collections.messageRequests)
    .doc(requestId)
    .get();
  if (!stillPending.exists || stillPending.get("status") !== "pending") {
    await resolvePendingMessageRequestNotifications(targetId, requesterId);
    return {created: false};
  }
  return delivered;
}

export async function deliverMessageRequestAcceptedNotification(
  requesterId: string,
  targetId: string,
  conversationId: string,
): Promise<{created: boolean; notificationId?: string}> {
  if (!requesterId || !targetId || requesterId === targetId) {
    return {created: false};
  }
  const target = await getFirestore().collection(collections.users)
    .doc(targetId).get();
  const username = String(target.get("username") ?? "Someone");
  const displayName = String(target.get("displayName") ?? username);
  return createAndDeliverNotification({
    eventId: messageRequestAcceptedEventId(requesterId, targetId),
    recipientId: requesterId,
    actorId: targetId,
    category: "activity",
    kind: "message_request_accepted",
    title: "Message request accepted",
    body: `${displayName} (@${username}) accepted your message request.`,
    route: `/messages/${encodeURIComponent(conversationId)}`,
    groupKey: `message_request_accepted:${targetId}`,
    entityType: "conversation",
    entityId: conversationId,
    data: {
      profileId: targetId,
      requesterId,
      targetId,
      conversationId,
      status: "accepted",
      source: "message_request_accepted",
    },
  });
}

export async function resolvePendingMessageRequestNotifications(
  targetId: string,
  requesterId: string,
): Promise<number> {
  if (!targetId || !requesterId) return 0;
  const database = getFirestore();
  const notifications = await database.collection("users").doc(targetId)
    .collection("notifications")
    .where("kind", "==", "message_request")
    .limit(50)
    .get();

  const matching = notifications.docs.filter(
    (document) => String(document.get("entityId") ?? "") === requesterId,
  );

  const now = Timestamp.now();
  let resolvedUnread = 0;
  const batch = database.batch();
  for (const document of matching) {
    if (document.get("deletedAt") instanceof Timestamp) continue;
    const wasUnread = !(document.get("readAt") instanceof Timestamp);
    if (wasUnread) resolvedUnread += 1;
    const existingData = document.get("data");
    batch.set(document.ref, {
      deletedAt: now,
      updatedAt: now,
      readAt: document.get("readAt") instanceof Timestamp ?
        document.get("readAt") :
        now,
      data: {
        ...(existingData !== null && typeof existingData === "object" ?
          existingData as Record<string, unknown> :
          {}),
        status: "resolved",
      },
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  }

  if (matching.length === 0) return 0;
  batch.delete(database.doc(
    `users/${targetId}/notification_events/${eventDocId(
      messageRequestPendingEventId(requesterId, targetId),
    )}`,
  ));
  if (resolvedUnread > 0) {
    const summaryRef = database.doc(
      `users/${targetId}/private/notification_summary`,
    );
    const summary = await summaryRef.get();
    const current = Number(summary.get("unreadCount") ?? 0);
    batch.set(summaryRef, {
      uid: targetId,
      unreadCount: Math.max(0, current - resolvedUnread),
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  }
  await batch.commit();
  return matching.length;
}
