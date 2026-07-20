import {
  FieldPath,
  getFirestore,
  Timestamp,
  type DocumentData,
  type DocumentSnapshot,
  type Firestore,
  type Query,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {callableOptions} from "../core/functionOptions";
import {collections} from "../core/schema";
import {
  resolveAccountPrivacy,
  viewerCanViewFullAccount,
} from "../profile/profilePrivacyModel";
import {assertCanAccessPost} from "../feed/contentAccess";
import {safeDocumentId} from "../feed/contentPolicy";
import {callableDocument, recordValue} from "./profilePolicy";

type ProfileContentFilter = "posts" | "reels" | "saved" | "reposted";

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

function parseFilter(value: unknown): ProfileContentFilter {
  if (value === "posts" || value === "reels" ||
      value === "saved" || value === "reposted") {
    return value;
  }
  throw new HttpsError("invalid-argument", "Content filter is invalid.");
}

function parseCursor(data: Record<string, unknown>): {
  id?: string;
  at?: Timestamp;
} {
  if (data.cursorId === undefined || data.cursorAt === undefined) return {};
  const id = safeDocumentId(data.cursorId, "cursorId");
  if (typeof data.cursorAt !== "string") {
    throw new HttpsError("invalid-argument", "Cursor is invalid.");
  }
  const date = new Date(data.cursorAt);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", "Cursor is invalid.");
  }
  return {id, at: Timestamp.fromDate(date)};
}

async function assertCanViewProfile(
  database: Firestore,
  viewerId: string,
  profileId: string,
): Promise<DocumentSnapshot<DocumentData>> {
  const profileRef = database.collection(collections.users).doc(profileId);
  const [profile, viewerBlock, profileBlock, follower] = await Promise.all([
    profileRef.get(),
    database.doc(`users/${viewerId}/blocks/${profileId}`).get(),
    database.doc(`users/${profileId}/blocks/${viewerId}`).get(),
    database.doc(`users/${profileId}/followers/${viewerId}`).get(),
  ]);
  if (!profile.exists || profile.get("moderationState") !== "active" ||
      viewerBlock.exists || profileBlock.exists) {
    throw new HttpsError("not-found", "This profile is unavailable.");
  }
  const canView = viewerCanViewFullAccount(
    resolveAccountPrivacy(profile),
    viewerId === profileId,
    follower.exists,
  );
  if (!canView) {
    throw new HttpsError("permission-denied", "This profile is private.");
  }
  return profile;
}

async function reactionFor(
  database: Firestore,
  viewerId: string,
  postId: string,
): Promise<Record<string, unknown> | undefined> {
  const reaction = await database.collection(collections.contentReactions)
    .doc(`${viewerId}--${postId}`).get();
  if (!reaction.exists) return undefined;
  return callableDocument(reaction);
}

async function safePostItem(
  database: Firestore,
  viewerId: string,
  postId: string,
): Promise<Record<string, unknown> | undefined> {
  const post = await database.collection(collections.posts).doc(postId).get();
  try {
    await assertCanAccessPost(database, viewerId, post);
  } catch (error) {
    if (error instanceof HttpsError &&
        (error.code === "not-found" || error.code === "permission-denied")) {
      return undefined;
    }
    throw error;
  }
  return {
    post: callableDocument(post),
    reaction: await reactionFor(database, viewerId, postId),
  };
}

async function directContent(
  database: Firestore,
  viewerId: string,
  profileId: string,
  filter: "posts" | "reels",
  limit: number,
  cursor: {id?: string; at?: Timestamp},
): Promise<{
  items: Record<string, unknown>[];
  source: QueryDocumentSnapshot<DocumentData>[];
}> {
  let query: Query<DocumentData> = database.collection(collections.posts)
    .where("authorId", "==", profileId)
    .where("kind", "==", filter === "reels" ? "reel" : "post")
    .where("status", "==", "published")
    .where("moderationState", "==", "active")
    .orderBy("publishedAt", "desc")
    .orderBy(FieldPath.documentId())
    .limit(limit + 1);
  if (cursor.id && cursor.at) {
    query = query.startAfter(cursor.at, cursor.id);
  }
  const snapshot = await query.get();
  const source = snapshot.docs;
  const loaded = await Promise.all(
    source.slice(0, limit).map((post) =>
      safePostItem(database, viewerId, post.id),
    ),
  );
  return {
    items: loaded.filter(
      (item): item is Record<string, unknown> => item !== undefined,
    ),
    source,
  };
}

async function savedContent(
  database: Firestore,
  viewerId: string,
  filter: "saved" | "reposted",
  limit: number,
  cursor: {id?: string; at?: Timestamp},
): Promise<{
  items: Record<string, unknown>[];
  source: QueryDocumentSnapshot<DocumentData>[];
}> {
  let query: Query<DocumentData> = filter === "saved" ?
    database.collection(collections.contentReactions)
      .where("uid", "==", viewerId)
      .where("saved", "==", true)
      .orderBy("updatedAt", "desc")
      .orderBy(FieldPath.documentId())
      .limit(limit + 1) :
    database.collection(collections.reposts)
      .where("reposterId", "==", viewerId)
      .orderBy("createdAt", "desc")
      .orderBy(FieldPath.documentId())
      .limit(limit + 1);
  if (cursor.id && cursor.at) {
    query = query.startAfter(cursor.at, cursor.id);
  }
  const snapshot = await query.get();
  const source = snapshot.docs;
  const loaded = await Promise.all(source.slice(0, limit).map(async (entry) => {
    const postId = String(entry.get("postId") ?? "");
    if (!postId) return undefined;
    return safePostItem(database, viewerId, postId);
  }));
  return {
    items: loaded.filter(
      (item): item is Record<string, unknown> => item !== undefined,
    ),
    source,
  };
}

export const loadProfileContent = onCall(
  callableOptions,
  async (request) => {
    const viewerId = requireUid(request.auth?.uid);
    const data = recordValue(request.data);
    const profileId = safeDocumentId(data.profileId, "profileId");
    const filter = parseFilter(data.filter);
    const requestedLimit = typeof data.limit === "number" ?
      Math.trunc(data.limit) : 18;
    const limit = Math.min(30, Math.max(1, requestedLimit));
    const cursor = parseCursor(data);
    const database = getFirestore();
    await assertCanViewProfile(database, viewerId, profileId);
    if ((filter === "saved" || filter === "reposted") &&
        viewerId !== profileId) {
      throw new HttpsError(
        "permission-denied",
        "Saved and reposted content is private.",
      );
    }

    const page = filter === "posts" || filter === "reels" ?
      await directContent(
        database,
        viewerId,
        profileId,
        filter,
        limit,
        cursor,
      ) :
      await savedContent(database, viewerId, filter, limit, cursor);
    const last = page.source.slice(0, limit).at(-1);
    const sortField = filter === "saved" ? "updatedAt" :
      filter === "reposted" ? "createdAt" : "publishedAt";
    return {
      items: page.items,
      hasMore: page.source.length > limit,
      ...(last ? {
        nextCursor: {
          documentId: last.id,
          sortAt: (last.get(sortField) as Timestamp).toDate().toISOString(),
        },
      } : {}),
    };
  },
);
