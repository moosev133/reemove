import {getStorage} from "firebase-admin/storage";
import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {activeProfileSnapshot, requireUid} from "../messaging/conversationAccess";
import {assessSubmissionRisk} from "./antiCheat";
import {
  asRecord,
  calculateAge,
  parseChallengeInput,
  progressPercent,
  type ChallengeMetric,
  type ChallengeVerificationMethod,
} from "./challengePolicy";

const safetyPolicy = {
  prohibitedBehaviors: [
    "continuing through pain",
    "sleep or hydration deprivation",
    "unsafe equipment use",
    "substance use",
    "unverified extreme effort",
  ],
  healthDisclaimer:
    "Stop if you feel pain, dizziness, or unusual discomfort and seek qualified help.",
};

function requiredString(
  value: unknown,
  label: string,
  maximum = 160,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return normalized;
}

function optionalString(
  value: unknown,
  label: string,
  maximum = 500,
): string | undefined {
  if (value === null || value === undefined || value === "") return undefined;
  return requiredString(value, label, maximum);
}

function positiveNumber(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new HttpsError("invalid-argument", `${label} must be positive.`);
  }
  return value;
}

async function assertEnabledSport(
  database: Firestore,
  sportId: string,
): Promise<void> {
  const sport = await database.collection(collections.sports).doc(sportId).get();
  if (!sport.exists || sport.get("isEnabled") !== true) {
    throw new HttpsError("failed-precondition", "This sport is unavailable.");
  }
}

async function isCommunityManager(
  database: Firestore,
  communityId: string,
  uid: string,
): Promise<boolean> {
  const member = await database
    .doc(`${collections.teams}/${communityId}/members/${uid}`)
    .get();
  return member.exists && member.get("status") === "active" &&
    ["owner", "administrator", "admin"].includes(String(member.get("role")));
}

async function profileAge(database: Firestore, uid: string): Promise<number> {
  const profile = await database.doc(`users/${uid}/private/profile`).get();
  const dateOfBirth = profile.get("dateOfBirth");
  if (typeof dateOfBirth !== "string") {
    throw new HttpsError(
      "failed-precondition",
      "Complete your private age information before joining challenges.",
    );
  }
  const age = calculateAge(dateOfBirth);
  if (age < 0) {
    throw new HttpsError("failed-precondition", "Your age information is invalid.");
  }
  return age;
}

function profileFields(profile: Record<string, unknown>): Record<string, unknown> {
  return {
    displayName: String(profile.displayName ?? "Athlete"),
    username: String(profile.username ?? ""),
    ...(profile.avatarUrl ? {avatarUrl: String(profile.avatarUrl)} : {}),
  };
}

async function assertChallengeAvailable(
  database: Firestore,
  challengeId: string,
): Promise<DocumentSnapshot<DocumentData>> {
  const challenge = await database.collection(collections.challenges).doc(challengeId).get();
  if (!challenge.exists || challenge.get("moderationState") !== "active" ||
      !["active", "scheduled"].includes(String(challenge.get("status")))) {
    throw new HttpsError("not-found", "This challenge is unavailable.");
  }
  return challenge;
}

function primaryRule(challenge: DocumentSnapshot<DocumentData>): Record<string, unknown> {
  const rules = challenge.get("rules");
  if (!Array.isArray(rules) || typeof rules[0] !== "object" || rules[0] === null) {
    throw new HttpsError("failed-precondition", "This challenge has invalid rules.");
  }
  return rules[0] as Record<string, unknown>;
}

function activityMetric(metric: ChallengeMetric): string | null {
  return {
    distance: "distanceKm",
    duration: "durationMinutes",
    sessions: null,
    repetitions: "repetitions",
    volume: "volumeKg",
    attendance: null,
    points: "matchPoints",
  }[metric];
}

