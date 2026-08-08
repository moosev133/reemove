import {getFirestore, Timestamp, type QueryDocumentSnapshot} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

import {primaryRegion} from "../core/functionOptions";
import {collections} from "../core/schema";
import {
  iterateActiveGroupMembers,
  sportsGroupConversationSource,
} from "../groups/groupChannels";
import {createAndDeliverNotification} from "../notifications/notificationService";

function messagePreview(message: QueryDocumentSnapshot): string {
  const text = String(message.get("text") ?? "").trim();
  if (text.length > 0) return text;
  return message.get("kind") === "image" ? "Sent a photo" :
    message.get("kind") === "video" ? "Sent a video" :
    message.get("kind") === "audio" ? "Sent audio" : "Sent a message";
}

function sportsSafeBody(options: {
  channelType: string;
  groupName: string;
  privacy: string;
  message: QueryDocumentSnapshot;
}): string {
  if (options.channelType === "announcements") {
    return "New announcement";
  }
  // Avoid leaking message text for private/hidden groups beyond a generic label.
  if (options.privacy === "private" || options.privacy === "hidden") {
    return `New message in ${options.groupName}`;
  }
  return messagePreview(options.message);
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
    const conversation = await conversationRef.get();
    if (!conversation.exists || conversation.get("moderationState") !== "active") return;

    const now = Timestamp.now();
    const sender = message.get("senderSnapshot") as Record<string, unknown> | undefined;
    const senderName = String(sender?.displayName ?? "Someone");
    const isGroup = conversation.get("type") === "group";
    const isSports = conversation.get("source") === sportsGroupConversationSource;
    const groupTitle = String(conversation.get("title") ?? "Group");
    let delivered = 0;

    if (isSports) {
      const groupId = String(conversation.get("groupId") ?? "");
      const channelType = String(conversation.get("channelType") ?? "member_chat");
      if (!groupId) return;
      const group = await database.collection(collections.groups).doc(groupId).get();
      if (!group.exists || group.get("status") !== "active") return;
      const groupName = String(group.get("name") ?? groupTitle);
      const privacy = String(group.get("privacy") ?? "public");
      const title = channelType === "announcements" ?
        groupName :
        `${senderName} in ${groupName}`;
      const body = sportsSafeBody({
        channelType,
        groupName,
        privacy,
        message,
      });
      const route =
        `/groups/${groupId}/channels/${channelType}?messageId=${messageId}`;

      for await (const page of iterateActiveGroupMembers(database, groupId)) {
        for (const member of page) {
          if (member.id === senderId) continue;
          const conversationMember = await conversationRef
            .collection("members")
            .doc(member.id)
            .get();
          const mutedUntil = conversationMember.get("mutedUntil");
          const notificationsDisabled =
            conversationMember.get("notificationsEnabled") === false;
          const muted = mutedUntil instanceof Timestamp &&
            mutedUntil.toMillis() > now.toMillis();
          const result = await createAndDeliverNotification({
            eventId: `${event.id}:${member.id}`,
            recipientId: member.id,
            actorId: senderId,
            category: "messages",
            kind: channelType === "announcements" ?
              "group_announcement" :
              "conversation_message",
            title,
            body,
            route,
            groupKey: `sports_group:${groupId}:${channelType}`,
            entityType: "group",
            entityId: groupId,
            data: {
              conversationId,
              messageId,
              groupId,
              channelType,
            },
            priority: "high",
            suppressPush: notificationsDisabled || muted,
            suppressionReason: notificationsDisabled ?
              "conversation_notifications_disabled" :
              muted ? "conversation_muted" : undefined,
          });
          if (result.created) delivered += 1;
        }
      }
      logger.info("Sports group conversation notifications processed.", {
        conversationId,
        messageId,
        groupId,
        channelType,
        recipients: delivered,
      });
      return;
    }

    const members = await conversationRef.collection("members").limit(100).get();
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
