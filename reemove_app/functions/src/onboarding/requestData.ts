import {HttpsError} from "firebase-functions/v2/https";

import {
  goalIds,
  isRecord,
  notificationPermissionStates,
  onboardingSteps,
  onboardingVersion,
  permissionStates,
  profileVisibilities,
  sportLevels,
  uniqueStrings,
  type NotificationPermissionState,
  type OnboardingStep,
  type PermissionState,
  type ProfileVisibility,
  type SportLevel,
} from "./onboardingPolicy";

export type OnboardingLocation = {
  latitude: number;
  longitude: number;
  locality?: string;
  administrativeArea?: string;
  countryCode?: string;
};

export type DiscoveryPreferences = {
  radiusKm: number;
  showNearbyPeople: boolean;
  recommendEvents: boolean;
  allowTrainerDiscovery: boolean;
  visibility: ProfileVisibility;
};

export type AccessibilityPreferences = {
  reduceMotion: boolean;
  highContrast: boolean;
  largeText: boolean;
  screenReaderOptimized: boolean;
};

export type NotificationPreferences = {
  masterEnabled: boolean;
  activity: boolean;
  messages: boolean;
  events: boolean;
  challenges: boolean;
  productUpdates: boolean;
  permissionStatus: NotificationPermissionState;
};

export type OnboardingDraftData = {
  version: number;
  currentStep: OnboardingStep;
  dateOfBirth: string | null;
  avatarUrl: string | null;
  avatarStoragePath: string | null;
  favoriteSportIds: string[];
  sportLevels: Record<string, SportLevel>;
  goals: string[];
  location: OnboardingLocation | null;
  locationPermission: PermissionState;
  discovery: DiscoveryPreferences;
  accessibility: AccessibilityPreferences;
  notifications: NotificationPreferences;
};

function invalid(message: string): never {
  throw new HttpsError("invalid-argument", message);
}

function nullableString(value: unknown, field: string, maxLength: number): string | null {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value !== "string") invalid(`${field} must be a string.`);
  const normalized = value.trim();
  if (normalized.length > maxLength) invalid(`${field} is too long.`);
  return normalized;
}

function booleanField(record: Record<string, unknown>, field: string, fallback: boolean): boolean {
  const value = record[field];
  if (value === undefined) return fallback;
  if (typeof value !== "boolean") invalid(`${field} must be a boolean.`);
  return value;
}

function stringArray(value: unknown, field: string, maximum: number): string[] {
  if (!Array.isArray(value)) invalid(`${field} must be a list.`);
  const strings = value.map((item) => {
    if (typeof item !== "string") invalid(`${field} contains an invalid value.`);
    const normalized = item.trim();
    if (normalized.length === 0 || normalized.length > 80) {
      invalid(`${field} contains an invalid value.`);
    }
    return normalized;
  });
  const unique = uniqueStrings(strings);
  if (unique.length > maximum) invalid(`${field} has too many values.`);
  return unique;
}

function parseLocation(value: unknown): OnboardingLocation | null {
  if (value === null || value === undefined) return null;
  if (!isRecord(value)) invalid("location must be an object.");
  const latitude = value.latitude;
  const longitude = value.longitude;
  if (typeof latitude !== "number" || latitude < -90 || latitude > 90) {
    invalid("location latitude is invalid.");
  }
  if (typeof longitude !== "number" || longitude < -180 || longitude > 180) {
    invalid("location longitude is invalid.");
  }
  const locality = nullableString(value.locality, "locality", 120);
  const administrativeArea = nullableString(
    value.administrativeArea,
    "administrativeArea",
    120,
  );
  const countryCode = nullableString(value.countryCode, "countryCode", 3)?.toUpperCase();
  return {
    latitude,
    longitude,
    ...(locality ? {locality} : {}),
    ...(administrativeArea ? {administrativeArea} : {}),
    ...(countryCode ? {countryCode} : {}),
  };
}

