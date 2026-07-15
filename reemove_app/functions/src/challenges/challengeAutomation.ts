import {getFirestore, Timestamp, type QueryDocumentSnapshot} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {writeAuditEvent} from "../core/audit";
import {callableOptions, primaryRegion} from "../core/functionOptions";
import {collections, currentSchemaVersion} from "../core/schema";
import {requireUid} from "../messaging/conversationAccess";
import {createAndDeliverNotification} from "../notifications/notificationService";
import {progressPercent} from "./challengePolicy";

const safeTemplates = [
  {
    sportId: "running",
    title: "Steady Week: 10 km",
    description:
      "Build consistency by recording a total of 10 km across the week. Split the distance into comfortable sessions and include rest days.",
    difficulty: "beginner",
    metric: "distance",
    target: 10,
    unit: "km",
    maximumDailyProgress: 5,
    maximumEffortMinutesPerDay: 90,
    badgeId: "steady-runner",
  },
  {
    sportId: "gym",
    title: "Three Quality Sessions",
    description:
      "Complete three well-planned gym sessions this week. Prioritize controlled technique, appropriate loads, and recovery.",
    difficulty: "beginner",
    metric: "sessions",
    target: 3,
    unit: "sessions",
    maximumDailyProgress: 1,
    maximumEffortMinutesPerDay: 90,
    badgeId: "consistent-lifter",
  },
  {
    sportId: "football",
    title: "Football Skills Week",
    description:
      "Complete two verified football practice sessions this week with a focus on safe, controlled skill work and team participation.",
    difficulty: "beginner",
    metric: "sessions",
    target: 2,
    unit: "sessions",
    maximumDailyProgress: 1,
    maximumEffortMinutesPerDay: 90,
    badgeId: "football-rhythm",
  },
] as const;

