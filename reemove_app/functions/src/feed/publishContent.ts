import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getDownloadURL, getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {
  extractHashtags,
  extractMentions,
  type MediaInput,
  parsePublishRequest,
  storyLifetimeHours,
} from "./contentPolicy";
import {initialContentRankingScore} from "./ranking";

type TrustedMedia = {
  id: string;
  storagePath: string;
  kind: "image" | "video";
  processingState: "pending" | "ready";
  downloadUrl: string;
  thumbnailUrl?: string;
  width?: number;
  height?: number;
  durationMs?: number;
  contentType: string;
  sizeBytes: number;
};

async function profileSnapshot(uid: string): Promise<Record<string, unknown>> {
  const snapshot = await getFirestore().collection(collections.users).doc(uid).get();
  if (!snapshot.exists || snapshot.get("moderationState") !== "active" ||
      snapshot.get("onboardingCompleted") !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Complete your active ReeMove profile before publishing.",
    );
  }
  return {
    id: uid,
    username: String(snapshot.get("username") ?? ""),
    displayName: String(snapshot.get("displayName") ?? "Athlete"),
    ...(snapshot.get("avatarUrl") ? {
      avatarUrl: String(snapshot.get("avatarUrl")),
    } : {}),
    isVerified: snapshot.get("isVerified") === true,
    verificationType: String(snapshot.get("verificationType") ?? "none"),
  };
}

function expectedPrefix(uid: string, draftId: string, assetId: string): string {
  return `content/${uid}/${draftId}/${assetId}/`;
}

async function validateMedia(
  uid: string,
  draftId: string,
  input: MediaInput,
): Promise<TrustedMedia> {
  if (!input.storagePath.startsWith(expectedPrefix(uid, draftId, input.id))) {
    throw new HttpsError("permission-denied", "Media ownership is invalid.");
  }

  const database = getFirestore();
  const bucket = getStorage().bucket();
  const file = bucket.file(input.storagePath);
  const [metadata] = await file.getMetadata();
  const ownerId = metadata.metadata?.ownerId;
  const storedDraftId = metadata.metadata?.draftId;
  const storedAssetId = metadata.metadata?.assetId;
  const declaredKind = metadata.metadata?.kind;
  const sizeBytes = Number(metadata.size ?? 0);
  const contentType = String(metadata.contentType ?? "");
  const inferredKind = contentType.startsWith("video/") ? "video" :
    contentType.startsWith("image/") ? "image" : null;

  if (ownerId !== uid || storedDraftId !== draftId || storedAssetId !== input.id ||
      inferredKind === null || declaredKind !== inferredKind ||
      inferredKind !== input.kind || sizeBytes <= 0) {
    throw new HttpsError("permission-denied", "Media ownership is invalid.");
  }
  const maximum = inferredKind === "video" ?
    150 * 1024 * 1024 : 15 * 1024 * 1024;
  if (sizeBytes > maximum) {
    throw new HttpsError("invalid-argument", "A media item is too large.");
  }

  const assetRef = database.collection(collections.mediaAssets).doc(input.id);
  const assetSnapshot = await assetRef.get();
  const processedReady = assetSnapshot.get("processingState") === "ready";
  const processedPath = processedReady ?
    String(assetSnapshot.get("storagePath") ?? input.storagePath) : input.storagePath;
  const processedFile = bucket.file(processedPath);
  const downloadUrl = await getDownloadURL(processedFile);
  const thumbnailUrl = processedReady && assetSnapshot.get("thumbnailUrl") ?
    String(assetSnapshot.get("thumbnailUrl")) : input.thumbnailUrl;
  const processingState = inferredKind === "image" || processedReady ?
    "ready" : "pending";

  const trusted: TrustedMedia = {
    id: input.id,
    storagePath: processedPath,
    kind: inferredKind,
    processingState,
    downloadUrl,
    contentType,
    sizeBytes,
  };
  if (thumbnailUrl) trusted.thumbnailUrl = thumbnailUrl;
  if (typeof input.width === "number") trusted.width = input.width;
  if (typeof input.height === "number") trusted.height = input.height;
  if (typeof input.durationMs === "number") trusted.durationMs = input.durationMs;
  return trusted;
}

async function validateSport(sportId: string | undefined): Promise<void> {
  if (!sportId) return;
  const snapshot = await getFirestore().collection(collections.sports)
    .doc(sportId).get();
  if (!snapshot.exists || snapshot.get("isEnabled") !== true) {
    throw new HttpsError("invalid-argument", "The selected sport is unavailable.");
  }
}

