import {getFirestore, Timestamp, type QueryDocumentSnapshot} from "firebase-admin/firestore";
import {getMessaging, type MulticastMessage} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

import {primaryRegion} from "../core/functionOptions";
import {collections, currentSchemaVersion} from "../core/schema";

const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

type RecipientToken = {
  uid: string;
  token: string;
  documentId: string;
};

export const notifyConversationMessage = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    region: primaryRegion,
    retry: false,
  },
  async (event) => {
    const message = event.data;
    if (!message || message.get("isDeleted") === true ||
        message.get("moderationState") !== "active") return;
    const conversationId = event.params.conversationId;
    const messageId = event.params.messageId;
    const senderId = String(message.get("senderId") ?? "");
    const database = getFirestore();
    const conversationRef = database.collection(collections.conversations).doc(conversationId);
    const [conversation, memberSnapshot] = await Promise.all([
      conversationRef.get(),
      conversationRef.collection("members").limit(100).get(),
    ]);
    if (!conversation.exists || conversation.get("moderationState") !== "active") return;
    const now = Timestamp.now();
    const recipients: QueryDocumentSnapshot[] = memberSnapshot.docs.filter((member) => {
      if (member.id === senderId || member.get("removedAt")) return false;
      if (member.get("notificationsEnabled") === false) return false;
      const mutedUntil = member.get("mutedUntil");
      return !(mutedUntil instanceof Timestamp && mutedUntil.toMillis() > now.toMillis());
    });
    if (recipients.length === 0) return;

    const eligible: QueryDocumentSnapshot[] = [];
    for (const member of recipients) {
      const preferences = await database.doc(`users/${member.id}/private/preferences`).get();
      const notifications = preferences.get("notifications") as Record<string, unknown> | undefined;
      if (notifications?.masterEnabled === false || notifications?.messages === false) continue;
      eligible.push(member);
    }
    const tokens: RecipientToken[] = [];
    for (const member of eligible) {
      const snapshot = await database.collection(`users/${member.id}/device_tokens`)
        .where("messagingEnabled", "==", true).limit(10).get();
      for (const document of snapshot.docs) {
        const token = document.get("token");
        if (typeof token === "string" && token.length > 0) {
          tokens.push({uid: member.id, token, documentId: document.id});
        }
      }
    }
    if (tokens.length === 0) return;

    const sender = message.get("senderSnapshot") as Record<string, unknown> | undefined;
    const senderName = String(sender?.displayName ?? "Someone");
    const isGroup = conversation.get("type") === "group";
    const groupTitle = String(conversation.get("title") ?? "Group");
    const preview = String(message.get("text") ?? "").trim() ||
      (message.get("kind") === "image" ? "Sent a photo" :
       message.get("kind") === "video" ? "Sent a video" :
       message.get("kind") === "audio" ? "Sent audio" : "Sent a message");

    for (let start = 0; start < tokens.length; start += 500) {
      const slice = tokens.slice(start, start + 500);
      const payload: MulticastMessage = {
        tokens: slice.map((item) => item.token),
        notification: {
          title: isGroup ? `${senderName} in ${groupTitle}` : senderName,
          body: preview.length > 160 ? `${preview.slice(0, 157)}...` : preview,
        },
        data: {
          type: "conversation_message",
          conversationId,
          messageId,
          route: `/messages/${conversationId}`,
        },
        android: {
          priority: "high",
          notification: {tag: `conversation_${conversationId}`},
        },
        apns: {
          payload: {aps: {sound: "default", threadId: conversationId}},
        },
      };
      const response = await getMessaging().sendEachForMulticast(payload);
      const cleanup = database.batch();
      response.responses.forEach((item, index) => {
        const token = slice[index];
        if (!item.success && item.error && invalidTokenCodes.has(item.error.code)) {
          cleanup.delete(database.doc(`users/${token.uid}/device_tokens/${token.documentId}`));
        }
      });
      await cleanup.commit();
    }

    const deliveryBatch = database.batch();
    for (const member of eligible) {
      deliveryBatch.set(
        database.collection(collections.notificationDeliveries)
          .doc(`${messageId}--${member.id}`),
        {
          type: "conversation_message",
          recipientId: member.id,
          senderId,
          conversationId,
          messageId,
          tokenCount: tokens.filter((item) => item.uid === member.id).length,
          status: "submitted",
          createdAt: now,
          updatedAt: now,
          schemaVersion: currentSchemaVersion,
        },
        {merge: true},
      );
    }
    await deliveryBatch.commit();
    logger.info("Conversation push submitted.", {
      conversationId,
      messageId,
      recipients: eligible.length,
      tokens: tokens.length,
    });
  },
);
