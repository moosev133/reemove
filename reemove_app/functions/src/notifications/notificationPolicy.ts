import {HttpsError} from "firebase-functions/v2/https";

export const notificationCategories = [
  "activity",
  "messages",
  "events",
  "challenges",
  "marketplace",
  "system",
  "productUpdates",
] as const;

export type NotificationCategory = typeof notificationCategories[number];

export const notificationKinds = [
  "conversation_message",
  "new_follower",
  "follow_request",
  "follow_request_accepted",
  "message_request",
  "message_request_accepted",
  "post_like",
  "post_comment",
  "post_repost",
  "challenge_submission",
  "challenge_review",
  "challenge_reward",
  "challenge_reminder",
  "event_update",
  "marketplace_update",
  "system_alert",
  "product_update",
] as const;

export type NotificationKind = typeof notificationKinds[number];

export type QuietHours = {
  enabled: boolean;
  startMinutes: number;
  endMinutes: number;
  utcOffsetMinutes: number;
};

export type ParsedNotificationPreferences = {
  masterEnabled: boolean;
  showPreviews: boolean;
  activity: boolean;
  messages: boolean;
  events: boolean;
  challenges: boolean;
  marketplace: boolean;
  system: boolean;
  productUpdates: boolean;
  quietHours: QuietHours;
};

const defaultQuietHours: QuietHours = {
  enabled: false,
  startMinutes: 22 * 60,
  endMinutes: 7 * 60,
  utcOffsetMinutes: 0,
};

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function booleanValue(
  value: unknown,
  fallback: boolean,
): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function integerInRange(
  value: unknown,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  if (typeof value !== "number" || !Number.isInteger(value) ||
      value < minimum || value > maximum) {
    return fallback;
  }
  return value;
}

export function parseStoredNotificationPreferences(
  value: unknown,
): ParsedNotificationPreferences {
  const data = asRecord(value);
  const activity = booleanValue(data.activity, true);
  const quiet = asRecord(data.quietHours);
  return {
    masterEnabled: booleanValue(data.masterEnabled, false),
    showPreviews: booleanValue(data.showPreviews, true),
    activity,
    messages: booleanValue(data.messages, true),
    events: booleanValue(data.events, true),
    challenges: booleanValue(data.challenges, true),
    marketplace: booleanValue(data.marketplace, activity),
    system: booleanValue(data.system, true),
    productUpdates: booleanValue(data.productUpdates, false),
    quietHours: {
      enabled: booleanValue(quiet.enabled, defaultQuietHours.enabled),
      startMinutes: integerInRange(
        quiet.startMinutes,
        defaultQuietHours.startMinutes,
        0,
        1439,
      ),
      endMinutes: integerInRange(
        quiet.endMinutes,
        defaultQuietHours.endMinutes,
        0,
        1439,
      ),
      utcOffsetMinutes: integerInRange(
        quiet.utcOffsetMinutes,
        defaultQuietHours.utcOffsetMinutes,
        -14 * 60,
        14 * 60,
      ),
    },
  };
}

export function parseNotificationPreferencesUpdate(
  value: unknown,
): ParsedNotificationPreferences {
  const data = asRecord(value);
  const requiredBooleans = [
    "masterEnabled",
    "showPreviews",
    "activity",
    "messages",
    "events",
    "challenges",
    "marketplace",
    "system",
    "productUpdates",
  ];
  for (const key of requiredBooleans) {
    if (typeof data[key] !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        `Notification preference ${key} is invalid.`,
      );
    }
  }
  const quiet = asRecord(data.quietHours);
  if (typeof quiet.enabled !== "boolean" ||
      typeof quiet.startMinutes !== "number" ||
      !Number.isInteger(quiet.startMinutes) ||
      quiet.startMinutes < 0 || quiet.startMinutes > 1439 ||
      typeof quiet.endMinutes !== "number" ||
      !Number.isInteger(quiet.endMinutes) ||
      quiet.endMinutes < 0 || quiet.endMinutes > 1439 ||
      typeof quiet.utcOffsetMinutes !== "number" ||
      !Number.isInteger(quiet.utcOffsetMinutes) ||
      quiet.utcOffsetMinutes < -14 * 60 ||
      quiet.utcOffsetMinutes > 14 * 60) {
    throw new HttpsError(
      "invalid-argument",
      "Quiet-hours settings are invalid.",
    );
  }
  return parseStoredNotificationPreferences(data);
}

export function categoryEnabled(
  preferences: ParsedNotificationPreferences,
  category: NotificationCategory,
): boolean {
  if (!preferences.masterEnabled) return false;
  return preferences[category];
}

export function isWithinQuietHours(
  date: Date,
  quietHours: QuietHours,
): boolean {
  if (!quietHours.enabled || quietHours.startMinutes === quietHours.endMinutes) {
    return false;
  }
  const utcMinutes = date.getUTCHours() * 60 + date.getUTCMinutes();
  const localMinutes = ((utcMinutes + quietHours.utcOffsetMinutes) % 1440 +
    1440) % 1440;
  if (quietHours.startMinutes < quietHours.endMinutes) {
    return localMinutes >= quietHours.startMinutes &&
      localMinutes < quietHours.endMinutes;
  }
  return localMinutes >= quietHours.startMinutes ||
    localMinutes < quietHours.endMinutes;
}

export function quietHoursEnd(
  date: Date,
  quietHours: QuietHours,
): Date {
  const utcMilliseconds = date.getTime();
  const local = new Date(
    utcMilliseconds + quietHours.utcOffsetMinutes * 60 * 1000,
  );
  const target = new Date(local);
  target.setUTCHours(
    Math.floor(quietHours.endMinutes / 60),
    quietHours.endMinutes % 60,
    0,
    0,
  );
  if (target.getTime() <= local.getTime()) {
    target.setUTCDate(target.getUTCDate() + 1);
  }
  return new Date(
    target.getTime() - quietHours.utcOffsetMinutes * 60 * 1000,
  );
}

export function boundedPushBody(
  body: string,
  showPreviews: boolean,
): string {
  if (!showPreviews) return "Open ReeMove to view this update.";
  const normalized = body.trim().replace(/\s+/g, " ");
  if (normalized.length <= 160) return normalized;
  return `${normalized.slice(0, 157)}...`;
}

export function notificationBucket(
  date: Date,
  windowHours = 12,
): number {
  return Math.floor(date.getTime() / (windowHours * 60 * 60 * 1000));
}

export function safeNotificationRoute(value: unknown): string {
  if (typeof value !== "string") return "/home/activity";
  const route = value.trim();
  if (!route.startsWith("/") || route.startsWith("//") ||
      route.length > 500 || route.includes("\\")) {
    return "/home/activity";
  }
  return route;
}