function parseDiscovery(value: unknown): DiscoveryPreferences {
  if (!isRecord(value)) invalid("discovery must be an object.");
  const radiusKm = value.radiusKm;
  if (typeof radiusKm !== "number" || radiusKm < 1 || radiusKm > 200) {
    invalid("Discovery radius must be between 1 and 200 km.");
  }
  const visibility = value.visibility;
  if (typeof visibility !== "string" ||
      !profileVisibilities.includes(visibility as ProfileVisibility)) {
    invalid("Profile visibility is invalid.");
  }
  return {
    radiusKm,
    showNearbyPeople: booleanField(value, "showNearbyPeople", true),
    recommendEvents: booleanField(value, "recommendEvents", true),
    allowTrainerDiscovery: booleanField(value, "allowTrainerDiscovery", true),
    visibility: visibility as ProfileVisibility,
  };
}

function parseAccessibility(value: unknown): AccessibilityPreferences {
  if (!isRecord(value)) invalid("accessibility must be an object.");
  return {
    reduceMotion: booleanField(value, "reduceMotion", false),
    highContrast: booleanField(value, "highContrast", false),
    largeText: booleanField(value, "largeText", false),
    screenReaderOptimized: booleanField(value, "screenReaderOptimized", false),
  };
}

function parseNotifications(value: unknown): NotificationPreferences {
  if (!isRecord(value)) invalid("notifications must be an object.");
  const permissionStatus = value.permissionStatus;
  if (typeof permissionStatus !== "string" ||
      !notificationPermissionStates.includes(
        permissionStatus as NotificationPermissionState,
      )) {
    invalid("Notification permission status is invalid.");
  }
  return {
    masterEnabled: booleanField(value, "masterEnabled", false),
    activity: booleanField(value, "activity", true),
    messages: booleanField(value, "messages", true),
    events: booleanField(value, "events", true),
    challenges: booleanField(value, "challenges", true),
    productUpdates: booleanField(value, "productUpdates", false),
    permissionStatus: permissionStatus as NotificationPermissionState,
  };
}

export function parseOnboardingDraft(input: unknown): OnboardingDraftData {
  if (!isRecord(input)) invalid("Onboarding data is required.");
  const version = input.version;
  if (version !== onboardingVersion) {
    invalid("This onboarding version is no longer supported. Restart onboarding.");
  }
  const currentStep = input.currentStep;
  if (typeof currentStep !== "string" ||
      !onboardingSteps.includes(currentStep as OnboardingStep)) {
    invalid("Onboarding step is invalid.");
  }
  const dateOfBirth = nullableString(input.dateOfBirth, "dateOfBirth", 10);
  const avatarUrl = nullableString(input.avatarUrl, "avatarUrl", 2000);
  const avatarStoragePath = nullableString(
    input.avatarStoragePath,
    "avatarStoragePath",
    500,
  );
  const favoriteSportIds = stringArray(
    input.favoriteSportIds ?? [],
    "favoriteSportIds",
    8,
  );
  const rawLevels = input.sportLevels ?? {};
  if (!isRecord(rawLevels)) invalid("sportLevels must be an object.");
  const parsedLevels: Record<string, SportLevel> = {};
  for (const [sportId, level] of Object.entries(rawLevels)) {
    if (sportId.length === 0 || sportId.length > 80 ||
        typeof level !== "string" ||
        !sportLevels.includes(level as SportLevel)) {
      invalid("A sport level is invalid.");
    }
    parsedLevels[sportId] = level as SportLevel;
  }
  const goals = stringArray(input.goals ?? [], "goals", 8);
  for (const goal of goals) {
    if (!goalIds.includes(goal as typeof goalIds[number])) {
      invalid("A selected goal is invalid.");
    }
  }
  const locationPermission = input.locationPermission ?? "notAsked";
  if (typeof locationPermission !== "string" ||
      !permissionStates.includes(locationPermission as PermissionState)) {
    invalid("Location permission status is invalid.");
  }

  return {
    version,
    currentStep: currentStep as OnboardingStep,
    dateOfBirth,
    avatarUrl,
    avatarStoragePath,
    favoriteSportIds,
    sportLevels: parsedLevels,
    goals,
    location: parseLocation(input.location),
    locationPermission: locationPermission as PermissionState,
    discovery: parseDiscovery(input.discovery ?? {
      radiusKm: 25,
      showNearbyPeople: true,
      recommendEvents: true,
      allowTrainerDiscovery: true,
      visibility: "public",
    }),
    accessibility: parseAccessibility(input.accessibility ?? {}),
    notifications: parseNotifications(input.notifications ?? {
      masterEnabled: false,
      permissionStatus: "notAsked",
    }),
  };
}
