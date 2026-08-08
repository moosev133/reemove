import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {writeAuditEvent} from "../core/audit";
import {callableOptions, primaryRegion} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {
  assertConversationMember,
  requireUid,
} from "../messaging/conversationAccess";
import {assertNotBlocked} from "./groupsAccess";
import {asRecord, requiredString} from "./groupsPolicy";
import {
  assertSportsChannelPublishAccess,
  groupChannelStoragePrefix,
  loadSportsConversationContext,
  parseGroupMediaMode,
  sportsGroupConversationSource,
} from "./groupChannelAccess";
import {ensureGroupChannelsMaterialized} from "./groupChannels";

/**
 * Screenshot / screen-recording prevention cannot be guaranteed on any client
 * OS. view_once only limits durable download URLs and one-time claim access.
 */

export const viewOnceSignedUrlTtlMs = 60_000;
export const groupMediaAccessUrlTtlMs = 10 * 60_000;
export const abandonedGroupMediaHours = 24;

function claimDocId(uid: string, attachmentId: string): string {
  return `${uid}--${attachmentId}`;
}

export const createGroupMediaUpload = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const channelType = requiredString(body.channelType, "channelType", 32);
  if (channelType !== "member_chat" && channelType !== "announcements") {
    throw new HttpsError("invalid-argument", "channelType is invalid.");
  }
  const messageId = requiredString(body.messageId, "messageId", 128);
  const attachmentId = requiredString(body.attachmentId, "attachmentId", 128);
  const kind = requiredString(body.kind, "kind", 16);
  if (kind !== "image" && kind !== "video" && kind !== "audio") {
    throw new HttpsError("invalid-argument", "kind is invalid.");
  }
  const contentType = requiredString(body.contentType, "contentType", 255);
  const filename = requiredString(body.filename ?? "upload.bin", "filename", 180)
    .replace(/[^\w.\-]+/g, "_");
  const mediaMode = parseGroupMediaMode(body.mediaMode ?? "normal");
  const sizeBytes = typeof body.sizeBytes === "number" &&
      Number.isInteger(body.sizeBytes) ?
    body.sizeBytes :
    -1;

  await consumeRateLimit(uid, {
    key: "create_group_media_upload",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });

  await ensureGroupChannelsMaterialized(groupId);
  const access = await assertSportsChannelPublishAccess({
    groupId,
    channelType,
    uid,
    mediaMode,
  });

  const maximum = kind === "image" ? 15 * 1024 * 1024 :
    kind === "audio" ? 25 * 1024 * 1024 : 100 * 1024 * 1024;
  if (sizeBytes <= 0 || sizeBytes > maximum) {
    throw new HttpsError("invalid-argument", "Attachment size is invalid.");
  }
  if (!contentType.startsWith(`${kind}/`)) {
    throw new HttpsError("invalid-argument", "Attachment content type is invalid.");
  }
  if (mediaMode === "view_once" && channelType === "announcements") {
    throw new HttpsError(
      "failed-precondition",
      "Announcements cannot use view-once media.",
    );
  }

  const storagePath =
    `${groupChannelStoragePrefix(groupId, channelType, messageId, attachmentId)}/${filename}`;
  const metadata = {
    ownerId: uid,
    groupId,
    channelType,
    conversationId: access.conversationId,
    messageId,
    assetId: attachmentId,
    kind,
    mediaMode,
    schemaVersion: String(currentSchemaVersion),
  };

  const now = Timestamp.now();
  const pendingRef = getFirestore()
    .collection(collections.groups)
    .doc(groupId)
    .collection("pending_media")
    .doc(`${messageId}--${attachmentId}`);
  await pendingRef.set({
    groupId,
    channelType,
    conversationId: access.conversationId,
    messageId,
    attachmentId,
    storagePath,
    ownerId: uid,
    kind,
    mediaMode,
    contentType,
    sizeBytes,
    status: "pending",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });

  return {
    storagePath,
    // Both keys are populated for client compatibility; requiredMetadata /
    // uploadPath match the naming used in the Phase C2 design doc.
    metadata,
    requiredMetadata: metadata,
    uploadPath: storagePath,
    maxBytes: maximum,
    contentTypePrefix: `${kind}/`,
    conversationId: access.conversationId,
    expiresHintHours: abandonedGroupMediaHours,
  };
});

/** Alias matching the Phase C2 design doc naming (`prepareGroupMediaUpload`). */
export const prepareGroupMediaUpload = createGroupMediaUpload;

