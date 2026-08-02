import {createHash} from "node:crypto";

import {
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";

import {collections, currentSchemaVersion} from "../core/schema";
import {createAndDeliverNotification} from "./notificationService";

export function followRequestPendingEventId(
  requesterId: string,
  targetId: string,
): string {
  return `follow_request_pending_${requesterId}_${targetId}`;
}

export function followRequestAcceptedEventId(
  requesterId: string,
  targetId: string,
): string {
  return `follow_request_accepted_${requesterId}_${targetId}`;
}

function eventDocId(eventId: string): string {
  return createHash("sha256").update(eventId).digest("hex");
}

/**
 * Clears a stale pending-request idempotency event when its inbox item was
 * soft-deleted or removed. Without this, a later re-request between the same
 * pair silently skips inbox delivery.
 */
export async function clearStaleFollowRequestPendingEvent(
  targetId: string,
  requesterId: string,
): Promise<{cleared: boolean; reason?: string}> {
  if (!targetId || !requesterId) return {cleared: false};
  const database = getFirestore();
  const eventId = followRequestPendingEventId(requesterId, targetId);
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
  if (notification.get("kind") !== "follow_request") {
    await eventRef.delete();
    return {cleared: true, reason: "notification_wrong_kind"};
  }
  return {cleared: false, reason: "active_pending_notification"};
}

/**
 * Inbox notification for the private profile owner only.
 * Never notifies the requester about their own outbound request.
 */
export async function deliverFollowRequestInboxNotification(
  requesterId: string,
  targetId: string,
): Promise<{created: boolean; notificationId?: string}> {
  if (!requesterId || !targetId || requesterId === targetId) {
    return {created: false};
  }
  await clearStaleFollowRequestPendingEvent(targetId, requesterId);

  const requestId = `${requesterId}--${targetId}`;
  const requester = await getFirestore().collection(collections.users)
    .doc(requesterId).get();
  const username = String(requester.get("username") ?? "Someone");
  const displayName = String(requester.get("displayName") ?? username);
  return createAndDeliverNotification({
    eventId: followRequestPendingEventId(requesterId, targetId),
    recipientId: targetId,
    actorId: requesterId,
    category: "activity",
    kind: "follow_request",
    title: "Follow request",
    body: `${displayName} (@${username}) requested to follow you.`,
    route: `/profile/user/${encodeURIComponent(username.toLowerCase())}`,
    groupKey: `follow_request_pending:${requesterId}`,
    entityType: "user",
    entityId: requesterId,
    data: {
      profileId: requesterId,
      requesterId,
      targetId,
      requestId,
      status: "pending",
      source: "follow_request_pending",
    },
  });
}

/**
 * Informational notification for the requester after acceptance.
 * Must never include Accept/Decline affordances (distinct kind).
 */
export async function deliverFollowRequestAcceptedNotification(
  requesterId: string,
  targetId: string,
): Promise<{created: boolean; notificationId?: string}> {
  if (!requesterId || !targetId || requesterId === targetId) {
    return {created: false};
  }
  const requestId = `${requesterId}--${targetId}`;
  const target = await getFirestore().collection(collections.users)
    .doc(targetId).get();
  const username = String(target.get("username") ?? "Someone");
  const displayName = String(target.get("displayName") ?? username);
  return createAndDeliverNotification({
    eventId: followRequestAcceptedEventId(requesterId, targetId),
    recipientId: requesterId,
    actorId: targetId,
    category: "activity",
    kind: "follow_request_accepted",
    title: "Follow request accepted",
    body: `${displayName} (@${username}) accepted your follow request.`,
    route: `/profile/user/${encodeURIComponent(username.toLowerCase())}`,
    groupKey: `follow_request_accepted:${targetId}`,
    entityType: "user",
    entityId: targetId,
    data: {
      profileId: targetId,
      requesterId,
      targetId,
      requestId,
      status: "accepted",
      source: "follow_request_accepted",
    },
  });
}

/**
 * Soft-delete the target's pending follow_request inbox items for a requester
 * and keep unread summary consistent.
 */
export async function resolvePendingFollowRequestNotifications(
  targetId: string,
  requesterId: string,
): Promise<number> {
  if (!targetId || !requesterId) return 0;
  const database = getFirestore();
  const notifications = await database.collection("users").doc(targetId)
    .collection("notifications")
    .where("kind", "==", "follow_request")
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

  // Always clear the pending-event idempotency key so a later re-request can
  // deliver a fresh inbox item.
  const eventId = followRequestPendingEventId(requesterId, targetId);
  batch.delete(database.doc(
    `users/${targetId}/notification_events/${eventDocId(eventId)}`,
  ));
  await batch.commit();

  if (resolvedUnread > 0) {
    const summaryRef = database.doc(
      `users/${targetId}/private/notification_summary`,
    );
    await database.runTransaction(async (transaction) => {
      const summary = await transaction.get(summaryRef);
      const unread = summary.exists ?
        Math.max(0, Number(summary.get("unreadCount") ?? 0) - resolvedUnread) :
        0;
      transaction.set(summaryRef, {
        uid: targetId,
        unreadCount: unread,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    });
  }
  return matching.length;
}

/**
 * Soft-delete orphan "New follower" inbox items when the follower edge no
 * longer exists (unfollow / remove follower).
 */
export async function resolveOrphanNewFollowerNotifications(
  recipientId: string,
  actorId: string,
): Promise<number> {
  if (!recipientId || !actorId) return 0;
  const database = getFirestore();
  const edge = await database.doc(
    `users/${recipientId}/followers/${actorId}`,
  ).get();
  if (edge.exists) return 0;

  const notifications = await database.collection("users").doc(recipientId)
    .collection("notifications")
    .where("kind", "==", "new_follower")
    .limit(50)
    .get();
  if (notifications.empty) return 0;

  const matching = notifications.docs.filter((document) => {
    if (document.get("deletedAt") instanceof Timestamp) return false;
    return String(document.get("entityId") ?? "") === actorId ||
      String(document.get("data")?.profileId ?? "") === actorId;
  });
  if (matching.length === 0) return 0;

  const now = Timestamp.now();
  let resolvedUnread = 0;
  const batch = database.batch();
  for (const document of matching) {
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
        status: "orphaned",
        relationshipStatus: "missing",
      },
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  }
  await batch.commit();

  if (resolvedUnread > 0) {
    const summaryRef = database.doc(
      `users/${recipientId}/private/notification_summary`,
    );
    await database.runTransaction(async (transaction) => {
      const summary = await transaction.get(summaryRef);
      const unread = summary.exists ?
        Math.max(0, Number(summary.get("unreadCount") ?? 0) - resolvedUnread) :
        0;
      transaction.set(summaryRef, {
        uid: recipientId,
        unreadCount: unread,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    });
  }
  return matching.length;
}
