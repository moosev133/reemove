import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentData,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {activeProfileSnapshot, assertConversationMember, requireUid} from "./conversationAccess";
import {
  deletableMessageHours,
  editableMessageMinutes,
  messageKind,
  messagePreview,
  type AttachmentInput,
} from "./messagingPolicy";
import {
  parseEditRequest,
  parseMessageRequest,
  parseReactionRequest,
  parseReadRequest,
  parseReportRequest,
  parseSendRequest,
} from "./requestData";

async function activeMembers(
  conversationId: string,
): Promise<QueryDocumentSnapshot<DocumentData>[]> {
  const snapshot = await getFirestore().collection(collections.conversations)
    .doc(conversationId).collection("members").limit(100).get();
  return snapshot.docs.filter((item) => !item.get("removedAt"));
}

async function verifiedAttachments(options: {
  uid: string;
  conversationId: string;
  messageId: string;
  attachments: AttachmentInput[];
}): Promise<Record<string, unknown>[]> {
  const bucket = getStorage().bucket();
  const result: Record<string, unknown>[] = [];
  for (const attachment of options.attachments) {
    const expectedPrefix = `messages/${options.conversationId}/${options.messageId}/${attachment.id}/`;
    if (!attachment.storagePath.startsWith(expectedPrefix)) {
      throw new HttpsError("invalid-argument", "Attachment path is invalid.");
    }
    const [metadata] = await bucket.file(attachment.storagePath).getMetadata();
    const custom = metadata.metadata ?? {};
    const actualSize = Number(metadata.size ?? 0);
    if (custom.ownerId !== options.uid ||
        custom.conversationId !== options.conversationId ||
        custom.messageId !== options.messageId ||
        custom.assetId !== attachment.id ||
        custom.kind !== attachment.kind ||
        metadata.contentType !== attachment.contentType ||
        actualSize !== attachment.sizeBytes) {
      throw new HttpsError(
        "failed-precondition",
        "Attachment ownership or metadata could not be verified.",
      );
    }
    const maximum = attachment.kind === "image" ? 15 * 1024 * 1024 :
      attachment.kind === "audio" ? 25 * 1024 * 1024 : 100 * 1024 * 1024;
    if (actualSize <= 0 || actualSize > maximum) {
      throw new HttpsError("invalid-argument", "Attachment size is invalid.");
    }
    const expectedContentPrefix = `${attachment.kind}/`;
    if (!attachment.contentType.startsWith(expectedContentPrefix)) {
      throw new HttpsError("invalid-argument", "Attachment content type is invalid.");
    }
    result.push({
      id: attachment.id,
      storagePath: attachment.storagePath,
      contentType: attachment.contentType,
      sizeBytes: actualSize,
      kind: attachment.kind,
      processingState: "ready",
    });
  }
  return result;
}

async function replyPreview(options: {
  conversationId: string;
  messageId?: string;
}): Promise<Record<string, unknown> | undefined> {
  if (!options.messageId) return undefined;
  const snapshot = await getFirestore().doc(
    `conversations/${options.conversationId}/messages/${options.messageId}`,
  ).get();
  if (!snapshot.exists || snapshot.get("isDeleted") === true) {
    throw new HttpsError("failed-precondition", "The replied-to message is unavailable.");
  }
  const sender = snapshot.get("senderSnapshot") as Record<string, unknown> | undefined;
  const kind = String(snapshot.get("kind") ?? "text");
  return {
    messageId: snapshot.id,
    senderId: String(snapshot.get("senderId") ?? ""),
    senderDisplayName: String(sender?.displayName ?? "Athlete"),
    kind,
    preview: messagePreview(
      kind === "image" || kind === "video" || kind === "audio" ? kind : "text",
      String(snapshot.get("text") ?? ""),
    ),
  };
}

