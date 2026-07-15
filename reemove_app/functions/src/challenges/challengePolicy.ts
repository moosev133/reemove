import {HttpsError} from "firebase-functions/v2/https";

export const challengeMetrics = [
  "distance",
  "duration",
  "sessions",
  "repetitions",
  "volume",
  "attendance",
  "points",
] as const;
export const challengeDifficulties = ["beginner", "intermediate", "advanced"] as const;
export const challengeVerificationMethods = [
  "automaticActivity",
  "activityAndProof",
  "photoProof",
  "organizerReview",
] as const;

export type ChallengeMetric = typeof challengeMetrics[number];
export type ChallengeDifficulty = typeof challengeDifficulties[number];
export type ChallengeVerificationMethod = typeof challengeVerificationMethods[number];

export type ChallengeInput = {
  sportId: string;
  title: string;
  description: string;
  difficulty: ChallengeDifficulty;
  startsAt: Date;
  endsAt: Date;
  metric: ChallengeMetric;
  target: number;
  unit: string;
  verificationMethod: ChallengeVerificationMethod;
  maximumDailyProgress: number;
  minimumAge: number;
  requiresRestDays: boolean;
  maximumEffortMinutesPerDay: number;
  communityId?: string;
};

const unsafeLanguage = [
  "ignore pain",
  "no sleep",
  "starve",
  "dehydrate",
  "dangerous stunt",
  "use substances",
  "injure yourself",
];

const metricUnits: Record<ChallengeMetric, readonly string[]> = {
  distance: ["km"],
  duration: ["minutes"],
  sessions: ["sessions"],
  repetitions: ["reps"],
  volume: ["kg"],
  attendance: ["sessions"],
  points: ["points"],
};

const absoluteTargetCaps: Record<ChallengeMetric, number> = {
  distance: 500,
  duration: 10_000,
  sessions: 100,
  repetitions: 20_000,
  volume: 2_000_000,
  attendance: 100,
  points: 100_000,
};

const absoluteDailyCaps: Record<ChallengeMetric, number> = {
  distance: 50,
  duration: 240,
  sessions: 3,
  repetitions: 2_000,
  volume: 250_000,
  attendance: 3,
  points: 10_000,
};

export function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The challenge request is invalid.");
  }
  return value as Record<string, unknown>;
}

function text(value: unknown, label: string, minimum: number, maximum: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be between ${minimum} and ${maximum} characters.`,
    );
  }
  return normalized;
}

function optionalText(value: unknown, label: string, maximum: number): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  return text(value, label, 1, maximum);
}

function enumValue<T extends readonly string[]>(
  value: unknown,
  label: string,
  options: T,
): T[number] {
  if (typeof value === "string" && options.includes(value)) {
    return value as T[number];
  }
  throw new HttpsError("invalid-argument", `${label} is invalid.`);
}

function finiteNumber(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return value;
}

function boundedInteger(value: unknown, label: string, minimum: number, maximum: number): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < minimum || value > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

function dateValue(value: unknown, label: string): Date {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return parsed;
}

export function containsUnsafeChallengeLanguage(...values: string[]): boolean {
  const combined = values.join(" ").toLowerCase();
  return unsafeLanguage.some((phrase) => combined.includes(phrase));
}

export function validateChallengeTarget(input: Pick<
  ChallengeInput,
  "metric" | "target" | "unit" | "maximumDailyProgress" | "maximumEffortMinutesPerDay"
>): void {
  if (!metricUnits[input.metric].includes(input.unit)) {
    throw new HttpsError("invalid-argument", "The unit does not match the selected metric.");
  }
  if (input.target <= 0 || input.target > absoluteTargetCaps[input.metric]) {
    throw new HttpsError("invalid-argument", "The challenge target is outside the safe range.");
  }
  if (input.maximumDailyProgress <= 0 ||
      input.maximumDailyProgress > absoluteDailyCaps[input.metric] ||
      input.maximumDailyProgress > input.target) {
    throw new HttpsError("invalid-argument", "The daily progress cap is outside the safe range.");
  }
  if (input.maximumEffortMinutesPerDay < 10 || input.maximumEffortMinutesPerDay > 240) {
    throw new HttpsError("invalid-argument", "The daily effort limit is outside the safe range.");
  }
}

export function parseChallengeInput(value: unknown, now = new Date()): ChallengeInput {
  const data = asRecord(value);
  const metric = enumValue(data.metric, "Metric", challengeMetrics);
  const target = finiteNumber(data.target, "Target");
  const maximumDailyProgress = finiteNumber(data.maximumDailyProgress, "Daily cap");
  const startsAt = dateValue(data.startsAt, "Start time");
  const endsAt = dateValue(data.endsAt, "End time");
  const title = text(data.title, "Title", 4, 80);
  const description = text(data.description, "Description", 12, 600);
  const unit = text(data.unit, "Unit", 1, 20).toLowerCase();
  const maximumEffortMinutesPerDay = boundedInteger(
    data.maximumEffortMinutesPerDay,
    "Daily effort limit",
    10,
    240,
  );
  const input: ChallengeInput = {
    sportId: text(data.sportId, "Sport", 1, 40),
    title,
    description,
    difficulty: enumValue(data.difficulty, "Difficulty", challengeDifficulties),
    startsAt,
    endsAt,
    metric,
    target,
    unit,
    verificationMethod: enumValue(
      data.verificationMethod,
      "Verification method",
      challengeVerificationMethods,
    ),
    maximumDailyProgress,
    minimumAge: boundedInteger(data.minimumAge, "Minimum age", 14, 50),
    requiresRestDays: data.requiresRestDays !== false,
    maximumEffortMinutesPerDay,
    communityId: optionalText(data.communityId, "Community", 120),
  };
  if (startsAt.getTime() < now.getTime() - 5 * 60 * 1000) {
    throw new HttpsError("invalid-argument", "The challenge cannot start in the past.");
  }
  const durationMs = endsAt.getTime() - startsAt.getTime();
  if (durationMs < 60 * 60 * 1000 || durationMs > 31 * 24 * 60 * 60 * 1000) {
    throw new HttpsError(
      "invalid-argument",
      "Challenges must run between one hour and 31 days.",
    );
  }
  if (containsUnsafeChallengeLanguage(title, description)) {
    throw new HttpsError(
      "invalid-argument",
      "The challenge description conflicts with ReeMove safety rules.",
    );
  }
  validateChallengeTarget(input);
  return input;
}

export function calculateAge(dateOfBirth: string, now = new Date()): number {
  const parts = dateOfBirth.split("-").map(Number);
  if (parts.length !== 3 || parts.some((part) => !Number.isFinite(part))) return -1;
  const [year, month, day] = parts;
  let age = now.getUTCFullYear() - year;
  const birthdayPassed = now.getUTCMonth() + 1 > month ||
    (now.getUTCMonth() + 1 === month && now.getUTCDate() >= day);
  if (!birthdayPassed) age -= 1;
  return age;
}

export function progressPercent(progress: number, target: number): number {
  if (target <= 0) return 0;
  return Math.min(100, Math.max(0, Math.round((progress / target) * 10_000) / 100));
}
