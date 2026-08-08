import {
  getFirestore,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {collections} from "../core/schema";
import {
  activeMemberRole,
  assertActiveGroup,
  groupRef,
  memberRef,
} from "./groupsAccess";
import {sportsGroupConversationSource} from "./groupChannels";
import {
  groupChannelContracts,
  groupMediaModes,
  isManagerRole,
  type GroupChannelType,
  type GroupMediaMode,
  type GroupMemberRole,
} from "./groupsPolicy";

export {sportsGroupConversationSource};
export function parseGroupMediaMode(value: unknown): GroupMediaMode {
  if (value === undefined || value === null || value === "") return "normal";
  if (typeof value !== "string" ||
      !(groupMediaModes as readonly string[]).includes(value)) {
    throw new HttpsError("invalid-argument", "mediaMode is invalid.");
  }
  return value as GroupMediaMode;
}

export function groupChannelStoragePrefix(
  groupId: string,
  channelType: GroupChannelType | string,
  messageId: string,
  attachmentId: string,
): string {
  return `groups/${groupId}/channels/${channelType}/${messageId}/${attachmentId}`;
}

export function isGroupChannelStoragePath(
  storagePath: string,
  groupId: string,
  channelType: string,
  messageId: string,
  attachmentId: string,
): boolean {
  const prefix = `${groupChannelStoragePrefix(groupId, channelType, messageId, attachmentId)}/`;
  return storagePath.startsWith(prefix);
}

export type SportsChannelAccess = {
  database: Firestore;
  group: DocumentSnapshot;
  membershipRole: GroupMemberRole;
  channelType: GroupChannelType;
  conversationId: string;
  groupId: string;
};

export async function assertSportsChannelPublishAccess(options: {
  groupId: string;
  channelType: GroupChannelType | string;
  uid: string;
  mediaMode?: GroupMediaMode;
  database?: Firestore;
}): Promise<SportsChannelAccess> {
  const database = options.database ?? getFirestore();
  const channelType = options.channelType === "announcements" ?
    "announcements" :
    "member_chat";
  const group = await groupRef(database, options.groupId).get();
  assertActiveGroup(group);
  if (group.get("status") !== "active") {
    throw new HttpsError("failed-precondition", "This group is not active.");
  }
  const membershipRole = activeMemberRole(
    await memberRef(database, options.groupId, options.uid).get(),
  );
  if (!membershipRole) {
    throw new HttpsError("permission-denied", "Group membership is required.");
  }

  const contract = groupChannelContracts().find((item) => item.type === channelType);
  if (!contract) {
    throw new HttpsError("failed-precondition", "Channel is unavailable.");
  }
  if (!contract.publishRoles.includes(membershipRole)) {
    throw new HttpsError(
      "permission-denied",
      "You cannot publish in this channel.",
    );
  }
  const mediaMode = options.mediaMode ?? "normal";
  if (!contract.supportedMediaModes.includes(mediaMode)) {
    throw new HttpsError(
      "failed-precondition",
      "This media mode is not supported in this channel.",
    );
  }

  const conversationId = channelType === "member_chat" ?
    String(group.get("memberChatConversationId") ?? "") :
    String(group.get("announcementsConversationId") ?? "");
  if (!conversationId) {
    throw new HttpsError("failed-precondition", "Channel conversation is missing.");
  }

  return {
    database,
    group,
    membershipRole,
    channelType,
    conversationId,
    groupId: options.groupId,
  };
}

export async function loadSportsConversationContext(
  conversation: DocumentSnapshot,
  uid: string,
): Promise<{
  groupId: string;
  channelType: GroupChannelType;
  membershipRole: GroupMemberRole;
  group: DocumentSnapshot;
} | null> {
  if (conversation.get("source") !== sportsGroupConversationSource) {
    return null;
  }
  const groupId = String(conversation.get("groupId") ?? "");
  const channelTypeRaw = String(conversation.get("channelType") ?? "");
  if (!groupId ||
      (channelTypeRaw !== "member_chat" && channelTypeRaw !== "announcements")) {
    throw new HttpsError("failed-precondition", "Sports channel is misconfigured.");
  }
  const channelType = channelTypeRaw as GroupChannelType;
  const database = conversation.ref.firestore;
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  if (group.get("status") !== "active") {
    throw new HttpsError("failed-precondition", "This group is not active.");
  }
  const membershipRole = activeMemberRole(
    await memberRef(database, groupId, uid).get(),
  );
  if (!membershipRole) {
    throw new HttpsError(
      "permission-denied",
      "Active sports group membership is required.",
    );
  }
  return {groupId, channelType, membershipRole, group};
}

export function assertCanPublishInSportsChannel(
  channelType: GroupChannelType,
  role: GroupMemberRole,
  mediaMode: GroupMediaMode,
): void {
  const contract = groupChannelContracts().find((item) => item.type === channelType);
  if (!contract || !contract.publishRoles.includes(role)) {
    throw new HttpsError(
      "permission-denied",
      "You cannot publish in this channel.",
    );
  }
  if (!contract.supportedMediaModes.includes(mediaMode)) {
    throw new HttpsError(
      "failed-precondition",
      "This media mode is not supported in this channel.",
    );
  }
}

export function sportsManagerCanModerate(role: GroupMemberRole | null): boolean {
  return role !== null && isManagerRole(role);
}

export async function conversationForSportsChannel(
  database: Firestore,
  conversationId: string,
): Promise<DocumentSnapshot> {
  return database.collection(collections.conversations).doc(conversationId).get();
}
