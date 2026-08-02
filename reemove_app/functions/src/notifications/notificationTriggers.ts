import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";

import {primaryRegion} from "../core/functionOptions";
import {collections} from "../core/schema";
import {resolveAccountPrivacy} from "../profile/profilePrivacyModel";
import {deliverFollowRequestInboxNotification} from "./followRequestNotifications";
import {shouldDeliverNewFollowerNotification} from "./newFollowerPolicy";
import {createAndDeliverNotification} from "./notificationService";

function eventId(value: string | undefined, fallback: string): string {
  return value && value.length > 0 ? value : fallback;
}

function preview(value: unknown, fallback: string): string {
  if (typeof value !== "string" || value.trim().length === 0) return fallback;
  const text = value.trim().replace(/\s+/g, " ");
  return text.length <= 180 ? text : `${text.slice(0, 177)}...`;
}

export const notifyFollowRequestCreated = onDocumentCreated(
  {
    document: "follow_requests/{requestId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const document = event.data;
    if (!document || document.get("status") !== "pending") return;
    const requesterId = String(document.get("requesterId") ?? "");
    const targetId = String(document.get("targetId") ?? "");
    if (!requesterId || !targetId) return;
    await deliverFollowRequestInboxNotification(requesterId, targetId);
  },
);

export const notifyFollowerCreated = onDocumentCreated(
  {
    document: "users/{recipientId}/followers/{actorId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const recipientId = event.params.recipientId;
    const actorId = event.params.actorId;
    if (!recipientId || !actorId || !event.data?.exists) return;
    const source = String(event.data.get("source") ?? "");
    const recipient = await getFirestore().collection(collections.users)
      .doc(recipientId).get();
    if (!recipient.exists) return;
    const accountPrivacy = resolveAccountPrivacy(recipient);
    const followApprovalPolicy = String(
      recipient.get("followApprovalPolicy") ?? "",
    );
    if (!shouldDeliverNewFollowerNotification({
      edgeSource: source,
      accountPrivacy,
      followApprovalPolicy,
    })) {
      return;
    }
    await createAndDeliverNotification({
      eventId: eventId(event.id, `follower:${recipientId}:${actorId}`),
      recipientId,
      actorId,
      category: "activity",
      kind: "new_follower",
      title: "New follower",
      body: "A new athlete started following you.",
      route: `/profile/connections/${recipientId}/followers`,
      groupKey: "new_followers",
      entityType: "user",
      entityId: actorId,
      data: {
        profileId: actorId,
        relationshipStatus: "confirmed",
        source: "direct_follow",
        status: "confirmed",
      },
    });
  },
);

export const notifyPostCommentCreated = onDocumentCreated(
  {
    document: "posts/{postId}/comments/{commentId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const comment = event.data;
    if (!comment || comment.get("isDeleted") === true ||
        comment.get("moderationState") !== "active") return;
    const postId = event.params.postId;
    const post = await getFirestore().collection(collections.posts).doc(postId).get();
    if (!post.exists || post.get("moderationState") !== "active") return;
    const recipientId = String(post.get("authorId") ?? "");
    const actorId = String(comment.get("authorId") ?? "");
    if (!recipientId || !actorId) return;
    await createAndDeliverNotification({
      eventId: eventId(event.id, `comment:${postId}:${event.params.commentId}`),
      recipientId,
      actorId,
      category: "activity",
      kind: "post_comment",
      title: "New comment",
      body: preview(comment.get("text"), "Someone commented on your post."),
      route: `/home/post/${postId}`,
      groupKey: `post_comments:${postId}`,
      entityType: "post",
      entityId: postId,
      data: {postId, commentId: event.params.commentId},
      priority: "high",
    });
  },
);

export const notifyPostReactionWritten = onDocumentWritten(
  {
    document: "content_reactions/{reactionId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;
    const actorId = String(after.get("uid") ?? "");
    const postId = String(after.get("postId") ?? "");
    if (!actorId || !postId) return;
    const post = await getFirestore().collection(collections.posts).doc(postId).get();
    if (!post.exists || post.get("moderationState") !== "active") return;
    const recipientId = String(post.get("authorId") ?? "");
    if (!recipientId) return;
    const transitions = [
      {
        field: "liked",
        kind: "post_like" as const,
        title: "New like",
        body: "Someone liked your post.",
        group: `post_likes:${postId}`,
      },
      {
        field: "reposted",
        kind: "post_repost" as const,
        title: "New repost",
        body: "Someone reposted your post.",
        group: `post_reposts:${postId}`,
      },
    ];
    for (const transition of transitions) {
      const wasActive = before?.exists && before.get(transition.field) === true;
      const isActive = after.get(transition.field) === true;
      if (wasActive || !isActive) continue;
      await createAndDeliverNotification({
        eventId: `${eventId(event.id, event.params.reactionId)}:${transition.field}`,
        recipientId,
        actorId,
        category: "activity",
        kind: transition.kind,
        title: transition.title,
        body: transition.body,
        route: `/home/post/${postId}`,
        groupKey: transition.group,
        entityType: "post",
        entityId: postId,
        data: {postId},
      });
    }
  },
);

