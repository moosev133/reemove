import {
  getFirestore,
  type DocumentData,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {collections} from "../core/schema";
import {isMessageAudienceAllowed} from "./messageAudiencePolicy";

export {isMessageAudienceAllowed} from "./messageAudiencePolicy";

export type MemberAccess = {
  database: Firestore;
  conversation: DocumentSnapshot<DocumentData>;
  member: DocumentSnapshot<DocumentData>;
};

export function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

export async function assertConversationMember(
  conversationId: string,
  uid: string,
): Promise<MemberAccess> {
  const database = getFirestore();
  const conversationRef = database.collection(collections.conversations).doc(conversationId);
  const memberRef = conversationRef.collection("members").doc(uid);
  const [conversation, member] = await Promise.all([
    conversationRef.get(),
    memberRef.get(),
  ]);
  if (!conversation.exists || conversation.get("moderationState") !== "active") {
    throw new HttpsError("not-found", "This conversation is unavailable.");
  }
  if (!member.exists || member.get("removedAt")) {
    throw new HttpsError("permission-denied", "You are not a member of this conversation.");
  }
  return {database, conversation, member};
}

export function assertGroupAdministrator(access: MemberAccess): void {
  if (access.conversation.get("type") !== "group") {
    throw new HttpsError("failed-precondition", "This action is only available in groups.");
  }
  const role = access.member.get("role");
  if (role !== "owner" && role !== "admin") {
    throw new HttpsError("permission-denied", "Only group administrators can do this.");
  }
}

export async function activeProfileSnapshot(
  database: Firestore,
  uid: string,
): Promise<Record<string, unknown>> {
  const profile = await database.collection(collections.users).doc(uid).get();
  if (!profile.exists || profile.get("moderationState") !== "active" ||
      profile.get("onboardingCompleted") !== true) {
    throw new HttpsError("failed-precondition", "This profile is unavailable.");
  }
  return {
    id: uid,
    username: String(profile.get("username") ?? ""),
    displayName: String(profile.get("displayName") ?? "Athlete"),
    ...(profile.get("avatarUrl") ? {avatarUrl: String(profile.get("avatarUrl"))} : {}),
    isVerified: profile.get("isVerified") === true,
  };
}

export async function assertUsersCanMessage(
  database: Firestore,
  senderId: string,
  targetId: string,
): Promise<void> {
  if (senderId === targetId) {
    throw new HttpsError("invalid-argument", "You cannot message yourself.");
  }
  const [senderBlock, targetBlock, targetSettings, follows] = await Promise.all([
    database.doc(`users/${senderId}/blocks/${targetId}`).get(),
    database.doc(`users/${targetId}/blocks/${senderId}`).get(),
    database.doc(`users/${targetId}/private/profile_settings`).get(),
    database.doc(`users/${targetId}/followers/${senderId}`).get(),
  ]);
  if (senderBlock.exists || targetBlock.exists) {
    throw new HttpsError("failed-precondition", "This conversation is unavailable.");
  }
  const audience = String(targetSettings.get("messageAudience") ?? "everyone");
  if (!isMessageAudienceAllowed(audience, follows.exists)) {
    throw new HttpsError(
      "permission-denied",
      "This person is not accepting messages from your account.",
    );
  }
}
