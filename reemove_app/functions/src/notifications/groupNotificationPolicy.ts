import {HttpsError} from "firebase-functions/v2/https";

import {currentSchemaVersion} from "../core/schema";
import type {NotificationKind} from "./notificationPolicy";

export type GroupNotificationCategory =
  | "member_chat"
  | "announcements"
  | "sessions"
  | "invitations";

export type GroupNotificationPreferences = {
  muted: boolean;
  memberChatEnabled: boolean;
  announcementsEnabled: boolean;
  sessionsEnabled: boolean;
  invitationsEnabled: boolean;
  schemaVersion?: number;
};

export function groupNotificationPreferencesDocId(
  groupId: string,
): string {
  // Stored as a single document under `users/{uid}/private/{documentId}` so
  // security rules can deny client writes with the existing `/private/{id}`
  // policy.
  return `group_notification_preferences:${groupId}`;
}

const defaultPreferences: GroupNotificationPreferences = {
  muted: false,
  memberChatEnabled: true,
  announcementsEnabled: true,
  sessionsEnabled: true,
  invitationsEnabled: true,
};

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export function groupNotificationCategoryForKind(
  kind: NotificationKind,
): GroupNotificationCategory | null {
  switch (kind) {
    case "conversation_message":
      return "member_chat";
    case "group_announcement":
      return "announcements";
    case "group_session_scheduled":
    case "group_session_updated":
    case "group_session_cancelled":
      return "sessions";
    case "group_join_request":
    case "group_join_accepted":
    case "group_invitation":
    case "group_invitation_accepted":
      return "invitations";
    default:
      return null;
  }
}

export function parseStoredGroupNotificationPreferences(
  value: unknown,
): GroupNotificationPreferences {
  const data = asRecord(value);
  return {
    muted: booleanValue(data.muted, defaultPreferences.muted),
    memberChatEnabled: booleanValue(
      data.memberChatEnabled,
      defaultPreferences.memberChatEnabled,
    ),
    announcementsEnabled: booleanValue(
      data.announcementsEnabled,
      defaultPreferences.announcementsEnabled,
    ),
    sessionsEnabled: booleanValue(
      data.sessionsEnabled,
      defaultPreferences.sessionsEnabled,
    ),
    invitationsEnabled: booleanValue(
      data.invitationsEnabled,
      defaultPreferences.invitationsEnabled,
    ),
    schemaVersion:
      typeof data.schemaVersion === "number" ? data.schemaVersion : undefined,
  };
}

export function parseGroupNotificationPreferencesUpdate(
  value: unknown,
): GroupNotificationPreferences {
  const data = asRecord(value);
  const requiredBooleans = [
    "muted",
    "memberChatEnabled",
    "announcementsEnabled",
    "sessionsEnabled",
    "invitationsEnabled",
  ];
  for (const key of requiredBooleans) {
    if (typeof data[key] !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        `Group notification preference "${key}" must be a boolean.`,
      );
    }
  }
  return {
    muted: data.muted as boolean,
    memberChatEnabled: data.memberChatEnabled as boolean,
    announcementsEnabled: data.announcementsEnabled as boolean,
    sessionsEnabled: data.sessionsEnabled as boolean,
    invitationsEnabled: data.invitationsEnabled as boolean,
    schemaVersion: currentSchemaVersion,
  };
}