export const sendMessage = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseSendRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  await consumeRateLimit(uid, {
    key: "send_message",
    maxAttempts: 300,
    windowSeconds: 60 * 60,
  });
  const database = access.database;
  const messageRef = access.conversation.ref.collection("messages")
    .doc(parsed.clientMessageId);
  const existing = await messageRef.get();
  if (existing.exists) {
    if (existing.get("senderId") !== uid) {
      throw new HttpsError("already-exists", "This message ID is already in use.");
    }
    return {messageId: messageRef.id, created: false};
  }

  const [sender, attachments, reply, members] = await Promise.all([
    activeProfileSnapshot(database, uid),
    verifiedAttachments({
      uid,
      conversationId: parsed.conversationId,
      messageId: parsed.clientMessageId,
      attachments: parsed.attachments,
    }),
    replyPreview({
      conversationId: parsed.conversationId,
      messageId: parsed.replyToMessageId,
    }),
    activeMembers(parsed.conversationId),
  ]);
  if (members.length === 0 || !members.some((item) => item.id === uid)) {
    throw new HttpsError("permission-denied", "You are not a member of this conversation.");
  }
  const kind = messageKind(parsed.text, parsed.attachments);
  const now = Timestamp.now();
  const lastMessage = {
    id: messageRef.id,
    senderId: uid,
    kind,
    preview: messagePreview(kind, parsed.text),
    sentAt: now,
  };

  await database.runTransaction(async (transaction) => {
    const latest = await transaction.get(messageRef);
    if (latest.exists) return;
    transaction.create(messageRef, {
      conversationId: parsed.conversationId,
      senderId: uid,
      senderSnapshot: sender,
      kind,
      text: parsed.text,
      attachments,
      ...(reply ? {replyTo: reply} : {}),
      reactionCounts: {},
      isDeleted: false,
      moderationState: "active",
      sentAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(access.conversation.ref, {
      lastMessage,
      updatedAt: now,
    });
    for (const member of members) {
      const isSender = member.id === uid;
      transaction.set(
        database.doc(`users/${member.id}/conversation_inbox/${parsed.conversationId}`),
        {
          lastMessage,
          updatedAt: now,
          isArchived: false,
          archivedAt: FieldValue.delete(),
          unreadCount: isSender ? 0 : FieldValue.increment(1),
        },
        {merge: true},
      );
      transaction.set(
        member.ref,
        {
          updatedAt: now,
          archivedAt: FieldValue.delete(),
          unreadCount: isSender ? 0 : FieldValue.increment(1),
        },
        {merge: true},
      );
    }
  });
  return {messageId: messageRef.id, created: true};
});

export const editMessage = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseEditRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  await consumeRateLimit(uid, {
    key: "edit_message",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });
  const messageRef = access.conversation.ref.collection("messages").doc(parsed.messageId);
  const message = await messageRef.get();
  if (!message.exists || message.get("isDeleted") === true) {
    throw new HttpsError("not-found", "This message is unavailable.");
  }
  if (message.get("senderId") !== uid || message.get("kind") !== "text") {
    throw new HttpsError("permission-denied", "This message cannot be edited.");
  }
  const sentAt = message.get("sentAt");
  if (!(sentAt instanceof Timestamp) ||
      Timestamp.now().toMillis() - sentAt.toMillis() > editableMessageMinutes * 60 * 1000) {
    throw new HttpsError("failed-precondition", "The editing window has closed.");
  }
  const now = Timestamp.now();
  const batch = access.database.batch();
  batch.update(messageRef, {text: parsed.text, editedAt: now, updatedAt: now});
  if (access.conversation.get("lastMessage.id") === parsed.messageId) {
    const lastMessage = {
      id: parsed.messageId,
      senderId: uid,
      kind: "text",
      preview: messagePreview("text", parsed.text),
      sentAt,
    };
    batch.update(access.conversation.ref, {lastMessage, updatedAt: now});
    const members = await activeMembers(parsed.conversationId);
    for (const member of members) {
      batch.set(
        access.database.doc(`users/${member.id}/conversation_inbox/${parsed.conversationId}`),
        {lastMessage, updatedAt: now},
        {merge: true},
      );
    }
  }
  await batch.commit();
  return {updated: true};
});

export const deleteMessage = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseMessageRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  const messageRef = access.conversation.ref.collection("messages").doc(parsed.messageId);
  const message = await messageRef.get();
  if (!message.exists || message.get("isDeleted") === true) return {deleted: true};
  const isSender = message.get("senderId") === uid;
  const role = access.member.get("role");
  const isAdmin = role === "owner" || role === "admin";
  const sentAt = message.get("sentAt");
  const withinWindow = sentAt instanceof Timestamp &&
    Timestamp.now().toMillis() - sentAt.toMillis() <= deletableMessageHours * 60 * 60 * 1000;
  if ((!isSender || !withinWindow) && !isAdmin) {
    throw new HttpsError("permission-denied", "This message cannot be deleted.");
  }
  const attachments = Array.isArray(message.get("attachments")) ?
    message.get("attachments") as Array<Record<string, unknown>> : [];
  const now = Timestamp.now();
  const batch = access.database.batch();
  batch.update(messageRef, {
    kind: "deleted",
    text: "",
    attachments: [],
    replyTo: FieldValue.delete(),
    isDeleted: true,
    deletedAt: now,
    deletedBy: uid,
    updatedAt: now,
  });
  if (access.conversation.get("lastMessage.id") === parsed.messageId) {
    const lastMessage = {
      id: parsed.messageId,
      senderId: String(message.get("senderId") ?? uid),
      kind: "deleted",
      preview: "Message deleted",
      sentAt: sentAt instanceof Timestamp ? sentAt : now,
    };
    batch.update(access.conversation.ref, {lastMessage, updatedAt: now});
    const members = await activeMembers(parsed.conversationId);
    for (const member of members) {
      batch.set(
        access.database.doc(`users/${member.id}/conversation_inbox/${parsed.conversationId}`),
        {lastMessage, updatedAt: now},
        {merge: true},
      );
    }
  }
  await batch.commit();

  await Promise.allSettled(attachments.map(async (item) => {
    const path = item.storagePath;
    if (typeof path === "string" &&
        path.startsWith(`messages/${parsed.conversationId}/${parsed.messageId}/`)) {
      await getStorage().bucket().file(path).delete({ignoreNotFound: true});
    }
  }));
  await writeAuditEvent({
    actorId: uid,
    action: "messaging.message_deleted",
    targetType: "message",
    targetId: parsed.messageId,
    metadata: {conversationId: parsed.conversationId, adminDelete: !isSender},
  });
  return {deleted: true};
});

