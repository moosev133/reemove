import {
  getFirestore,
  Timestamp,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";

import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {requireUid} from "../messaging/conversationAccess";
import {assertCanAccessStory} from "./contentAccess";
import {recordValue} from "../profile/profilePolicy";

function serializeStory(
  snapshot: DocumentSnapshot,
  viewedStoryIds: Set<string>,
): Record<string, unknown> {
  const data = snapshot.data() ?? {};
  const authorSnapshot = data.authorSnapshot as Record<string, unknown> | undefined;
  const media = data.media as Record<string, unknown> | undefined;
  return {
    id: snapshot.id,
    authorId: String(data.authorId ?? authorSnapshot?.id ?? ""),
    authorSnapshot,
    media,
    visibility: String(data.visibility ?? "public"),
    moderationState: String(data.moderationState ?? "active"),
    caption: String(data.caption ?? ""),
    sportId: data.sportId ?? null,
    createdAt: (data.createdAt as Timestamp | undefined)?.toDate().toISOString(),
    expiresAt: (data.expiresAt as Timestamp | undefined)?.toDate().toISOString(),
    viewCount: Number(data.viewCount ?? 0),
    isViewed: viewedStoryIds.has(snapshot.id),
    schemaVersion: String(data.schemaVersion ?? currentSchemaVersion),
  };
}

export const loadStoryRail = onCall(callableOptions, async (request) => {
  const viewerId = requireUid(request.auth?.uid);
  const data = recordValue(request.data ?? {});
  const limitValue = typeof data.limit === "number" ?
    Math.trunc(data.limit) : 40;
  const limit = Math.min(50, Math.max(1, limitValue));
  await consumeRateLimit(viewerId, {
    key: "load_story_rail",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  const [blocks, blockedBy, following] = await Promise.all([
    database.collection(collections.users).doc(viewerId).collection("blocks").get(),
    database.collection(collections.users).doc(viewerId).collection("blocked_by").get(),
    database.collection(collections.users).doc(viewerId).collection("following").get(),
  ]);
  const hiddenUserIds = new Set<string>([
    ...blocks.docs.map((item) => item.id),
    ...blockedBy.docs.map((item) => item.id),
  ]);
  const followedAuthorIds = new Set<string>(
    following.docs.map((item) => item.id),
  );

  const now = Timestamp.now();
  const publicStories = await database.collection(collections.stories)
    .where("visibility", "==", "public")
    .where("moderationState", "==", "active")
    .where("expiresAt", ">", now)
    .orderBy("expiresAt")
    .orderBy("createdAt", "desc")
    .limit(limit * 2)
    .get();

  const followerStories = followedAuthorIds.size === 0 ?
    [] :
    await Promise.all([...followedAuthorIds].slice(0, 50).map(async (authorId) => {
      const snapshot = await database.collection(collections.stories)
        .where("authorId", "==", authorId)
        .where("visibility", "==", "followers")
        .where("moderationState", "==", "active")
        .where("expiresAt", ">", now)
        .orderBy("expiresAt")
        .orderBy("createdAt", "desc")
        .limit(10)
        .get();
      return snapshot.docs;
    }));

  const storyDocs = new Map<string, DocumentSnapshot>();
  for (const document of publicStories.docs) {
    const authorId = String(document.get("authorId") ?? "");
    if (!authorId || hiddenUserIds.has(authorId)) continue;
    storyDocs.set(document.id, document);
  }
  for (const documents of followerStories) {
    for (const document of documents) {
      const authorId = String(document.get("authorId") ?? "");
      if (!authorId || hiddenUserIds.has(authorId)) continue;
      if (!followedAuthorIds.has(authorId)) continue;
      storyDocs.set(document.id, document);
    }
  }

  const accessibleStories: DocumentSnapshot[] = [];
  for (const document of storyDocs.values()) {
    try {
      await assertCanAccessStory(database, viewerId, document);
      accessibleStories.push(document);
    } catch {
      // Skip stories the viewer cannot access.
    }
  }

  const trimmed = accessibleStories
    .sort((left, right) => {
      const leftCreated = (left.get("createdAt") as Timestamp | undefined)?.toMillis() ?? 0;
      const rightCreated = (right.get("createdAt") as Timestamp | undefined)?.toMillis() ?? 0;
      return rightCreated - leftCreated;
    })
    .slice(0, limit);

  const viewedStoryIds = new Set<string>();
  await Promise.all(trimmed.map(async (story) => {
    const view = await database.collection("story_views")
      .doc(`${viewerId}--${story.id}`)
      .get();
    if (view.exists) viewedStoryIds.add(story.id);
  }));

  const groups = new Map<string, Record<string, unknown>[]>();
  for (const story of trimmed) {
    const authorId = String(story.get("authorId") ?? "");
    const bucket = groups.get(authorId) ?? [];
    bucket.push(serializeStory(story, viewedStoryIds));
    groups.set(authorId, bucket);
  }

  return {
    groups: [...groups.entries()].map(([authorId, stories]) => ({
      authorId,
      author: stories[0]?.authorSnapshot ?? null,
      stories,
      hasUnseen: stories.some((item) => item.isViewed !== true),
    })),
    generatedAt: new Date().toISOString(),
  };
});
