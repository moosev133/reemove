import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentData,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {removeRelationshipForBlock} from "../profile/followGraph";
import {purgeFeedEntriesBothDirections} from "../profile/privacyEnforcement";
import {assertCanAccessPost, assertCanAccessStory} from "./contentAccess";
import {parseCommentText, safeDocumentId} from "./contentPolicy";
import {contentRankingScore} from "./ranking";

type ReactionType = "like" | "save" | "repost";

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

function mapValue(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  return value as Record<string, unknown>;
}

function reactionType(value: unknown): ReactionType {
  if (value === "like" || value === "save" || value === "repost") return value;
  throw new HttpsError("invalid-argument", "Reaction type is invalid.");
}

function reactionFields(type: ReactionType): {state: string; counter: string} {
  switch (type) {
  case "like": return {state: "liked", counter: "likeCount"};
  case "save": return {state: "saved", counter: "saveCount"};
  case "repost": return {state: "reposted", counter: "repostCount"};
  }
}

async function authorSnapshot(uid: string): Promise<Record<string, unknown>> {
  const snapshot = await getFirestore().collection(collections.users).doc(uid).get();
  if (!snapshot.exists || snapshot.get("moderationState") !== "active") {
    throw new HttpsError("failed-precondition", "Your profile is unavailable.");
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

export const togglePostReaction = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const postId = safeDocumentId(data.postId, "postId");
  const type = reactionType(data.type);
  await consumeRateLimit(uid, {
    key: `post_reaction_${type}`,
    maxAttempts: 300,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  const postRef = database.collection(collections.posts).doc(postId);
  const stateRef = database.collection(collections.contentReactions)
    .doc(`${uid}--${postId}`);
  const postSnapshot = await postRef.get();
  await assertCanAccessPost(database, uid, postSnapshot);
  const fields = reactionFields(type);

  const result = await database.runTransaction(async (transaction) => {
    const [post, state] = await Promise.all([
      transaction.get(postRef),
      transaction.get(stateRef),
    ]);
    if (!post.exists) throw new HttpsError("not-found", "This post is unavailable.");
    const wasActive = state.get(fields.state) === true;
    const active = !wasActive;
    const currentCount = Number(post.get(fields.counter) ?? 0);
    const count = Math.max(0, currentCount + (active ? 1 : -1));
    const now = Timestamp.now();
    transaction.set(stateRef, {
      uid,
      postId,
      liked: state.get("liked") === true,
      saved: state.get("saved") === true,
      reposted: state.get("reposted") === true,
      [fields.state]: active,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    if (type === "repost") {
      const repostRef = database.collection(collections.reposts)
        .doc(`${uid}--${postId}`);
      if (active) {
        transaction.set(repostRef, {
          reposterId: uid,
          postId,
          originalAuthorId: String(post.get("authorId") ?? ""),
          createdAt: now,
          updatedAt: now,
          schemaVersion: currentSchemaVersion,
        }, {merge: true});
      } else {
        transaction.delete(repostRef);
      }
    }
    const counts = {
      likes: fields.counter === "likeCount" ? count : Number(post.get("likeCount") ?? 0),
      comments: Number(post.get("commentCount") ?? 0),
      saves: fields.counter === "saveCount" ? count : Number(post.get("saveCount") ?? 0),
      reposts: fields.counter === "repostCount" ? count : Number(post.get("repostCount") ?? 0),
      views: Number(post.get("viewCount") ?? 0),
      isReel: post.get("kind") === "reel",
      isVerifiedAuthor: post.get("authorSnapshot.isVerified") === true,
    };
    transaction.update(postRef, {
      [fields.counter]: count,
      rankingScore: contentRankingScore(counts),
      updatedAt: now,
    });
    return {active, count};
  });

  return result;
});

export const createPostComment = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const postId = safeDocumentId(data.postId, "postId");
  const text = parseCommentText(data.text);
  const parentCommentId = data.parentCommentId === undefined ? null :
    safeDocumentId(data.parentCommentId, "parentCommentId");
  await consumeRateLimit(uid, {
    key: "create_comment",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  const postRef = database.collection(collections.posts).doc(postId);
  const postSnapshot = await postRef.get();
  await assertCanAccessPost(database, uid, postSnapshot);
  if (postSnapshot.get("allowComments") === false) {
    throw new HttpsError("failed-precondition", "Comments are disabled.");
  }
  const author = await authorSnapshot(uid);
  const commentRef = postRef.collection("comments").doc();
  const parentRef = parentCommentId ?
    postRef.collection("comments").doc(parentCommentId) : null;
  const now = Timestamp.now();

  await database.runTransaction(async (transaction) => {
    if (parentRef) {
      const parent = await transaction.get(parentRef);
      if (!parent.exists || parent.get("isDeleted") === true ||
          parent.get("parentCommentId") !== null) {
        throw new HttpsError("not-found", "The parent comment is unavailable.");
      }
      transaction.update(parentRef, {
        replyCount: FieldValue.increment(1),
        updatedAt: now,
      });
    }
    transaction.create(commentRef, {
      postId,
      authorId: uid,
      authorSnapshot: author,
      text,
      parentCommentId,
      likeCount: 0,
      replyCount: 0,
      isDeleted: false,
      moderationState: "active",
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(postRef, {
      commentCount: FieldValue.increment(1),
      rankingScore: FieldValue.increment(4),
      updatedAt: now,
    });
  });

  return {commentId: commentRef.id};
});

export const toggleCommentLike = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const postId = safeDocumentId(data.postId, "postId");
  const commentId = safeDocumentId(data.commentId, "commentId");
  await consumeRateLimit(uid, {
    key: "comment_like",
    maxAttempts: 300,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  const postRef = database.collection(collections.posts).doc(postId);
  const commentRef = postRef.collection("comments").doc(commentId);
  const stateRef = database.collection(collections.commentReactions)
    .doc(`${uid}--${commentId}`);
  const postSnapshot = await postRef.get();
  await assertCanAccessPost(database, uid, postSnapshot);

  return database.runTransaction(async (transaction) => {
    const [comment, state] = await Promise.all([
      transaction.get(commentRef),
      transaction.get(stateRef),
    ]);
    if (!comment.exists || comment.get("isDeleted") === true ||
        comment.get("moderationState") !== "active") {
      throw new HttpsError("not-found", "This comment is unavailable.");
    }
    const active = state.get("liked") !== true;
    const count = Math.max(
      0,
      Number(comment.get("likeCount") ?? 0) + (active ? 1 : -1),
    );
    const now = Timestamp.now();
    transaction.set(stateRef, {
      uid,
      postId,
      commentId,
      liked: active,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    transaction.update(commentRef, {likeCount: count, updatedAt: now});
    return {active, count};
  });
});

export const deletePostComment = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const postId = safeDocumentId(data.postId, "postId");
  const commentId = safeDocumentId(data.commentId, "commentId");
  const database = getFirestore();
  const postRef = database.collection(collections.posts).doc(postId);
  const commentRef = postRef.collection("comments").doc(commentId);

  await database.runTransaction(async (transaction) => {
    const comment = await transaction.get(commentRef);
    if (!comment.exists) return;
    const isAdmin = request.auth?.token.admin === true;
    if (comment.get("authorId") !== uid && !isAdmin) {
      throw new HttpsError("permission-denied", "You cannot delete this comment.");
    }
    if (comment.get("isDeleted") === true) return;
    const now = Timestamp.now();
    transaction.update(commentRef, {
      text: "",
      isDeleted: true,
      deletedAt: now,
      updatedAt: now,
    });
    transaction.update(postRef, {
      commentCount: FieldValue.increment(-1),
      updatedAt: now,
    });
  });
  return {deleted: true};
});

export const recordPostView = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const postId = safeDocumentId(data.postId, "postId");
  const database = getFirestore();
  const postRef = database.collection(collections.posts).doc(postId);
  const postSnapshot = await postRef.get();
  await assertCanAccessPost(database, uid, postSnapshot);
  const viewRef = database.collection(collections.postViews)
    .doc(`${uid}--${postId}`);
  const now = Timestamp.now();
  await database.runTransaction(async (transaction) => {
    const view = await transaction.get(viewRef);
    if (view.exists) {
      transaction.update(viewRef, {lastViewedAt: now});
      return;
    }
    transaction.create(viewRef, {
      uid,
      postId,
      firstViewedAt: now,
      lastViewedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(postRef, {
      viewCount: FieldValue.increment(1),
      rankingScore: FieldValue.increment(0.08),
      updatedAt: now,
    });
  });
  return {recorded: true};
});

export const markStoryViewed = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const storyId = safeDocumentId(data.storyId, "storyId");
  const database = getFirestore();
  const storyRef = database.collection(collections.stories).doc(storyId);
  const storySnapshot = await storyRef.get();
  await assertCanAccessStory(database, uid, storySnapshot);
  const viewRef = database.collection(collections.storyViews)
    .doc(`${uid}--${storyId}`);
  const now = Timestamp.now();
  await database.runTransaction(async (transaction) => {
    const view = await transaction.get(viewRef);
    if (view.exists) return;
    transaction.create(viewRef, {
      uid,
      storyId,
      authorId: storySnapshot.get("authorId"),
      viewedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(storyRef, {
      viewCount: FieldValue.increment(1),
      updatedAt: now,
    });
  });
  return {viewed: true};
});

export const deleteStory = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const storyId = safeDocumentId(data.storyId, "storyId");
  const database = getFirestore();
  const storyRef = database.collection(collections.stories).doc(storyId);
  const snapshot = await storyRef.get();
  if (!snapshot.exists) return {deleted: true};
  const isAdmin = request.auth?.token.admin === true;
  if (snapshot.get("authorId") !== uid && !isAdmin) {
    throw new HttpsError("permission-denied", "You cannot delete this story.");
  }
  const now = Timestamp.now();
  await storyRef.update({
    moderationState: "removed",
    expiresAt: now,
    deletedAt: now,
    updatedAt: now,
  });
  return {deleted: true};
});

export const reportReasons = new Set([
  "spam",
  "harassment",
  "hate",
  "violence",
  "dangerousActivity",
  "nudity",
  "misinformation",
  "impersonation",
  "intellectualProperty",
  "other",
]);

export const reportContent = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const targetType = String(data.targetType ?? "");
  const targetId = safeDocumentId(data.targetId, "targetId");
  const reason = String(data.reason ?? "");
  const details = typeof data.details === "string" ? data.details.trim() : "";
  if (!new Set(["user", "post", "comment", "story", "reel", "group"]).has(targetType) ||
      !reportReasons.has(reason) || details.length > 2000) {
    throw new HttpsError("invalid-argument", "The report is invalid.");
  }
  await consumeRateLimit(uid, {
    key: "content_report",
    maxAttempts: 30,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const reportRef = database.collection("reports").doc();
  const now = Timestamp.now();
  await reportRef.create({
    reporterId: uid,
    targetType,
    targetId,
    reason,
    ...(details ? {details} : {}),
    status: "open",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  await writeAuditEvent({
    actorId: uid,
    action: "content.report_created",
    targetType,
    targetId,
    metadata: {reportId: reportRef.id, reason},
  });
  return {reportId: reportRef.id};
});

export const blockUser = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = mapValue(request.data);
  const targetUserId = safeDocumentId(data.targetUserId, "targetUserId");
  if (uid === targetUserId) {
    throw new HttpsError("invalid-argument", "You cannot block yourself.");
  }
  await consumeRateLimit(uid, {
    key: "block_user",
    maxAttempts: 100,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const target = await database.collection(collections.users).doc(targetUserId).get();
  if (!target.exists) throw new HttpsError("not-found", "This account is unavailable.");
  const blockRef = database.doc(`users/${uid}/blocks/${targetUserId}`);
  const blockedByRef = database.doc(`users/${targetUserId}/blocked_by/${uid}`);
  const now = Timestamp.now();
  const blockRecord = {
    blockerId: uid,
    blockedId: targetUserId,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
  const batch = database.batch();
  batch.set(blockRef, blockRecord, {merge: true});
  batch.set(blockedByRef, blockRecord, {merge: true});
  await batch.commit();
  await removeRelationshipForBlock(database, uid, targetUserId);
  await purgeFeedEntriesBothDirections(database, uid, targetUserId);
  await writeAuditEvent({
    actorId: uid,
    action: "safety.user_blocked",
    targetType: "user",
    targetId: targetUserId,
  });
  return {blocked: true};
});

export function isActiveDocument(snapshot: DocumentSnapshot<DocumentData>): boolean {
  return snapshot.exists && snapshot.get("moderationState") === "active";
}
