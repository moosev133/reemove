import {getFirestore, Timestamp, type QueryDocumentSnapshot} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

import {primaryRegion} from "../core/functionOptions";
import {collections} from "../core/schema";
import {createAndDeliverNotification} from "../notifications/notificationService";

function messagePreview(message: QueryDocumentSnapshot): string {
  const text = String(message.get("text") ?? "").trim();
  if (text.length > 0) return text;
  return message.get("kind") === "image" ? "Sent a photo" :
    message.get("kind") === "video" ? "Sent a video" :
    message.get("kind") === "audio" ? "Sent audio" : "Sent a message";
}

export const notifyConversationMessage = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const message = event.data;
    if (!message || message.get("isDeleted") === true ||
        message.get("moderationState") !== "active") return;
    const conversationId = event.params.conversationId;
    const messageId = event.params.messageId;
    const senderId = String(message.get("senderId") ?? "");
    const database = getFirestore();
    const conversationRef = database.collection(collections.conversations)
      .doc(conversationId);
    const [conversation, members] = await Promise.all([
      conversationRef.get(),
      conversationRef.collection("members").limit(100).get(),
    ]);
    if (!conversation.exists || conversation.get("moderationState") !== "active") return;
    const now = Timestamp.now();
    const sender = message.get("senderSnapshot") as Record<string, unknown> | undefined;
    const senderName = String(sender?.displayName ?? "Someone");
    const isGroup = conversation.get("type") === "group";
    const groupTitle = String(conversation.get("title") ?? "Group");
    let delivered = 0;
    for (const member of members.docs) {
      if (member.id === senderId || member.get("removedAt")) continue;
      const mutedUntil = member.get("mutedUntil");
      const notificationsDisabled = member.get("notificationsEnabled") === false;
      const muted = mutedUntil instanceof Timestamp &&
        mutedUntil.toMillis() > now.toMillis();
      const result = await createAndDeliverNotification({
        eventId: `${event.id}:${member.id}`,
        recipientId: member.id,
        actorId: senderId,
        category: "messages",
        kind: "conversation_message",
        title: isGroup ? `${senderName} in ${groupTitle}` : senderName,
        body: messagePreview(message),
        route: `/messages/${conversationId}`,
        groupKey: `conversation:${conversationId}`,
        entityType: "conversation",
        entityId: conversationId,
        data: {conversationId, messageId},
        priority: "high",
        suppressPush: notificationsDisabled || muted,
        suppressionReason: notificationsDisabled ?
          "conversation_notifications_disabled" :
          muted ? "conversation_muted" : undefined,
      });
      if (result.created) delivered += 1;
    }
    logger.info("Conversation notifications processed.", {
      conversationId,
      messageId,
      recipients: delivered,
    });
  },
);