async function verifyProof(
  proofStoragePath: string | undefined,
  uid: string,
  challengeId: string,
): Promise<boolean> {
  if (!proofStoragePath) return false;
  const prefix = `challenge_proofs/${uid}/${challengeId}/`;
  if (!proofStoragePath.startsWith(prefix)) return false;
  try {
    const [metadata] = await getStorage().bucket().file(proofStoragePath).getMetadata();
    const custom = metadata.metadata ?? {};
    return custom.ownerId === uid && custom.challengeId === challengeId &&
      custom.schemaVersion === "1";
  } catch {
    return false;
  }
}

async function verifyActivity(input: {
  database: Firestore;
  activityId: string | undefined;
  uid: string;
  challenge: DocumentSnapshot<DocumentData>;
  metric: ChallengeMetric;
  progressDelta: number;
}): Promise<{verified: boolean; duplicate: boolean}> {
  if (!input.activityId) return {verified: false, duplicate: false};
  const activityRef = input.database.collection(collections.activities).doc(input.activityId);
  const usedRef = input.challenge.ref.collection("used_activities").doc(input.activityId);
  const [activity, used] = await Promise.all([activityRef.get(), usedRef.get()]);
  if (used.exists) return {verified: false, duplicate: true};
  if (!activity.exists || activity.get("userId") !== input.uid ||
      activity.get("sportId") !== input.challenge.get("sportId") ||
      activity.get("status") !== "verified") {
    return {verified: false, duplicate: false};
  }
  const occurredAt = activity.get("occurredAt");
  const startsAt = input.challenge.get("startsAt");
  const endsAt = input.challenge.get("endsAt");
  if (!(occurredAt instanceof Timestamp) || !(startsAt instanceof Timestamp) ||
      !(endsAt instanceof Timestamp) || occurredAt.toMillis() < startsAt.toMillis() ||
      occurredAt.toMillis() > endsAt.toMillis()) {
    return {verified: false, duplicate: false};
  }
  const metricKey = activityMetric(input.metric);
  if (metricKey === null) {
    return {verified: input.progressDelta === 1, duplicate: false};
  }
  const metrics = activity.get("metrics");
  const value = typeof metrics === "object" && metrics !== null ?
    (metrics as Record<string, unknown>)[metricKey] : undefined;
  return {
    verified: typeof value === "number" && Number.isFinite(value) &&
      value + Number.EPSILON >= input.progressDelta,
    duplicate: false,
  };
}

function utcDayKey(value: Timestamp): string {
  return value.toDate().toISOString().slice(0, 10);
}

async function applyVerifiedProgress(input: {
  database: Firestore;
  challenge: DocumentSnapshot<DocumentData>;
  participantRef: DocumentReference<DocumentData>;
  progressDelta: number;
  submissionRef: DocumentReference<DocumentData>;
  activityId?: string;
  uid: string;
  profile: Record<string, unknown>;
}): Promise<void> {
  const rule = primaryRule(input.challenge);
  const target = Number(rule.target ?? 0);
  const maximumDailyProgress = Number(rule.maximumDailyProgress ?? 0);
  await input.database.runTransaction(async (transaction) => {
    const [latestChallenge, participant, submission] = await Promise.all([
      transaction.get(input.challenge.ref),
      transaction.get(input.participantRef),
      transaction.get(input.submissionRef),
    ]);
    if (!latestChallenge.exists || latestChallenge.get("status") !== "active" ||
        latestChallenge.get("moderationState") !== "active") {
      throw new HttpsError("failed-precondition", "This challenge is no longer active.");
    }
    if (!participant.exists || participant.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "Join the challenge before submitting progress.");
    }
    if (submission.get("status") === "verified") return;
    const now = Timestamp.now();
    const submissionCreatedAt = submission.get("createdAt");
    const progressDay = utcDayKey(
      submissionCreatedAt instanceof Timestamp ? submissionCreatedAt : now,
    );
    const currentDailyProgress = participant.get("dailyProgressDay") === progressDay ?
      Number(participant.get("dailyProgressAmount") ?? 0) : 0;
    if (maximumDailyProgress <= 0 ||
        currentDailyProgress + input.progressDelta > maximumDailyProgress) {
      throw new HttpsError(
        "failed-precondition",
        "This submission would exceed the challenge daily progress limit.",
      );
    }
    const previous = Number(participant.get("progress") ?? 0);
    const next = Math.min(target, previous + input.progressDelta);
    const completed = previous < target && next >= target;
    transaction.update(input.participantRef, {
      progress: next,
      progressPercent: progressPercent(next, target),
      status: completed ? "completed" : "active",
      ...(completed ? {completedAt: now} : {}),
      dailyProgressDay: progressDay,
      dailyProgressAmount: currentDailyProgress + input.progressDelta,
      lastSubmissionAt: now,
      updatedAt: now,
    });
    transaction.set(
      input.challenge.ref.collection("leaderboard").doc(input.uid),
      {
        userId: input.uid,
        ...profileFields(input.profile),
        progress: next,
        progressPercent: progressPercent(next, target),
        rank: Number(participant.get("rank") ?? 0),
        verifiedAt: now,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      },
      {merge: true},
    );
    transaction.update(input.submissionRef, {
      status: "verified",
      reviewedAt: now,
      reviewedBy: "system",
      updatedAt: now,
    });
    if (input.activityId) {
      transaction.create(
        input.challenge.ref.collection("used_activities").doc(input.activityId),
        {
          activityId: input.activityId,
          userId: input.uid,
          submissionId: input.submissionRef.id,
          createdAt: now,
          schemaVersion: currentSchemaVersion,
        },
      );
    }
    if (completed) {
      transaction.update(input.challenge.ref, {
        completionCount: FieldValue.increment(1),
        updatedAt: now,
      });
    }
  });
}