export const notifyChallengeSubmissionCreated = onDocumentCreated(
  {
    document: "challenges/{challengeId}/submissions/{submissionId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const submission = event.data;
    if (!submission || !["pending", "flagged"].includes(
      String(submission.get("status")),
    )) return;
    const challengeId = event.params.challengeId;
    const challenge = await getFirestore().collection(collections.challenges)
      .doc(challengeId).get();
    if (!challenge.exists) return;
    const recipientId = String(challenge.get("creatorId") ?? "");
    const actorId = String(submission.get("userId") ?? "");
    if (!recipientId || !actorId) return;
    await createAndDeliverNotification({
      eventId: eventId(event.id, `challenge-submission:${event.params.submissionId}`),
      recipientId,
      actorId,
      category: "challenges",
      kind: "challenge_submission",
      title: "Challenge proof ready",
      body: "A participant submitted progress for your review.",
      route: `/discover/challenges/${challengeId}/review`,
      groupKey: `challenge_submissions:${challengeId}`,
      entityType: "challenge",
      entityId: challengeId,
      data: {
        challengeId,
        submissionId: event.params.submissionId,
      },
      priority: "high",
    });
  },
);

export const notifyChallengeSubmissionReviewed = onDocumentWritten(
  {
    document: "challenges/{challengeId}/submissions/{submissionId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists || !after?.exists) return;
    const previousStatus = String(before.get("status") ?? "");
    const status = String(after.get("status") ?? "");
    if (previousStatus === status || !["verified", "rejected"].includes(status)) return;
    const recipientId = String(after.get("userId") ?? "");
    const reviewerId = String(after.get("reviewedBy") ?? "");
    const challengeId = event.params.challengeId;
    if (!recipientId) return;
    await createAndDeliverNotification({
      eventId: `${eventId(event.id, event.params.submissionId)}:${status}`,
      recipientId,
      ...(reviewerId ? {actorId: reviewerId} : {}),
      category: "challenges",
      kind: "challenge_review",
      title: status === "verified" ? "Progress verified" : "Progress needs changes",
      body: status === "verified" ?
        "Your challenge progress was verified." :
        "Your challenge submission was not verified. Review the feedback and try again safely.",
      route: `/discover/challenges/${challengeId}`,
      groupKey: `challenge_review:${challengeId}`,
      entityType: "challenge",
      entityId: challengeId,
      data: {challengeId, submissionId: event.params.submissionId, status},
      priority: "high",
    });
  },
);

export const notifyChallengeRewardCreated = onDocumentCreated(
  {
    document: "reward_claims/{claimId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const claim = event.data;
    if (!claim || claim.get("status") !== "claimed") return;
    const recipientId = String(claim.get("userId") ?? "");
    const challengeId = String(claim.get("challengeId") ?? "");
    if (!recipientId || !challengeId) return;
    await createAndDeliverNotification({
      eventId: eventId(event.id, `reward:${event.params.claimId}`),
      recipientId,
      category: "challenges",
      kind: "challenge_reward",
      title: "Reward unlocked",
      body: "Your verified challenge reward is now available.",
      route: "/discover/challenges/rewards",
      groupKey: "challenge_rewards",
      entityType: "challenge",
      entityId: challengeId,
      data: {challengeId, claimId: event.params.claimId},
    });
  },
);

