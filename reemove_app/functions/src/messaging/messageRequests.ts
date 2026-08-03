import {
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {
  deliverMessageRequestAcceptedNotification,
  deliverMessageRequestInboxNotification,
  resolvePendingMessageRequestNotifications,
} from "../notifications/messageRequestNotifications";
import {isMessageAudienceAllowed} from "./messageAudiencePolicy";
import {ensureDirectConversationBetween} from "./conversations";
import {
  messageRequestId,
  purgeMessageRequestsBetween,
} from "./messageRequestCleanup";
import {
  activeProfileSnapshot,
  requireUid,
} from "./conversationAccess";
import {directConversationId} from "./messagingPolicy";
import type {ProfileAudience} from "../profile/profilePolicy";

export {messageRequestId, purgeMessageRequestsBetween};

function parseTargetUserId(data: unknown): string {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  const targetUserId = (data as Record<string, unknown>).targetUserId ??
    (data as Record<string, unknown>).profileId;
  if (typeof targetUserId !== "string" || !targetUserId.trim()) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }
  return targetUserId.trim();
}

function parseDecision(data: unknown): "accept" | "decline" {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  const decision = (data as Record<string, unknown>).decision;
  if (decision !== "accept" && decision !== "decline") {
    throw new HttpsError("invalid-argument", "decision must be accept or decline.");
  }
  return decision;
}

async function assertNotBlocked(
  database: Firestore,
  senderId: string,
  targetId: string,
): Promise<void> {
  const [senderBlock, targetBlock] = await Promise.all([
    database.doc(`users/${senderId}/blocks/${targetId}`).get(),
    database.doc(`users/${targetId}/blocks/${senderId}`).get(),
  ]);
  if (senderBlock.exists || targetBlock.exists) {
    throw new HttpsError(
      "failed-precondition",
      "This conversation is unavailable.",
    );
  }
}

async function privacyAudience(
  database: Firestore,
  uid: string,
  field: "messageAudience" | "messageRequestAudience",
  fallback: ProfileAudience,
): Promise<ProfileAudience> {
  const settings = await database.doc(`users/${uid}/private/profile_settings`).get();
  const value = String(settings.get(field) ?? fallback);
  if (value === "followers" || value === "noOne" || value === "everyone") {
    return value;
  }
  return fallback;
}

export const createMessageRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const targetUserId = parseTargetUserId(request.data);
  if (uid === targetUserId) {
    throw new HttpsError("invalid-argument", "You cannot message yourself.");
  }
  await consumeRateLimit(uid, {
    key: "create_message_request",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  await assertNotBlocked(database, uid, targetUserId);
  await activeProfileSnapshot(database, uid);
  await activeProfileSnapshot(database, targetUserId);

  const conversationId = directConversationId(uid, targetUserId);
  const existingConversation = await database.collection(collections.conversations)
    .doc(conversationId).get();
  if (existingConversation.exists) {
    const member = await existingConversation.ref.collection("members").doc(uid).get();
    if (member.exists && !member.get("removedAt")) {
      return {conversationId, existingConversation: true, created: false};
    }
  }

  const [directAudience, requestAudience, follows] = await Promise.all([
    privacyAudience(database, targetUserId, "messageAudience", "everyone"),
    privacyAudience(database, targetUserId, "messageRequestAudience", "noOne"),
    database.doc(`users/${targetUserId}/followers/${uid}`).get(),
  ]);

  if (isMessageAudienceAllowed(directAudience, follows.exists)) {
    const opened = await ensureDirectConversationBetween(database, uid, targetUserId);
    return {
      conversationId: opened.conversationId,
      existingConversation: opened.existing,
      created: false,
      direct: true,
    };
  }
  if (!isMessageAudienceAllowed(requestAudience, follows.exists)) {
    throw new HttpsError(
      "permission-denied",
      "This person is not accepting messages from your account.",
    );
  }

  const requestRef = database.collection(collections.messageRequests)
    .doc(messageRequestId(uid, targetUserId));
  const existing = await requestRef.get();
  if (existing.exists && existing.get("status") === "pending") {
    return {
      requestId: requestRef.id,
      status: "pending",
      created: false,
      existingRequest: true,
    };
  }

  const now = Timestamp.now();
  await requestRef.set({
    requesterId: uid,
    targetId: targetUserId,
    status: "pending",
    createdAt: existing.exists ? (existing.get("createdAt") ?? now) : now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });

  await deliverMessageRequestInboxNotification(uid, targetUserId);
  await writeAuditEvent({
    action: "messaging.message_requested",
    actorId: uid,
    targetType: "user",
    targetId: targetUserId,
    metadata: {requestId: requestRef.id},
  });

  return {
    requestId: requestRef.id,
    status: "pending",
    created: true,
    existingRequest: false,
  };
});

export const cancelMessageRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const targetUserId = parseTargetUserId(request.data);
  const database = getFirestore();
  const requestRef = database.collection(collections.messageRequests)
    .doc(messageRequestId(uid, targetUserId));
  const existing = await requestRef.get();
  if (!existing.exists || existing.get("status") !== "pending") {
    return {cancelled: false};
  }
  if (existing.get("requesterId") !== uid) {
    throw new HttpsError("permission-denied", "Only the requester can cancel.");
  }
  await requestRef.delete();
  await resolvePendingMessageRequestNotifications(targetUserId, uid);
  return {cancelled: true};
});

export const respondToMessageRequest = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  if (typeof request.data !== "object" || request.data === null) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  const body = request.data as Record<string, unknown>;
  const requesterId = typeof body.requesterId === "string" ?
    body.requesterId.trim() :
    (typeof body.profileId === "string" ? body.profileId.trim() : "");
  if (!requesterId) {
    throw new HttpsError("invalid-argument", "requesterId is required.");
  }
  const decision = parseDecision(request.data);
  if (uid === requesterId) {
    throw new HttpsError("invalid-argument", "Invalid message request.");
  }

  const database = getFirestore();
  await assertNotBlocked(database, uid, requesterId);
  const requestRef = database.collection(collections.messageRequests)
    .doc(messageRequestId(requesterId, uid));
  const existing = await requestRef.get();
  if (!existing.exists || existing.get("status") !== "pending") {
    throw new HttpsError("not-found", "This message request is no longer pending.");
  }
  if (existing.get("targetId") !== uid) {
    throw new HttpsError("permission-denied", "Only the recipient can respond.");
  }

  await resolvePendingMessageRequestNotifications(uid, requesterId);

  if (decision === "decline") {
    await requestRef.delete();
    await writeAuditEvent({
      action: "messaging.message_request_declined",
      actorId: uid,
      targetType: "user",
      targetId: requesterId,
      metadata: {},
    });
    // Decline is silent to the requester — no notification.
    return {decision: "decline", conversationId: null};
  }

  const opened = await ensureDirectConversationBetween(database, uid, requesterId);
  await requestRef.delete();
  await deliverMessageRequestAcceptedNotification(
    requesterId,
    uid,
    opened.conversationId,
  );
  await writeAuditEvent({
    action: "messaging.message_request_accepted",
    actorId: uid,
    targetType: "conversation",
    targetId: opened.conversationId,
    metadata: {requesterId},
  });
  return {
    decision: "accept",
    conversationId: opened.conversationId,
    existing: opened.existing,
  };
});