export const createChallenge = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseChallengeInput(request.data);
  await consumeRateLimit(uid, {
    key: "create_challenge",
    maxAttempts: 6,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  await assertEnabledSport(database, input.sportId);
  const profile = await activeProfileSnapshot(database, uid);
  const profileDoc = await database.collection(collections.users).doc(uid).get();
  const creatorRole = String(profileDoc.get("role") ?? "athlete");
  const verifiedCreator = profileDoc.get("isVerified") === true;
  const professionalCreator = verifiedCreator &&
    ["trainer", "business"].includes(creatorRole);
  const communityManager = input.communityId ?
    await isCommunityManager(database, input.communityId, uid) : false;
  if (input.communityId && !communityManager) {
    throw new HttpsError(
      "permission-denied",
      "Only community managers can publish a challenge for this community.",
    );
  }
  const now = Timestamp.now();
  const reference = database.collection(collections.challenges).doc();
  const immediatelyTrusted = verifiedCreator || communityManager ||
    request.auth?.token.admin === true;
  const startsAt = Timestamp.fromDate(input.startsAt);
  await reference.set({
    creatorId: uid,
    creatorName: String(profile.displayName ?? "Athlete"),
    sportId: input.sportId,
    title: input.title,
    description: input.description,
    source: professionalCreator ? "trainer" : "community",
    status: startsAt.toMillis() > now.toMillis() ? "scheduled" : "active",
    difficulty: input.difficulty,
    startsAt,
    endsAt: Timestamp.fromDate(input.endsAt),
    rules: [{
      metric: input.metric,
      target: input.target,
      unit: input.unit,
      verificationMethod: input.verificationMethod,
      maximumDailyProgress: input.maximumDailyProgress,
    }],
    safetyPolicy: {
      minimumAge: input.minimumAge,
      requiresRestDays: input.requiresRestDays,
      maximumEffortMinutesPerDay: input.maximumEffortMinutesPerDay,
      ...safetyPolicy,
    },
    media: [],
    participantCount: 0,
    completionCount: 0,
    rewardIds: [],
    ...(input.communityId ? {communityId: input.communityId} : {}),
    visibility: "public",
    moderationState: immediatelyTrusted ? "active" : "pending",
    isFeatured: false,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  await writeAuditEvent({
    actorId: uid,
    action: "challenges.created",
    targetType: "challenge",
    targetId: reference.id,
    metadata: {
      sportId: input.sportId,
      moderationState: immediatelyTrusted ? "active" : "pending",
    },
  });
  return {
    challengeId: reference.id,
    moderationState: immediatelyTrusted ? "active" : "pending",
  };
});

export const joinChallenge = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const challengeId = requiredString(data.challengeId, "Challenge", 120);
  await consumeRateLimit(uid, {
    key: "join_challenge",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const challenge = await assertChallengeAvailable(database, challengeId);
  const now = Timestamp.now();
  const startsAt = challenge.get("startsAt");
  const endsAt = challenge.get("endsAt");
  if (!(startsAt instanceof Timestamp) || !(endsAt instanceof Timestamp) ||
      startsAt.toMillis() > now.toMillis() || endsAt.toMillis() <= now.toMillis()) {
    throw new HttpsError("failed-precondition", "This challenge is not currently open.");
  }
  const age = await profileAge(database, uid);
  const policy = challenge.get("safetyPolicy") as Record<string, unknown> | undefined;
  const minimumAge = Number(policy?.minimumAge ?? 14);
  if (age < minimumAge) {
    throw new HttpsError(
      "permission-denied",
      `This challenge is available from age ${minimumAge}.`,
    );
  }
  const profile = await activeProfileSnapshot(database, uid);
  const participantRef = challenge.ref.collection("participants").doc(uid);
  await database.runTransaction(async (transaction) => {
    const participant = await transaction.get(participantRef);
    if (participant.exists && participant.get("status") !== "withdrawn") return;
    transaction.set(participantRef, {
      challengeId,
      userId: uid,
      ...profileFields(profile),
      status: "active",
      progress: 0,
      progressPercent: 0,
      rank: null,
      reminderEnabled: true,
      joinedAt: now,
      updatedAt: now,
      completedAt: null,
      dailyProgressDay: null,
      dailyProgressAmount: 0,
      lastSubmissionAt: null,
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(challenge.ref, {
      participantCount: FieldValue.increment(1),
      updatedAt: now,
    });
  });
  await writeAuditEvent({
    actorId: uid,
    action: "challenges.joined",
    targetType: "challenge",
    targetId: challengeId,
  });
  return {ok: true};
});

export const leaveChallenge = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const challengeId = requiredString(data.challengeId, "Challenge", 120);
  const database = getFirestore();
  const challengeRef = database.collection(collections.challenges).doc(challengeId);
  const participantRef = challengeRef.collection("participants").doc(uid);
  await database.runTransaction(async (transaction) => {
    const [challenge, participant] = await Promise.all([
      transaction.get(challengeRef),
      transaction.get(participantRef),
    ]);
    if (!challenge.exists || !participant.exists ||
        participant.get("status") === "withdrawn") return;
    const now = Timestamp.now();
    transaction.update(participantRef, {
      status: "withdrawn",
      reminderEnabled: false,
      updatedAt: now,
    });
    transaction.delete(challengeRef.collection("leaderboard").doc(uid));
    transaction.update(challengeRef, {
      participantCount: FieldValue.increment(-1),
      updatedAt: now,
    });
  });
  await writeAuditEvent({
    actorId: uid,
    action: "challenges.left",
    targetType: "challenge",
    targetId: challengeId,
  });
  return {ok: true};
});

export const submitChallengeProgress = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const challengeId = requiredString(data.challengeId, "Challenge", 120);
    const progressDelta = positiveNumber(data.progressDelta, "Progress");
    const activityId = optionalString(data.activityId, "Activity", 120);
    const proofStoragePath = optionalString(data.proofStoragePath, "Proof", 500);
    const note = optionalString(data.note, "Note", 300);
    await consumeRateLimit(uid, {
      key: "submit_challenge_progress",
      maxAttempts: 20,
      windowSeconds: 24 * 60 * 60,
    });
    const database = getFirestore();
    const challenge = await assertChallengeAvailable(database, challengeId);
    if (challenge.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "This challenge has not started.");
    }
    const participantRef = challenge.ref.collection("participants").doc(uid);
    const participant = await participantRef.get();
    if (!participant.exists || participant.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "Join the challenge first.");
    }
    const rule = primaryRule(challenge);
    const metric = String(rule.metric) as ChallengeMetric;
    const verificationMethod = String(
      rule.verificationMethod,
    ) as ChallengeVerificationMethod;
    const maximumDailyProgress = Number(rule.maximumDailyProgress ?? 0);
    if (progressDelta > maximumDailyProgress) {
      throw new HttpsError(
        "invalid-argument",
        "This progress is above the challenge daily verification cap.",
      );
    }
    const hasProof = await verifyProof(proofStoragePath, uid, challengeId);
    const proofRequired = [
      "activityAndProof",
      "photoProof",
      "organizerReview",
    ].includes(verificationMethod);
    if (proofRequired && !hasProof) {
      throw new HttpsError("failed-precondition", "Required proof is missing or invalid.");
    }
    const activity = await verifyActivity({
      database,
      activityId,
      uid,
      challenge,
      metric,
      progressDelta,
    });
    const activityRequired = [
      "automaticActivity",
      "activityAndProof",
    ].includes(verificationMethod);
    if (activity.duplicate) {
      throw new HttpsError("already-exists", "This activity was already used.");
    }
    if (activityRequired && !activity.verified) {
      throw new HttpsError(
        "failed-precondition",
        "The linked activity could not verify this progress.",
      );
    }
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const todays = await challenge.ref.collection("submissions")
      .where("userId", "==", uid)
      .where("createdAt", ">=", Timestamp.fromDate(dayStart))
      .limit(20)
      .get();
    const verifiedToday = todays.docs
      .filter((item) => item.get("status") === "verified")
      .reduce((total, item) => total + Number(item.get("progressDelta") ?? 0), 0);
    if (verifiedToday + progressDelta > maximumDailyProgress) {
      throw new HttpsError(
        "invalid-argument",
        "Your verified progress for today reached this challenge's daily cap.",
      );
    }
    const lastSubmissionAt = participant.get("lastSubmissionAt");
    const minutesSincePreviousSubmission = lastSubmissionAt instanceof Timestamp ?
      (Date.now() - lastSubmissionAt.toMillis()) / 60_000 : undefined;
    const risk = assessSubmissionRisk({
      progressDelta,
      maximumDailyProgress,
      metric,
      activityVerified: activityRequired ? activity.verified : true,
      hasRequiredProof: proofRequired ? hasProof : true,
      duplicateActivity: activity.duplicate,
      submissionCountToday: todays.size,
      minutesSincePreviousSubmission,
    });
    const profile = await activeProfileSnapshot(database, uid);
    const now = Timestamp.now();
    const submissionRef = challenge.ref.collection("submissions").doc();
    const canAutoVerify = risk.autoVerify &&
      verificationMethod === "automaticActivity";
    await submissionRef.set({
      challengeId,
      userId: uid,
      ...profileFields(profile),
      progressDelta,
      ...(activityId ? {activityId} : {}),
      ...(proofStoragePath ? {proofStoragePath} : {}),
      ...(note ? {note} : {}),
      status: canAutoVerify ? "pending" : risk.score >= 70 ? "flagged" : "pending",
      riskScore: risk.score,
      riskReasons: risk.reasons,
      createdAt: now,
      updatedAt: now,
      reviewedAt: null,
      schemaVersion: currentSchemaVersion,
    });
    if (canAutoVerify) {
      await applyVerifiedProgress({
        database,
        challenge,
        participantRef,
        progressDelta,
        submissionRef,
        activityId,
        uid,
        profile,
      });
    }
    await writeAuditEvent({
      actorId: uid,
      action: "challenges.progress_submitted",
      targetType: "challenge_submission",
      targetId: submissionRef.id,
      metadata: {
        challengeId,
        autoVerified: canAutoVerify,
        riskScore: risk.score,
      },
    });
    return {submissionId: submissionRef.id, autoVerified: canAutoVerify};
  },
);

