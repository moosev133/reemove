import {HttpsError} from "firebase-functions/v2/https";

export const groupPrivacyValues = ["public", "private", "hidden"] as const;
export type GroupPrivacy = typeof groupPrivacyValues[number];

export const groupJoinPolicyValues = [
  "open",
  "approvalRequired",
  "inviteOnly",
] as const;
export type GroupJoinPolicy = typeof groupJoinPolicyValues[number];

export const groupStatusValues = ["active", "archived", "deleted"] as const;
export type GroupStatus = typeof groupStatusValues[number];

export const groupMemberRoles = ["owner", "admin", "member"] as const;
export type GroupMemberRole = typeof groupMemberRoles[number];

export const groupSessionStatuses = [
  "scheduled",
  "cancelled",
  "completed",
] as const;
export type GroupSessionStatus = typeof groupSessionStatuses[number];

export const groupChannelTypes = ["member_chat", "announcements"] as const;
export type GroupChannelType = typeof groupChannelTypes[number];

/** C1 media contracts only — deep view-once behavior is Phase C2. */
export const groupMediaModes = ["normal", "keep_in_chat", "view_once"] as const;
export type GroupMediaMode = typeof groupMediaModes[number];

export type GroupLocationInput = {
  locality?: string;
  administrativeArea?: string;
  countryCode?: string;
  text?: string;
};

export type CreateGroupInput = {
  name: string;
  description: string;
  category: string;
  privacy: GroupPrivacy;
  joinPolicy: GroupJoinPolicy;
  location: GroupLocationInput;
  capacity: number;
  avatarUrl?: string;
  coverUrl?: string;
};

export type UpdateGroupInput = {
  groupId: string;
  name?: string;
  description?: string;
  category?: string;
  privacy?: GroupPrivacy;
  joinPolicy?: GroupJoinPolicy;
  location?: GroupLocationInput;
  capacity?: number;
  avatarUrl?: string | null;
  coverUrl?: string | null;
  status?: Exclude<GroupStatus, "deleted">;
};

export type CreateSessionInput = {
  groupId: string;
  title: string;
  activity: string;
  startAt: Date;
  endAt: Date;
  description: string;
  capacity: number;
  location: GroupLocationInput;
};

export function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

