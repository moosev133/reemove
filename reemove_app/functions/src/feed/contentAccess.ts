import type {
  DocumentData,
  DocumentSnapshot,
  Firestore,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  normalizeContentVisibility,
  resolveAccountPrivacy,
  viewerCanViewAuthorContent,
} from "../profile/profilePrivacyModel";
import {collections} from "../core/schema";

async function hasBlock(
  database: Firestore,
  left: string,
  right: string,
): Promise<boolean> {
  const [leftBlocksRight, rightBlocksLeft] = await Promise.all([
    database.doc(`users/${left}/blocks/${right}`).get(),
    database.doc(`users/${right}/blocks/${left}`).get(),
  ]);
  return leftBlocksRight.exists || rightBlocksLeft.exists;
}

export async function assertCanAccessPost(
  database: Firestore,
  viewerId: string,
  snapshot: DocumentSnapshot<DocumentData>,
): Promise<void> {
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "This post is unavailable.");
  }
  const authorId = String(snapshot.get("authorId") ?? "");
  if (!authorId) throw new HttpsError("not-found", "This post is unavailable.");
  if (await hasBlock(database, viewerId, authorId)) {
    throw new HttpsError("permission-denied", "This post is unavailable.");
  }
  if (viewerId === authorId) return;
  if (snapshot.get("status") !== "published" ||
      snapshot.get("moderationState") !== "active") {
    throw new HttpsError("not-found", "This post is unavailable.");
  }
  const visibility = normalizeContentVisibility(snapshot.get("visibility"));
  const follows = await database.doc(
    `users/${authorId}/followers/${viewerId}`,
  ).get();
  const author = await database.collection(collections.users).doc(authorId).get();
  const accountPrivacy = resolveAccountPrivacy(author);
  if (viewerCanViewAuthorContent(
    accountPrivacy,
    visibility,
    false,
    follows.exists,
  )) {
    return;
  }
  throw new HttpsError("permission-denied", "This post is private.");
}

export async function assertCanAccessStory(
  database: Firestore,
  viewerId: string,
  snapshot: DocumentSnapshot<DocumentData>,
): Promise<void> {
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "This story is unavailable.");
  }
  const authorId = String(snapshot.get("authorId") ?? "");
  if (!authorId || await hasBlock(database, viewerId, authorId)) {
    throw new HttpsError("permission-denied", "This story is unavailable.");
  }
  if (viewerId === authorId) return;
  if (snapshot.get("moderationState") !== "active") {
    throw new HttpsError("not-found", "This story is unavailable.");
  }
  const visibility = normalizeContentVisibility(snapshot.get("visibility"));
  const follows = await database.doc(
    `users/${authorId}/followers/${viewerId}`,
  ).get();
  const author = await database.collection(collections.users).doc(authorId).get();
  const accountPrivacy = resolveAccountPrivacy(author);
  if (viewerCanViewAuthorContent(
    accountPrivacy,
    visibility,
    false,
    follows.exists,
  )) {
    return;
  }
  throw new HttpsError("permission-denied", "This story is private.");
}