export const reviewChallengeSubmission = onCall(
  callableOptions,
  async (request) => {
    const reviewerId = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const challengeId = requiredString(data.challengeId, "Challenge", 120);
    const submissionId = requiredString(data.submissionId, "Submission", 120);
    if (typeof data.approve !== "boolean") {
      throw new HttpsError("invalid-argument", "The review decision is invalid.");
    }
    const database = getFirestore();
    const challenge = await database.collection(collections.challenges).doc(challengeId).get();
    if (!challenge.exists) {
      throw new HttpsError("not-found", "This challenge is unavailable.");
    }
    const manager = challenge.get("creatorId") === reviewerId ||
      request.auth?.token.admin === true ||
      (typeof challenge.get("communityId") === "string" &&
        await isCommunityManager(database, String(challenge.get("communityId")), reviewerId));
    if (!manager) {
      throw new HttpsError("permission-denied", "Challenge reviewer access is required.");
    }
    const submissionRef = challenge.ref.collection("submissions").doc(submissionId);
    const submission = await submissionRef.get();
    if (!submission.exists || !["pending", "flagged"].includes(String(submission.get("status")))) {
      throw new HttpsError("failed-precondition", "This submission is no longer pending.");
    }
    const userId = String(submission.get("userId"));
    if (!data.approve) {
      await submissionRef.update({
        status: "rejected",
        reviewedBy: reviewerId,
        reviewedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    } else {
      const profile = await activeProfileSnapshot(database, userId);
      await applyVerifiedProgress({
        database,
        challenge,
        participantRef: challenge.ref.collection("participants").doc(userId),
        progressDelta: Number(submission.get("progressDelta") ?? 0),
        submissionRef,
        activityId: typeof submission.get("activityId") === "string" ?
          String(submission.get("activityId")) : undefined,
        uid: userId,
        profile,
      });
      await submissionRef.update({reviewedBy: reviewerId});
    }
    await writeAuditEvent({
      actorId: reviewerId,
      action: data.approve ?
        "challenges.submission_approved" : "challenges.submission_rejected",
      targetType: "challenge_submission",
      targetId: submissionId,
      metadata: {challengeId},
    });
    return {ok: true};
  },
);

export const getChallengeProofReviewUrl = onCall(
  callableOptions,
  async (request) => {
    const reviewerId = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const challengeId = requiredString(data.challengeId, "Challenge", 120);
    const submissionId = requiredString(data.submissionId, "Submission", 120);
    await consumeRateLimit(reviewerId, {
      key: "challenge_proof_review_url",
      maxAttempts: 120,
      windowSeconds: 60 * 60,
    });
    const database = getFirestore();
    const challenge = await database.collection(collections.challenges).doc(challengeId).get();
    if (!challenge.exists) {
      throw new HttpsError("not-found", "This challenge is unavailable.");
    }
    const manager = challenge.get("creatorId") === reviewerId ||
      request.auth?.token.admin === true ||
      (typeof challenge.get("communityId") === "string" &&
        await isCommunityManager(
          database,
          String(challenge.get("communityId")),
          reviewerId,
        ));
    if (!manager) {
      throw new HttpsError(
        "permission-denied",
        "Challenge reviewer access is required.",
      );
    }
    const submission = await challenge.ref.collection("submissions").doc(submissionId).get();
    if (!submission.exists) {
      throw new HttpsError("not-found", "This submission is unavailable.");
    }
    const proofStoragePath = submission.get("proofStoragePath");
    const participantId = submission.get("userId");
    if (typeof proofStoragePath !== "string" ||
        typeof participantId !== "string" ||
        !proofStoragePath.startsWith(
          `challenge_proofs/${participantId}/${challengeId}/`,
        )) {
      throw new HttpsError("not-found", "This submission has no reviewable proof.");
    }
    const file = getStorage().bucket().file(proofStoragePath);
    const [metadata] = await file.getMetadata();
    const custom = metadata.metadata ?? {};
    if (custom.ownerId !== participantId || custom.challengeId !== challengeId ||
        custom.schemaVersion !== "1") {
      throw new HttpsError("failed-precondition", "The proof metadata is invalid.");
    }
    const expiresAt = Date.now() + 5 * 60 * 1000;
    const [url] = await file.getSignedUrl({
      action: "read",
      version: "v4",
      expires: expiresAt,
    });
    await writeAuditEvent({
      actorId: reviewerId,
      action: "challenges.proof_viewed",
      targetType: "challenge_submission",
      targetId: submissionId,
      metadata: {challengeId},
    });
    return {url, expiresAt: new Date(expiresAt).toISOString()};
  },
);

export const setChallengeReminder = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const challengeId = requiredString(data.challengeId, "Challenge", 120);
  if (typeof data.enabled !== "boolean") {
    throw new HttpsError("invalid-argument", "Reminder preference is invalid.");
  }
  const database = getFirestore();
  const participantRef = database
    .doc(`${collections.challenges}/${challengeId}/participants/${uid}`);
  const participant = await participantRef.get();
  if (!participant.exists || participant.get("status") === "withdrawn") {
    throw new HttpsError("failed-precondition", "Join the challenge first.");
  }
  await participantRef.update({
    reminderEnabled: data.enabled,
    updatedAt: Timestamp.now(),
  });
  return {ok: true};
});