export function requiredString(
  value: unknown,
  label: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is required.`);
  }
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return trimmed;
}

export function optionalString(
  value: unknown,
  label: string,
  maxLength: number,
): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return trimmed;
}

export function optionalUrl(
  value: unknown,
  label: string,
): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string" || value.length > 2048) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const trimmed = value.trim();
  if (!/^https:\/\//i.test(trimmed)) {
    throw new HttpsError("invalid-argument", `${label} must be an https URL.`);
  }
  return trimmed;
}

function parsePrivacy(value: unknown): GroupPrivacy {
  if (typeof value !== "string" ||
      !(groupPrivacyValues as readonly string[]).includes(value)) {
    throw new HttpsError("invalid-argument", "privacy is invalid.");
  }
  return value as GroupPrivacy;
}

function parseJoinPolicy(value: unknown): GroupJoinPolicy {
  if (typeof value !== "string" ||
      !(groupJoinPolicyValues as readonly string[]).includes(value)) {
    throw new HttpsError("invalid-argument", "joinPolicy is invalid.");
  }
  return value as GroupJoinPolicy;
}

export function normalizeJoinPolicy(
  privacy: GroupPrivacy,
  joinPolicy: GroupJoinPolicy,
): GroupJoinPolicy {
  if (privacy === "hidden") return "inviteOnly";
  if (privacy === "private" && joinPolicy === "open") {
    return "approvalRequired";
  }
  return joinPolicy;
}

function parseLocation(value: unknown): GroupLocationInput {
  const data = asRecord(value);
  const location: GroupLocationInput = {};
  if (data.locality !== undefined) {
    location.locality = requiredString(data.locality, "locality", 80);
  }
  if (data.administrativeArea !== undefined) {
    location.administrativeArea = requiredString(
      data.administrativeArea,
      "administrativeArea",
      80,
    );
  }
  if (data.countryCode !== undefined) {
    const code = requiredString(data.countryCode, "countryCode", 2).toUpperCase();
    if (!/^[A-Z]{2}$/.test(code)) {
      throw new HttpsError("invalid-argument", "countryCode is invalid.");
    }
    location.countryCode = code;
  }
  if (data.text !== undefined) {
    location.text = requiredString(data.text, "location text", 200);
  }
  return location;
}

function parseCapacity(value: unknown, fallback = 0): number {
  if (value === undefined || value === null) return fallback;
  if (typeof value !== "number" || !Number.isInteger(value) ||
      value < 0 || value > 10000) {
    throw new HttpsError("invalid-argument", "capacity is invalid.");
  }
  return value;
}

export function parseCreateGroupInput(data: unknown): CreateGroupInput {
  const body = asRecord(data);
  const privacy = parsePrivacy(body.privacy ?? "public");
  const joinPolicy = normalizeJoinPolicy(
    privacy,
    parseJoinPolicy(body.joinPolicy ?? (
      privacy === "public" ? "open" : "approvalRequired"
    )),
  );
  return {
    name: requiredString(body.name, "name", 80),
    description: requiredString(body.description, "description", 2000),
    category: requiredString(body.category, "category", 64),
    privacy,
    joinPolicy,
    location: parseLocation(body.location),
    capacity: parseCapacity(body.capacity, 0),
    avatarUrl: optionalUrl(body.avatarUrl, "avatarUrl"),
    coverUrl: optionalUrl(body.coverUrl, "coverUrl"),
  };
}

export function parseUpdateGroupInput(data: unknown): UpdateGroupInput {
  const body = asRecord(data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const patch: UpdateGroupInput = {groupId};
  if (body.name !== undefined) {
    patch.name = requiredString(body.name, "name", 80);
  }
  if (body.description !== undefined) {
    patch.description = requiredString(body.description, "description", 2000);
  }
  if (body.category !== undefined) {
    patch.category = requiredString(body.category, "category", 64);
  }
  if (body.privacy !== undefined) {
    patch.privacy = parsePrivacy(body.privacy);
  }
  if (body.joinPolicy !== undefined) {
    patch.joinPolicy = parseJoinPolicy(body.joinPolicy);
  }
  if (body.location !== undefined) {
    patch.location = parseLocation(body.location);
  }
  if (body.capacity !== undefined) {
    patch.capacity = parseCapacity(body.capacity);
  }
  if (body.avatarUrl !== undefined) {
    patch.avatarUrl = body.avatarUrl === null ?
      null :
      optionalUrl(body.avatarUrl, "avatarUrl") ?? null;
  }
  if (body.coverUrl !== undefined) {
    patch.coverUrl = body.coverUrl === null ?
      null :
      optionalUrl(body.coverUrl, "coverUrl") ?? null;
  }
  if (body.status !== undefined) {
    if (body.status !== "active" && body.status !== "archived") {
      throw new HttpsError("invalid-argument", "status is invalid.");
    }
    patch.status = body.status;
  }
  const keys = Object.keys(patch).filter((key) => key !== "groupId");
  if (keys.length === 0) {
    throw new HttpsError("invalid-argument", "No group updates provided.");
  }
  return patch;
}

export function parseCreateSessionInput(data: unknown): CreateSessionInput {
  const body = asRecord(data);
  const startAt = parseIsoDate(body.startAt, "startAt");
  const endAt = parseIsoDate(body.endAt, "endAt");
  if (endAt.getTime() <= startAt.getTime()) {
    throw new HttpsError("invalid-argument", "endAt must be after startAt.");
  }
  return {
    groupId: requiredString(body.groupId, "groupId", 128),
    title: requiredString(body.title, "title", 120),
    activity: requiredString(body.activity, "activity", 64),
    startAt,
    endAt,
    description: optionalString(body.description, "description", 2000),
    capacity: parseCapacity(body.capacity, 0),
    location: parseLocation(body.location),
  };
}

export function parseIsoDate(value: unknown, label: string): Date {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpsError("invalid-argument", `${label} is required.`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return date;
}

export function parseDecision(data: unknown): "accept" | "decline" {
  const body = asRecord(data);
  if (body.decision !== "accept" && body.decision !== "decline") {
    throw new HttpsError(
      "invalid-argument",
      "decision must be accept or decline.",
    );
  }
  return body.decision;
}

export function isManagerRole(role: string): boolean {
  return role === "owner" || role === "admin";
}

export function canRemoveMember(
  actorRole: GroupMemberRole,
  targetRole: GroupMemberRole,
): boolean {
  if (targetRole === "owner") return false;
  if (actorRole === "owner") return targetRole === "admin" || targetRole === "member";
  if (actorRole === "admin") return targetRole === "member";
  return false;
}

export function nextMemberCount(current: number, delta: number): number {
  return Math.max(0, current + delta);
}

export function groupChannelContracts(): Array<{
  type: GroupChannelType;
  supportedMediaModes: GroupMediaMode[];
  publishRoles: GroupMemberRole[];
  readRoles: GroupMemberRole[];
}> {
  return [
    {
      type: "member_chat",
      supportedMediaModes: [...groupMediaModes],
      publishRoles: ["owner", "admin", "member"],
      readRoles: ["owner", "admin", "member"],
    },
    {
      type: "announcements",
      supportedMediaModes: ["normal", "keep_in_chat"],
      publishRoles: ["owner", "admin"],
      readRoles: ["owner", "admin", "member"],
    },
  ];
}