export const notifySportsEventAttendanceCreated = onDocumentCreated(
  {
    document: "events/{eventId}/attendees/{attendeeId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const attendee = event.data;
    if (!attendee || !["attending", "waitlisted"].includes(
      String(attendee.get("status")),
    )) return;
    const eventIdValue = event.params.eventId;
    const sportsEvent = await getFirestore().collection(collections.events)
      .doc(eventIdValue).get();
    if (!sportsEvent.exists) return;
    const recipientId = String(sportsEvent.get("ownerId") ?? "");
    const actorId = String(attendee.get("userId") ?? event.params.attendeeId);
    const sportId = String(sportsEvent.get("sportId") ?? "");
    if (!recipientId || !actorId || recipientId === actorId) return;
    await createAndDeliverNotification({
      eventId: eventId(event.id, `event-attendee:${eventIdValue}:${actorId}`),
      recipientId,
      actorId,
      category: "events",
      kind: "event_update",
      title: attendee.get("status") === "waitlisted" ?
        "Event waitlist update" : "New event attendee",
      body: attendee.get("status") === "waitlisted" ?
        "An athlete joined your event waitlist." :
        "An athlete is attending your sports event.",
      route: `/sports/${sportId}/events/${eventIdValue}`,
      groupKey: `event_attendance:${eventIdValue}`,
      entityType: "event",
      entityId: eventIdValue,
      data: {eventId: eventIdValue, sportId},
    });
  },
);

export const notifyMarketplaceListingWritten = onDocumentWritten(
  {
    document: "marketplace_listings/{listingId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists || !after?.exists) return;
    const previousStatus = String(before.get("status") ?? "");
    const status = String(after.get("status") ?? "");
    const previousModeration = String(before.get("moderationState") ?? "");
    const moderation = String(after.get("moderationState") ?? "");
    if (previousStatus === status && previousModeration === moderation) return;
    const recipientId = String(after.get("sellerId") ?? "");
    if (!recipientId) return;
    const listingId = event.params.listingId;
    let title = "Marketplace listing updated";
    let body = `Your listing is now ${status}.`;
    if (moderation === "rejected" || status === "rejected") {
      title = "Listing needs changes";
      body = preview(
        after.get("rejectionReason"),
        "Review the listing policy and update your item before publishing again.",
      );
    } else if (status === "active" && previousStatus !== "active") {
      title = "Listing is live";
      body = "Your marketplace listing is now visible to athletes.";
    } else if (status === "expired") {
      title = "Listing expired";
      body = "Your listing expired. You can review and relist it from your marketplace library.";
    }
    await createAndDeliverNotification({
      eventId: `${eventId(event.id, listingId)}:${status}:${moderation}`,
      recipientId,
      category: "marketplace",
      kind: "marketplace_update",
      title,
      body,
      route: `/discover/marketplace/listing/${listingId}`,
      groupKey: `marketplace_listing:${listingId}`,
      entityType: "marketplace_listing",
      entityId: listingId,
      data: {listingId, status, moderationState: moderation},
    });
  },
);

export const notifyScheduledEventStarting = onDocumentWritten(
  {
    document: "events/{eventId}",
    region: primaryRegion,
    retry: true,
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists || !after?.exists) return;
    const previousStatus = String(before.get("status") ?? "");
    const status = String(after.get("status") ?? "");
    if (previousStatus === status) return;
    if (!["cancelled", "completed"].includes(status)) return;
    const eventIdValue = event.params.eventId;
    const attendees = await after.ref.collection("attendees")
      .where("status", "==", "attending")
      .limit(500)
      .get();
    const sportId = String(after.get("sportId") ?? "");
    const ownerId = String(after.get("ownerId") ?? "");
    for (const attendee of attendees.docs) {
      const recipientId = String(attendee.get("userId") ?? attendee.id);
      if (!recipientId || recipientId === ownerId) continue;
      await createAndDeliverNotification({
        eventId: `${eventId(event.id, eventIdValue)}:${status}:${recipientId}`,
        recipientId,
        ...(ownerId ? {actorId: ownerId} : {}),
        category: "events",
        kind: "event_update",
        title: status === "cancelled" ? "Event cancelled" : "Event completed",
        body: status === "cancelled" ?
          "A sports event you planned to attend was cancelled." :
          "Your sports event has finished. Share your activity when you are ready.",
        route: `/sports/${sportId}/events/${eventIdValue}`,
        groupKey: `event_status:${eventIdValue}`,
        entityType: "event",
        entityId: eventIdValue,
        data: {eventId: eventIdValue, sportId, status},
        priority: status === "cancelled" ? "high" : "normal",
      });
    }
  },
);

export function isRecentTimestamp(value: unknown, maximumAgeDays: number): boolean {
  if (!(value instanceof Timestamp)) return false;
  return Date.now() - value.toMillis() <= maximumAgeDays * 24 * 60 * 60 * 1000;
}
