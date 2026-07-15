export const onboardingVersion = 1;
export const defaultMinimumAge = 13;
export const defaultMaximumAge = 120;

export const onboardingSteps = [
  "profile",
  "birthday",
  "sports",
  "levels",
  "goals",
  "location",
  "discovery",
  "accessibility",
  "notifications",
  "review",
] as const;

export const sportLevels = [
  "beginner",
  "intermediate",
  "advanced",
  "professional",
] as const;

export const goalIds = [
  "stay_active",
  "build_strength",
  "improve_endurance",
  "lose_weight_safely",
  "gain_muscle",
  "learn_a_sport",
  "find_training_partners",
  "join_matches",
  "prepare_for_competition",
  "improve_wellbeing",
] as const;

export const permissionStates = [
  "notAsked",
  "granted",
  "denied",
  "deniedForever",
  "unavailable",
] as const;

export const notificationPermissionStates = [
  "notAsked",
  "authorized",
  "provisional",
  "denied",
  "unavailable",
] as const;

export const profileVisibilities = ["public", "followers", "private"] as const;

export type OnboardingStep = typeof onboardingSteps[number];
export type SportLevel = typeof sportLevels[number];
export type PermissionState = typeof permissionStates[number];
export type NotificationPermissionState = typeof notificationPermissionStates[number];
export type ProfileVisibility = typeof profileVisibilities[number];

export function calculateAge(
  dateOfBirth: string,
  now: Date = new Date(),
): number {
  const [year, month, day] = dateOfBirth.split("-").map(Number);
  if (!year || !month || !day) return -1;

  let age = now.getUTCFullYear() - year;
  const monthDifference = now.getUTCMonth() + 1 - month;
  if (monthDifference < 0 || (monthDifference === 0 && now.getUTCDate() < day)) {
    age -= 1;
  }
  return age;
}

export function isValidIsoBirthDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

export function validateAge(
  dateOfBirth: string,
  minimumAge = defaultMinimumAge,
  maximumAge = defaultMaximumAge,
  now: Date = new Date(),
): string | null {
  if (!isValidIsoBirthDate(dateOfBirth)) {
    return "Enter a valid birthday.";
  }
  const age = calculateAge(dateOfBirth, now);
  if (age < minimumAge) {
    return `You must be at least ${minimumAge} years old to use ReeMove.`;
  }
  if (age > maximumAge) {
    return "Enter a valid birthday.";
  }
  return null;
}

export function ageBandFor(age: number): string {
  if (age < 18) return "minor";
  if (age < 25) return "18_24";
  if (age < 35) return "25_34";
  if (age < 45) return "35_44";
  if (age < 55) return "45_54";
  return "55_plus";
}

export function isStringRecord(value: unknown): value is Record<string, string> {
  if (!isRecord(value)) return false;
  return Object.values(value).every((item) => typeof item === "string");
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function uniqueStrings(values: readonly string[]): string[] {
  return [...new Set(values)];
}