export const toggleMessageReaction = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseReactionRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  await consumeRateLimit(uid, {
    key: "message_reaction",
    maxAttempts: 400,
    windowSeconds: 60 * 60,
  });
  const messageRef = access.conversation.ref.collection("messages").doc(parsed.messageId);
  const reactionRef = messageRef.collection("reactions").doc(uid);
  const mirrorRef = access.database.doc(
    `users/${uid}/message_reactions/${parsed.conversationId}--${parsed.messageId}`,
  );

  const result = await access.database.runTransaction(async (transaction) => {
    const [message, reaction] = await Promise.all([
      transaction.get(messageRef),
      transaction.get(reactionRef),
    ]);
    if (!message.exists || message.get("isDeleted") === true) {
      throw new HttpsError("not-found", "This message is unavailable.");
    }
    const previous = Array.isArray(reaction.get("emojis")) ?
      (reaction.get("emojis") as unknown[]).filter((item): item is string => typeof item === "string") : [];
    const active = !previous.includes(parsed.emoji);
    const emojis = active ? [...previous, parsed.emoji] :
      previous.filter((item) => item !== parsed.emoji);
    const currentCounts = message.get("reactionCounts") as Record<string, unknown> | undefined;
    const counts: Record<string, number> = {};
    for (const [emoji, value] of Object.entries(currentCounts ?? {})) {
      counts[emoji] = typeof value === "number" ? Math.max(0, Math.trunc(value)) : 0;
    }
    counts[parsed.emoji] = Math.max(0, (counts[parsed.emoji] ?? 0) + (active ? 1 : -1));
    if (counts[parsed.emoji] === 0) delete counts[parsed.emoji];
    const now = Timestamp.now();
    if (emojis.length === 0) {
      transaction.delete(reactionRef);
      transaction.delete(mirrorRef);
    } else {
      const value = {
        uid,
        conversationId: parsed.conversationId,
        messageId: parsed.messageId,
        emojis,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      };
      transaction.set(reactionRef, value, {merge: true});
      transaction.set(mirrorRef, value, {merge: true});
    }
    transaction.update(messageRef, {reactionCounts: counts, updatedAt: now});
    return {active, counts};
  });
  return result;
});

export const markConversationRead = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseReadRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  const message = await access.conversation.ref.collection("messages")
    .doc(parsed.messageId).get();
  if (!message.exists) {
    throw new HttpsError("not-found", "This message is unavailable.");
  }
  const sentAt = message.get("sentAt");
  if (!(sentAt instanceof Timestamp)) {
    throw new HttpsError("failed-precondition", "This message has invalid timing data.");
  }
  const now = Timestamp.now();
  await access.database.runTransaction(async (transaction) => {
    const member = await transaction.get(access.member.ref);
    const previousMessageAt = member.get("lastReadMessageSentAt");
    if (previousMessageAt instanceof Timestamp &&
        previousMessageAt.toMillis() >= sentAt.toMillis()) return;
    transaction.set(access.member.ref, {
      lastReadAt: now,
      lastReadMessageId: parsed.messageId,
      lastReadMessageSentAt: sentAt,
      unreadCount: 0,
      updatedAt: now,
    }, {merge: true});
    transaction.set(
      access.database.doc(`users/${uid}/conversation_inbox/${parsed.conversationId}`),
      {
        lastReadAt: now,
        lastReadMessageId: parsed.messageId,
        unreadCount: 0,
        updatedAt: now,
      },
      {merge: true},
    );
  });
  return {read: true};
});

export const reportMessage = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseReportRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  await consumeRateLimit(uid, {
    key: "report_message",
    maxAttempts: 30,
    windowSeconds: 24 * 60 * 60,
  });
  const message = await access.conversation.ref.collection("messages")
    .doc(parsed.messageId).get();
  if (!message.exists) throw new HttpsError("not-found", "This message is unavailable.");
  const reportId = `${uid}--${parsed.conversationId}--${parsed.messageId}`;
  const now = Timestamp.now();
  await access.database.collection(collections.messageReports).doc(reportId).set({
    reporterId: uid,
    conversationId: parsed.conversationId,
    messageId: parsed.messageId,
    messageSenderId: String(message.get("senderId") ?? ""),
    reason: parsed.reason,
    details: parsed.details,
    status: "pending",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  }, {merge: false});
  await writeAuditEvent({
    actorId: uid,
    action: "messaging.message_reported",
    targetType: "message",
    targetId: parsed.messageId,
    metadata: {conversationId: parsed.conversationId, reason: parsed.reason},
  });
  return {reported: true};
});
