import {
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {collections} from "../core/schema";
import {
  resolveAccountPrivacy,
  viewerCanViewFullAccount,
} from "./profilePrivacyModel";

export type {ProfileAccessLevel} from "./profilePrivacyModel";

export function safeProfilePreview(
  profile: DocumentSnapshot,
): Record<string, unknown> {
  const accountPrivacy = resolveAccountPrivacy(profile);
  return {
    uid: profile.id,
    username: String(profile.get("username") ?? ""),
    displayName: String(profile.get("displayName") ?? "Athlete"),
    ...(profile.get("avatarUrl") ? {
      avatarUrl: String(profile.get("avatarUrl")),
    } : {}),
    visibility: String(profile.get("visibility") ?? "public"),
    accountPrivacy,
    isVerified: profile.get("isVerified") === true,
    verificationType: String(profile.get("verificationType") ?? "none"),
  };
}

export async function privacySettingsFor(
  database: Firestore,
  profileId: string,
): Promise<Record<string, unknown>> {
  const snapshot = await database.doc(
    `users/${profileId}/private/profile_settings`,
  ).get();
  return snapshot.data() ?? {};
}

export async function assertUsernameDiscoverable(
  database: Firestore,
  profileId: string,
): Promise<void> {
  const privacy = await privacySettingsFor(database, profileId);
  if (privacy.discoverableByUsername === false) {
    throw new HttpsError("not-found", "This profile is unavailable.");
  }
}

export function viewerCanViewFullProfile(
  viewerId: string,
  profile: DocumentSnapshot,
  isFollowing: boolean,
): boolean {
  if (!profile.exists || profile.get("moderationState") !== "active") {
    return false;
  }
  if (viewerId === profile.id) return true;
  return viewerCanViewFullAccount(
    resolveAccountPrivacy(profile),
    false,
    isFollowing,
  );
}

export async function purgeFeedEntriesBetween(
  database: Firestore,
  recipientId: string,
  authorId: string,
): Promise<number> {
  const snapshot = await database.collection(collections.feedEntries)
    .where("recipientId", "==", recipientId)
    .where("authorId", "==", authorId)
    .limit(500)
    .get();
  if (snapshot.empty) return 0;
  const batch = database.batch();
  for (const document of snapshot.docs) {
    batch.delete(document.ref);
  }
  await batch.commit();
  return snapshot.size;
}

export async function purgeFeedEntriesBothDirections(
  database: Firestore,
  firstUserId: string,
  secondUserId: string,
): Promise<void> {
  await Promise.all([
    purgeFeedEntriesBetween(database, firstUserId, secondUserId),
    purgeFeedEntriesBetween(database, secondUserId, firstUserId),
  ]);
}