export const finalizeGroupMediaUpload = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const channelType = requiredString(body.channelType, "channelType", 32);
  const messageId = requiredString(body.messageId, "messageId", 128);
  const attachmentId = requiredString(body.attachmentId, "attachmentId", 128);
  const storagePath = requiredString(body.storagePath, "storagePath", 1024);
  const mediaMode = parseGroupMediaMode(body.mediaMode ?? "normal");

  await consumeRateLimit(uid, {
    key: "finalize_group_media_upload",
    maxAttempts: 200,
    windowSeconds: 60 * 60,
  });

  const access = await assertSportsChannelPublishAccess({
    groupId,
    channelType: channelType === "announcements" ? "announcements" : "member_chat",
    uid,
    mediaMode,
  });

  const expectedPrefix = groupChannelStoragePrefix(
    groupId,
    channelType === "announcements" ? "announcements" : "member_chat",
    messageId,
    attachmentId,
  );
  if (!storagePath.startsWith(`${expectedPrefix}/`)) {
    throw new HttpsError("invalid-argument", "Attachment path is invalid.");
  }

  const [metadata] = await getStorage().bucket().file(storagePath).getMetadata();
  const custom = metadata.metadata ?? {};
  if (
    custom.ownerId !== uid ||
    custom.groupId !== groupId ||
    custom.conversationId !== access.conversationId ||
    custom.messageId !== messageId ||
    custom.assetId !== attachmentId ||
    custom.schemaVersion !== String(currentSchemaVersion)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Attachment ownership or metadata could not be verified.",
    );
  }

  const pendingRef = getFirestore()
    .collection(collections.groups)
    .doc(groupId)
    .collection("pending_media")
    .doc(`${messageId}--${attachmentId}`);
  await pendingRef.set({
    status: "finalized",
    finalizedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  }, {merge: true});

  return {
    ok: true,
    storagePath,
    mediaMode: String(custom.mediaMode ?? mediaMode),
    kind: String(custom.kind ?? ""),
    contentType: String(metadata.contentType ?? ""),
    sizeBytes: Number(metadata.size ?? 0),
  };
});

export const claimViewOnceMedia = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const conversationId = requiredString(body.conversationId, "conversationId", 128);
  const messageId = requiredString(body.messageId, "messageId", 128);
  const attachmentId = requiredString(body.attachmentId, "attachmentId", 128);

  await consumeRateLimit(uid, {
    key: "claim_view_once_media",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });

  const access = await assertConversationMember(conversationId, uid);
  const conversation = access.conversation;
  // Ensures the caller is still an active sports-group member (denies
  // removed/kicked members even if a stale conversation membership lingers).
  const sports = await loadSportsConversationContext(conversation, uid);
  if (!sports) {
    throw new HttpsError(
      "failed-precondition",
      "View-once claims are only available for sports group channels.",
    );
  }

  const messageRef = conversation.ref.collection("messages").doc(messageId);
  const claimRef = messageRef.collection("view_once_claims")
    .doc(claimDocId(uid, attachmentId));

  // Blocks are checked against the message sender before consuming the
  // one-time claim so a block cannot be bypassed by racing the transaction.
  const preMessage = await messageRef.get();
  if (!preMessage.exists || preMessage.get("isDeleted") === true) {
    throw new HttpsError("not-found", "This message is unavailable.");
  }
  const senderId = String(preMessage.get("senderId") ?? "");
  if (senderId && senderId !== uid) {
    await assertNotBlocked(access.database, uid, senderId);
  }

  const result = await access.database.runTransaction(async (transaction) => {
    const [message, claim] = await Promise.all([
      transaction.get(messageRef),
      transaction.get(claimRef),
    ]);
    if (!message.exists || message.get("isDeleted") === true) {
      throw new HttpsError("not-found", "This message is unavailable.");
    }
    if (claim.exists) {
      throw new HttpsError(
        "already-exists",
        "This view-once attachment was already claimed.",
      );
    }
    const attachments = Array.isArray(message.get("attachments")) ?
      message.get("attachments") as Array<Record<string, unknown>> :
      [];
    const attachment = attachments.find((item) => item.id === attachmentId);
    if (!attachment) {
      throw new HttpsError("not-found", "This attachment is unavailable.");
    }
    if (attachment.mediaMode !== "view_once") {
      throw new HttpsError(
        "failed-precondition",
        "This attachment is not view-once media.",
      );
    }
    if (typeof attachment.storagePath !== "string" || !attachment.storagePath) {
      throw new HttpsError("failed-precondition", "Attachment path is missing.");
    }
    // Sender may re-open their own upload without consuming recipient claims.
    const isSender = message.get("senderId") === uid;
    if (!isSender) {
      const now = Timestamp.now();
      transaction.create(claimRef, {
        uid,
        attachmentId,
        conversationId,
        messageId,
        claimedAt: now,
        createdAt: now,
        schemaVersion: currentSchemaVersion,
      });
      transaction.set(messageRef, {
        viewOnceClaimCount: FieldValue.increment(1),
        updatedAt: now,
      }, {merge: true});
    }
    return {
      storagePath: String(attachment.storagePath),
      contentType: typeof attachment.contentType === "string" ?
        attachment.contentType :
        "application/octet-stream",
    };
  });

  const expiresAt = Date.now() + viewOnceSignedUrlTtlMs;
  const [url] = await getStorage().bucket().file(result.storagePath).getSignedUrl({
    action: "read",
    version: "v4",
    expires: expiresAt,
  });

  await writeAuditEvent({
    actorId: uid,
    action: "groups.view_once_claimed",
    targetType: "message",
    targetId: messageId,
    metadata: {conversationId, attachmentId},
  });

  return {
    url,
    expiresAt: new Date(expiresAt).toISOString(),
    contentType: result.contentType,
  };
});