async function linkMedia(
  uid: string,
  draftId: string,
  media: TrustedMedia[],
  contentPath: string,
): Promise<void> {
  const database = getFirestore();
  const batch = database.batch();
  const now = Timestamp.now();
  for (const item of media) {
    const assetRef = database.collection(collections.mediaAssets).doc(item.id);
    batch.set(assetRef, {
      ownerId: uid,
      draftId,
      linkedContentPath: contentPath,
      ...item,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    if (item.kind === "video" && item.processingState === "pending") {
      const jobRef = database.collection(collections.mediaJobs).doc(item.id);
      batch.set(jobRef, {
        assetId: item.id,
        ownerId: uid,
        inputStoragePath: item.storagePath,
        contentPath,
        status: "queued",
        attempts: 0,
        createdAt: now,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    }
  }
  await batch.commit();
}

export const publishPost = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to publish.");
  await consumeRateLimit(uid, {
    key: "publish_post",
    maxAttempts: 30,
    windowSeconds: 60 * 60,
  });

  const input = parsePublishRequest(request.data);
  if (input.kind === "story") {
    throw new HttpsError("invalid-argument", "Use story publishing for stories.");
  }
  await validateSport(input.sportId);
  const [author, media] = await Promise.all([
    profileSnapshot(uid),
    Promise.all(input.media.map((item) => validateMedia(uid, input.draftId, item))),
  ]);
  const database = getFirestore();
  const postRef = database.collection(collections.posts).doc();
  const now = Timestamp.now();
  const needsProcessing = media.some((item) => item.processingState === "pending");
  const status = needsProcessing ? "processing" : "published";
  const data = {
    authorId: uid,
    authorSnapshot: author,
    kind: input.kind,
    caption: input.caption,
    media,
    hashtags: extractHashtags(input.caption),
    mentions: extractMentions(input.caption),
    ...(input.sportId ? {sportId: input.sportId} : {}),
    ...(input.locationLabel ? {locationLabel: input.locationLabel} : {}),
    visibility: input.visibility,
    moderationState: "active",
    status,
    allowComments: input.allowComments,
    likeCount: 0,
    commentCount: 0,
    saveCount: 0,
    repostCount: 0,
    viewCount: 0,
    rankingScore: initialContentRankingScore(
      input.kind,
      author.isVerified === true,
    ),
    publishedAt: now,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
  await database.runTransaction(async (transaction) => {
    transaction.create(postRef, data);
    transaction.update(database.collection(collections.users).doc(uid), {
      postsCount: FieldValue.increment(1),
      updatedAt: now,
    });
  });
  await linkMedia(uid, input.draftId, media, postRef.path);
  await writeAuditEvent({
    actorId: uid,
    action: "content.post_published",
    targetType: input.kind,
    targetId: postRef.id,
    metadata: {status, mediaCount: media.length, visibility: input.visibility},
  });
  return {postId: postRef.id, status};
});

export const publishStory = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to publish.");
  await consumeRateLimit(uid, {
    key: "publish_story",
    maxAttempts: 50,
    windowSeconds: 60 * 60,
  });

  const input = parsePublishRequest(request.data);
  if (input.kind !== "story") {
    throw new HttpsError("invalid-argument", "This request is not a story.");
  }
  await validateSport(input.sportId);
  const [author, mediaItems] = await Promise.all([
    profileSnapshot(uid),
    Promise.all(input.media.map((item) => validateMedia(uid, input.draftId, item))),
  ]);
  const media = mediaItems[0];
  const database = getFirestore();
  const storyRef = database.collection(collections.stories).doc();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(
    now.toMillis() + storyLifetimeHours * 60 * 60 * 1000,
  );
  await storyRef.create({
    authorId: uid,
    authorSnapshot: author,
    media,
    ...(input.caption ? {caption: input.caption} : {}),
    ...(input.sportId ? {sportId: input.sportId} : {}),
    visibility: input.visibility,
    moderationState: "active",
    viewCount: 0,
    createdAt: now,
    updatedAt: now,
    expiresAt,
    schemaVersion: currentSchemaVersion,
  });
  await linkMedia(uid, input.draftId, mediaItems, storyRef.path);
  await writeAuditEvent({
    actorId: uid,
    action: "content.story_published",
    targetType: "story",
    targetId: storyRef.id,
    metadata: {visibility: input.visibility, mediaKind: media.kind},
  });
  return {storyId: storyRef.id, expiresAt: expiresAt.toDate().toISOString()};
});