export const claimChallengeRewards = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const challengeId = requiredString(data.challengeId, "Challenge", 120);
  await consumeRateLimit(uid, {
    key: "claim_challenge_reward",
    maxAttempts: 20,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const challengeRef = database.collection(collections.challenges).doc(challengeId);
  const participantRef = challengeRef.collection("participants").doc(uid);
  const [challenge, participant] = await Promise.all([
    challengeRef.get(),
    participantRef.get(),
  ]);
  if (!challenge.exists || !participant.exists ||
      participant.get("status") !== "completed") {
    throw new HttpsError(
      "failed-precondition",
      "Complete the verified challenge before claiming rewards.",
    );
  }
  const now = Timestamp.now();
  const badgeId = challenge.get("badgeId");
  const badge = typeof badgeId === "string" && badgeId.length > 0 ?
    await database.collection(collections.challengeBadges).doc(badgeId).get() : null;
  const rewardIds = Array.isArray(challenge.get("rewardIds")) ?
    (challenge.get("rewardIds") as unknown[])
      .filter((item): item is string => typeof item === "string") : [];
  const rewardDocuments = await Promise.all(
    rewardIds.map((rewardId) =>
      database.collection(collections.challengeRewards).doc(rewardId).get(),
    ),
  );
  let alreadyClaimed = false;
  await database.runTransaction(async (transaction) => {
    const latestParticipant = await transaction.get(participantRef);
    if (!latestParticipant.exists || latestParticipant.get("status") !== "completed") {
      throw new HttpsError(
        "failed-precondition",
        "Complete the verified challenge before claiming rewards.",
      );
    }
    if (latestParticipant.get("rewardsClaimedAt") instanceof Timestamp) {
      alreadyClaimed = true;
      return;
    }
    if (badge?.exists) {
      transaction.set(database.doc(`users/${uid}/challenge_badges/${badge.id}`), {
        badge: {id: badge.id, ...badge.data()},
        challengeId,
        earnedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: false});
    }
    for (const reward of rewardDocuments) {
      const expiresAt = reward.get("expiresAt");
      const active = reward.exists && reward.get("isActive") === true &&
        (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() > now.toMillis());
      if (!active) continue;
      transaction.set(
        database.collection(collections.rewardClaims).doc(`${uid}--${reward.id}`),
        {
          userId: uid,
          rewardId: reward.id,
          reward: {id: reward.id, ...reward.data()},
          challengeId,
          status: "claimed",
          claimedAt: now,
          createdAt: now,
          updatedAt: now,
          schemaVersion: currentSchemaVersion,
        },
        {merge: false},
      );
    }
    transaction.update(participantRef, {rewardsClaimedAt: now, updatedAt: now});
  });
  await writeAuditEvent({
    actorId: uid,
    action: "challenges.rewards_claimed",
    targetType: "challenge",
    targetId: challengeId,
  });
  return {ok: true, alreadyClaimed};
});
