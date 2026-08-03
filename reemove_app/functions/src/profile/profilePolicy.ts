import {
  GeoPoint,
  Timestamp,
  type DocumentData,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {normalizeUsername, validateUsername} from "../account/usernamePolicy";

export type ProfileAudience = "everyone" | "followers" | "noOne";
export type FollowApprovalPolicy = "automatic" | "approvalRequired";
export type FollowerListAudience = "everyone" | "followers" | "owner";

export interface ProfilePrivacyInput {
  followApprovalPolicy: FollowApprovalPolicy;
  messageAudience: ProfileAudience;
  messageRequestAudience: ProfileAudience;
  mentionAudience: ProfileAudience;
  tagAudience: ProfileAudience;
  showActivityStatus: boolean;
  showSportLevels: boolean;
  showGoals: boolean;
  showLocation: boolean;
  followerListAudience: FollowerListAudience;
  showFollowerLists: boolean;
  hideLikeCounts: boolean;
  discoverableByUsername: boolean;
  personalizedSuggestions: boolean;
}

export interface ProfessionalProfileInput {
  headline?: string;
  organization?: string;
  positionOrCategory?: string;
  yearsExperience?: number;
  specialties: string[];
  acceptingClients: boolean;
}

export interface ProfileUpdateInput {
  displayName: string;
  username?: string;
  usernameNormalized?: string;
  bio: string;
  avatarUrl?: string;
  avatarStoragePath?: string;
  coverUrl?: string;
  coverStoragePath?: string;
  websiteUrl?: string;
  primarySportId?: string;
  favoriteSportIds: string[];
  goals: string[];
  visibility: "public" | "followers" | "private";
  professionalDetails: ProfessionalProfileInput;
  privacy: ProfilePrivacyInput;
}

export function recordValue(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  return value as Record<string, unknown>;
}

export function safeString(
  value: unknown,
  field: string,
  maximum: number,
  minimum = 0,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be between ${minimum} and ${maximum} characters.`,
    );
  }
  return normalized;
}

export function optionalString(
  value: unknown,
  field: string,
  maximum: number,
): string | undefined {
  if (value === null || value === undefined || value === "") return undefined;
  return safeString(value, field, maximum, 1);
}

function stringArray(
  value: unknown,
  field: string,
  maximumItems: number,
  maximumLength: number,
): string[] {
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  if (value.length > maximumItems) {
    throw new HttpsError(
      "invalid-argument",
      `${field} contains too many items.`,
    );
  }
  const items = value.map((item) => safeString(
    item,
    field,
    maximumLength,
    1,
  ));
  return [...new Set(items)];
}

function booleanValue(
  value: unknown,
  field: string,
  fallback: boolean,
): boolean {
  if (value === undefined) return fallback;
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}

function followerListAudienceValue(
  data: Record<string, unknown>,
): FollowerListAudience {
  const raw = data.followerListAudience;
  if (raw === "everyone" || raw === "followers" || raw === "owner") {
    return raw;
  }
  return booleanValue(
    data.showFollowerLists,
    "Follower-list visibility",
    true,
  ) ? "everyone" : "owner";
}

function audience(value: unknown, field: string): ProfileAudience {
  if (value === "everyone" || value === "followers" || value === "noOne") {
    return value;
  }
  throw new HttpsError("invalid-argument", `${field} is invalid.`);
}

export function parsePrivacy(value: unknown): ProfilePrivacyInput {
  const data = recordValue(value ?? {});
  const followApprovalPolicy = data.followApprovalPolicy === undefined ?
    "automatic" : data.followApprovalPolicy;
  if (followApprovalPolicy !== "automatic" &&
      followApprovalPolicy !== "approvalRequired") {
    throw new HttpsError(
      "invalid-argument",
      "Follow approval policy is invalid.",
    );
  }
  return {
    followApprovalPolicy,
    messageAudience: audience(
      data.messageAudience ?? "everyone",
      "Message audience",
    ),
    messageRequestAudience: audience(
      data.messageRequestAudience ?? "noOne",
      "Message request audience",
    ),
    mentionAudience: audience(
      data.mentionAudience ?? "everyone",
      "Mention audience",
    ),
    tagAudience: audience(data.tagAudience ?? "followers", "Tag audience"),
    showActivityStatus: booleanValue(
      data.showActivityStatus,
      "Activity visibility",
      true,
    ),
    showSportLevels: booleanValue(
      data.showSportLevels,
      "Sport-level visibility",
      true,
    ),
    showGoals: booleanValue(data.showGoals, "Goal visibility", true),
    showLocation: booleanValue(
      data.showLocation,
      "Location visibility",
      true,
    ),
    followerListAudience: followerListAudienceValue(data),
    showFollowerLists: followerListAudienceValue(data) !== "owner",
    hideLikeCounts: booleanValue(
      data.hideLikeCounts,
      "Like-count visibility",
      false,
    ),
    discoverableByUsername: booleanValue(
      data.discoverableByUsername,
      "Username discovery",
      true,
    ),
    personalizedSuggestions: booleanValue(
      data.personalizedSuggestions,
      "Personalized suggestions",
      true,
    ),
  };
}

function parseProfessional(value: unknown): ProfessionalProfileInput {
  const data = value === null || value === undefined ? {} : recordValue(value);
  const years = data.yearsExperience;
  if (years !== undefined &&
      (typeof years !== "number" || !Number.isInteger(years) ||
       years < 0 || years > 80)) {
    throw new HttpsError(
      "invalid-argument",
      "Years of experience is invalid.",
    );
  }
  return {
    headline: optionalString(data.headline, "Headline", 120),
    organization: optionalString(data.organization, "Organization", 120),
    positionOrCategory: optionalString(
      data.positionOrCategory,
      "Position or category",
      100,
    ),
    yearsExperience: years as number | undefined,
    specialties: stringArray(
      data.specialties ?? [],
      "Specialties",
      20,
      60,
    ),
    acceptingClients: booleanValue(
      data.acceptingClients,
      "Accepting clients",
      false,
    ),
  };
}

function profileUrl(value: unknown): string | undefined {
  const candidate = optionalString(value, "Website", 300);
  if (!candidate) return undefined;
  let parsed: URL;
  try {
    parsed = new URL(candidate);
  } catch {
    throw new HttpsError("invalid-argument", "Enter a valid website URL.");
  }
  if (parsed.protocol !== "https:") {
    throw new HttpsError("invalid-argument", "Website links must use HTTPS.");
  }
  return parsed.toString();
}

export function parseProfileUpdate(value: unknown): ProfileUpdateInput {
  const data = recordValue(value);
  const visibility = data.visibility;
  if (visibility !== "public" &&
      visibility !== "followers" &&
      visibility !== "private") {
    throw new HttpsError("invalid-argument", "Profile visibility is invalid.");
  }
  const usernameValue = optionalString(data.username, "Username", 30);
  let username: string | undefined;
  let usernameNormalized: string | undefined;
  if (usernameValue) {
    username = usernameValue;
    usernameNormalized = normalizeUsername(usernameValue);
    const problem = validateUsername(usernameNormalized);
    if (problem) throw new HttpsError("invalid-argument", problem);
  }
  const favoriteSportIds = stringArray(
    data.favoriteSportIds ?? [],
    "Favorite sports",
    20,
    80,
  );
  const primarySportId = optionalString(
    data.primarySportId,
    "Primary sport",
    80,
  );
  if (primarySportId && !favoriteSportIds.includes(primarySportId)) {
    throw new HttpsError(
      "invalid-argument",
      "The primary sport must be one of your favorite sports.",
    );
  }
  return {
    displayName: safeString(data.displayName, "Display name", 80, 1),
    username,
    usernameNormalized,
    bio: safeString(data.bio ?? "", "Bio", 500),
    avatarUrl: optionalString(data.avatarUrl, "Avatar URL", 2000),
    avatarStoragePath: optionalString(
      data.avatarStoragePath,
      "Avatar storage path",
      500,
    ),
    coverUrl: optionalString(data.coverUrl, "Cover URL", 2000),
    coverStoragePath: optionalString(
      data.coverStoragePath,
      "Cover storage path",
      500,
    ),
    websiteUrl: profileUrl(data.websiteUrl),
    primarySportId,
    favoriteSportIds,
    goals: stringArray(data.goals ?? [], "Goals", 20, 100),
    visibility,
    professionalDetails: parseProfessional(data.professionalDetails),
    privacy: parsePrivacy(data.privacy),
  };
}

function serialize(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof GeoPoint) {
    return {latitude: value.latitude, longitude: value.longitude};
  }
  if (Array.isArray(value)) return value.map(serialize);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .map(([key, item]) => [key, serialize(item)]),
    );
  }
  return value;
}

export function callableDocument(
  snapshot: DocumentSnapshot<DocumentData>,
): Record<string, unknown> {
  return {
    id: snapshot.id,
    ...serialize(snapshot.data() ?? {}) as Record<string, unknown>,
  };
}

export function callableProfile(
  snapshot: DocumentSnapshot<DocumentData>,
): Record<string, unknown> {
  const data = callableDocument(snapshot);
  data.uid = snapshot.id;
  return data;
}

export function sanitizedCallableProfile(
  snapshot: DocumentSnapshot<DocumentData>,
  privacy: Record<string, unknown>,
  isOwner: boolean,
): Record<string, unknown> {
  const profile = callableProfile(snapshot);
  if (isOwner) return profile;

  // Operational discovery fields are never part of another user's response.
  delete profile.discoveryRadiusKm;

  if (privacy.showSportLevels === false) {
    profile.sportLevels = {};
  }
  if (privacy.showGoals === false) {
    profile.goals = [];
  }
  if (privacy.showLocation === false) {
    for (const key of [
      "location",
      "geohash",
      "locality",
      "administrativeArea",
      "countryCode",
    ]) {
      delete profile[key];
    }
  }
  return profile;
}