/** Alias for clients that prefer openViewOnceAttachment naming. */
export const openViewOnceAttachment = claimViewOnceMedia;

/**
 * Member-only signed URL for `normal` / `keep_in_chat` group channel media.
 * `view_once` attachments must go through claimViewOnceMedia instead — this
 * callable refuses to serve them even if requested directly.
 */
export const getGroupMediaAccessUrl = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const conversationId = requiredString(body.conversationId, "conversationId", 128);
  const messageId = requiredString(body.messageId, "messageId", 128);
  const attachmentId = requiredString(body.attachmentId, "attachmentId", 128);

  await consumeRateLimit(uid, {
    key: "get_group_media_access_url",
    maxAttempts: 300,
    windowSeconds: 60 * 60,
  });

  const access = await assertConversationMember(conversationId, uid);
  const conversation = access.conversation;
  if (conversation.get("source") !== sportsGroupConversationSource) {
    throw new HttpsError(
      "failed-precondition",
      "This callable is only available for sports group channels.",
    );
  }
  // Ensures the caller is still an active sports-group member (denies
  // removed/kicked members even if a stale conversation membership lingers).
  await loadSportsConversationContext(conversation, uid);

  const messageRef = conversation.ref.collection("messages").doc(messageId);
  const message = await messageRef.get();
  if (!message.exists || message.get("isDeleted") === true) {
    throw new HttpsError("not-found", "This message is unavailable.");
  }
  const senderId = String(message.get("senderId") ?? "");
  if (senderId && senderId !== uid) {
    await assertNotBlocked(access.database, uid, senderId);
  }
  const attachments = Array.isArray(message.get("attachments")) ?
    message.get("attachments") as Array<Record<string, unknown>> :
    [];
  const attachment = attachments.find((item) => item.id === attachmentId);
  if (!attachment) {
    throw new HttpsError("not-found", "This attachment is unavailable.");
  }
  const mediaMode = String(attachment.mediaMode ?? "normal");
  if (mediaMode === "view_once") {
    throw new HttpsError(
      "failed-precondition",
      "Use claimViewOnceMedia to open view-once attachments.",
    );
  }
  const storagePath = typeof attachment.storagePath === "string" ?
    attachment.storagePath :
    "";
  if (!storagePath) {
    throw new HttpsError("failed-precondition", "Attachment path is missing.");
  }

  const expiresAt = Date.now() + groupMediaAccessUrlTtlMs;
  const [url] = await getStorage().bucket().file(storagePath).getSignedUrl({
    action: "read",
    version: "v4",
    expires: expiresAt,
  });
  return {
    url,
    expiresAt: new Date(expiresAt).toISOString(),
    contentType: typeof attachment.contentType === "string" ?
      attachment.contentType :
      "application/octet-stream",
  };
});

export async function cleanupAbandonedGroupMediaHelper(options?: {
  olderThanHours?: number;
  limit?: number;
}): Promise<{scanned: number; deleted: number}> {
  const olderThanHours = options?.olderThanHours ?? abandonedGroupMediaHours;
  const limit = options?.limit ?? 200;
  const cutoff = Timestamp.fromMillis(
    Date.now() - olderThanHours * 60 * 60 * 1000,
  );
  const database = getFirestore();
  const snapshot = await database.collectionGroup("pending_media")
    .where("status", "==", "pending")
    .where("createdAt", "<=", cutoff)
    .limit(limit)
    .get();

  let deleted = 0;
  const bucket = getStorage().bucket();
  for (const doc of snapshot.docs) {
    const storagePath = doc.get("storagePath");
    if (typeof storagePath === "string" && storagePath.startsWith("groups/")) {
      await bucket.file(storagePath).delete({ignoreNotFound: true}).catch(() => undefined);
    }
    await doc.ref.delete().catch(() => undefined);
    deleted += 1;
  }
  return {scanned: snapshot.size, deleted};
}

export const cleanupAbandonedGroupMedia = onSchedule(
  {
    region: primaryRegion,
    schedule: "every 6 hours",
    timeZone: "UTC",
    retryCount: 2,
  },
  async () => {
    const result = await cleanupAbandonedGroupMediaHelper();
    logger.info("Abandoned group media cleanup completed.", result);
  },
);