function weekKey(date: Date): string {
  const utc = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = utc.getUTCDay() || 7;
  utc.setUTCDate(utc.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((utc.getTime() - yearStart.getTime()) / 86_400_000) + 1) / 7);
  return `${utc.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function currentWeekBounds(now = new Date()): {startsAt: Date; endsAt: Date} {
  const startsAt = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    0,
    0,
    0,
  ));
  const day = startsAt.getUTCDay() || 7;
  startsAt.setUTCDate(startsAt.getUTCDate() - day + 1);
  const endsAt = new Date(startsAt.getTime() + 7 * 24 * 60 * 60 * 1000);
  return {startsAt, endsAt};
}

export async function generateSafeWeeklyChallenges(now = new Date()): Promise<number> {
  const database = getFirestore();
  const key = weekKey(now);
  const bounds = currentWeekBounds(now);
  const timestamp = Timestamp.now();
  const batch = database.batch();
  let writes = 0;
  for (const template of safeTemplates) {
    const reference = database
      .collection(collections.challenges)
      .doc(`ai-${template.sportId}-${key}`);
    const existing = await reference.get();
    if (existing.exists) continue;
    batch.create(reference, {
      creatorId: "system",
      creatorName: "ReeMove Coach",
      sportId: template.sportId,
      title: template.title,
      description: template.description,
      source: "ai",
      status: now >= bounds.startsAt && now < bounds.endsAt ? "active" : "scheduled",
      difficulty: template.difficulty,
      startsAt: Timestamp.fromDate(bounds.startsAt),
      endsAt: Timestamp.fromDate(bounds.endsAt),
      rules: [{
        metric: template.metric,
        target: template.target,
        unit: template.unit,
        verificationMethod: "automaticActivity",
        maximumDailyProgress: template.maximumDailyProgress,
      }],
      safetyPolicy: {
        minimumAge: 14,
        requiresRestDays: true,
        maximumEffortMinutesPerDay: template.maximumEffortMinutesPerDay,
        prohibitedBehaviors: [
          "continuing through pain",
          "sleep or hydration deprivation",
          "unsafe equipment use",
          "unverified extreme effort",
        ],
        healthDisclaimer:
          "Stop if you feel pain, dizziness, or unusual discomfort and seek qualified help.",
      },
      media: [],
      participantCount: 0,
      completionCount: 0,
      badgeId: template.badgeId,
      rewardIds: [],
      visibility: "public",
      moderationState: "active",
      isFeatured: true,
      aiDisclosure:
        "Generated from a safety-reviewed ReeMove template. External AI generation remains disabled until Phase 14 safety evaluation is complete.",
      generator: {
        type: "curated_template",
        version: "phase11-v1",
        weekKey: key,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
      schemaVersion: currentSchemaVersion,
    });
    writes += 1;
  }
  if (writes > 0) await batch.commit();
  return writes;
}

export const generateWeeklyChallenges = onSchedule({
  region: primaryRegion,
  schedule: "5 0 * * 1",
  timeZone: "UTC",
  retryCount: 2,
}, async () => {
  const written = await generateSafeWeeklyChallenges();
  logger.info("Weekly safe challenges generated.", {written});
});

export const generateWeeklyChallengesNow = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    if (request.auth?.token.admin !== true) {
      throw new HttpsError("permission-denied", "Administrator access is required.");
    }
    const written = await generateSafeWeeklyChallenges();
    await writeAuditEvent({
      actorId: uid,
      action: "challenges.weekly_generated",
      targetType: "challenges",
      targetId: weekKey(new Date()),
      metadata: {written},
    });
    return {written};
  },
);

export async function rebuildChallengeLeaderboards(): Promise<number> {
  const database = getFirestore();
  const now = Timestamp.now();
  const challenges = await database.collection(collections.challenges)
    .where("moderationState", "==", "active")
    .where("status", "in", ["active", "completed"])
    .limit(100)
    .get();
  let updated = 0;
  for (const challenge of challenges.docs) {
    const participants = await challenge.ref.collection("participants")
      .where("status", "in", ["active", "completed"])
      .orderBy("progress", "desc")
      .limit(100)
      .get();
    const targetRules = challenge.get("rules");
    const firstRule = Array.isArray(targetRules) && targetRules[0] ?
      targetRules[0] as Record<string, unknown> : {};
    const target = Number(firstRule.target ?? 0);
    const batch = database.batch();
    participants.docs.forEach((participant, index) => {
      const progress = Number(participant.get("progress") ?? 0);
      const rank = index + 1;
      const entryRef = challenge.ref.collection("leaderboard").doc(participant.id);
      batch.set(entryRef, {
        userId: participant.id,
        displayName: String(participant.get("displayName") ?? "Athlete"),
        username: String(participant.get("username") ?? ""),
        ...(participant.get("avatarUrl") ? {
          avatarUrl: String(participant.get("avatarUrl")),
        } : {}),
        progress,
        progressPercent: progressPercent(progress, target),
        rank,
        verifiedAt: participant.get("lastSubmissionAt") ?? null,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
      batch.update(participant.ref, {rank, updatedAt: now});
    });
    if (participants.size > 0) await batch.commit();
    updated += participants.size;
  }
  return updated;
}

export const refreshChallengeLeaderboards = onSchedule({
  region: primaryRegion,
  schedule: "every 15 minutes",
  timeZone: "UTC",
  retryCount: 2,
}, async () => {
  const updated = await rebuildChallengeLeaderboards();
  logger.info("Challenge leaderboard entries refreshed.", {updated});
});

export const finalizeExpiredChallenges = onSchedule({
  region: primaryRegion,
  schedule: "every 60 minutes",
  timeZone: "UTC",
  retryCount: 2,
}, async () => {
  const database = getFirestore();
  const now = Timestamp.now();
  const expired = await database.collection(collections.challenges)
    .where("status", "in", ["active", "scheduled"])
    .where("endsAt", "<=", now)
    .limit(300)
    .get();
  if (expired.empty) return;
  const batch = database.batch();
  for (const challenge of expired.docs) {
    batch.update(challenge.ref, {status: "completed", updatedAt: now});
  }
  await batch.commit();
  logger.info("Expired challenges finalized.", {count: expired.size});
});

function eligibleForReminder(
  participant: QueryDocumentSnapshot,
  now: Timestamp,
): boolean {
  if (participant.get("status") !== "active" ||
      participant.get("reminderEnabled") !== true) return false;
  const lastReminderAt = participant.get("lastReminderAt");
  return !(lastReminderAt instanceof Timestamp) ||
    now.toMillis() - lastReminderAt.toMillis() >= 22 * 60 * 60 * 1000;
}

export const sendChallengeReminders = onSchedule({
  region: primaryRegion,
  schedule: "every 60 minutes",
  timeZone: "UTC",
  retryCount: 1,
}, async () => {
  const database = getFirestore();
  const now = Timestamp.now();
  const participants = await database.collectionGroup("participants")
    .where("status", "==", "active")
    .where("reminderEnabled", "==", true)
    .limit(500)
    .get();
  const eligible = participants.docs.filter((item) => eligibleForReminder(item, now));
  for (const participant of eligible) {
    const uid = String(participant.get("userId") ?? "");
    const challengeId = String(participant.get("challengeId") ?? "");
    if (!uid || !challengeId) continue;
    const challenge = await database.collection(collections.challenges)
      .doc(challengeId).get();
    if (!challenge.exists || challenge.get("status") !== "active") continue;
    await createAndDeliverNotification({
      eventId: `challenge-reminder:${challengeId}:${uid}:${now.toDate().toISOString().slice(0, 13)}`,
      recipientId: uid,
      category: "challenges",
      kind: "challenge_reminder",
      title: "Your challenge is active",
      body: `${String(challenge.get("title") ?? "Challenge")}: add progress when you are ready. Rest and safety come first.`,
      route: `/ch/${challengeId}`,
      groupKey: `challenge_reminder:${challengeId}`,
      entityType: "challenge",
      entityId: challengeId,
      data: {challengeId},
    });
    await participant.ref.update({lastReminderAt: now, updatedAt: now});
  }
  logger.info("Challenge reminder pass completed.", {eligible: eligible.length});
});
