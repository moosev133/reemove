import {HttpsError} from "firebase-functions/v2/https";

import {parseGroupMediaMode} from "../groups/groupChannelAccess";
import type {GroupMediaMode} from "../groups/groupsPolicy";
import {
  groupTitle,
  normalizedMessageText,
  optionalDetails,
  optionalId,
  parseAttachments,
  reactionEmoji,
  recordValue,
  reportReason,
  safeId,
  uniqueIds,
  type AttachmentInput,
} from "./messagingPolicy";

export function parseDirectRequest(value: unknown): {targetUserId: string} {
  const data = recordValue(value);
  return {targetUserId: safeId(data.targetUserId, "targetUserId")};
}

export function parseCreateGroupRequest(value: unknown): {
  title: string;
  memberIds: string[];
} {
  const data = recordValue(value);
  return {
    title: groupTitle(data.title),
    memberIds: uniqueIds(data.memberIds, "memberIds", 49),
  };
}

export function parseUpdateGroupRequest(value: unknown): {
  conversationId: string;
  title?: string;
  avatarUrl?: string;
  avatarStoragePath?: string;
  addMemberIds: string[];
  removeMemberIds: string[];
} {
  const data = recordValue(value);
  const rawTitle = data.title;
  const title = rawTitle === undefined ? undefined : groupTitle(rawTitle);
  const avatarUrl = optionalUrl(data.avatarUrl, "avatarUrl");
  const avatarStoragePath = optionalText(data.avatarStoragePath, "avatarStoragePath", 1024);
  const addMemberIds = uniqueIds(data.addMemberIds ?? [], "addMemberIds", 20);
  const removeMemberIds = uniqueIds(data.removeMemberIds ?? [], "removeMemberIds", 20);
  if (!title && !avatarUrl && !avatarStoragePath &&
      addMemberIds.length === 0 && removeMemberIds.length === 0) {
    throw new HttpsError("invalid-argument", "No group changes were supplied.");
  }
  return {
    conversationId: safeId(data.conversationId, "conversationId"),
    title,
    avatarUrl,
    avatarStoragePath,
    addMemberIds,
    removeMemberIds,
  };
}

export function parseConversationRequest(value: unknown): {conversationId: string} {
  const data = recordValue(value);
  return {conversationId: safeId(data.conversationId, "conversationId")};
}

export function parseSendRequest(value: unknown): {
  conversationId: string;
  clientMessageId: string;
  text: string;
  attachments: AttachmentInput[];
  replyToMessageId?: string;
  mediaMode: GroupMediaMode;
} {
  const data = recordValue(value);
  const text = normalizedMessageText(data.text);
  const attachments = parseAttachments(data.attachments);
  if (text.length === 0 && attachments.length === 0) {
    throw new HttpsError("invalid-argument", "Write a message or add media.");
  }
  const mediaMode = parseGroupMediaMode(data.mediaMode ?? "normal");
  if (mediaMode === "view_once" && attachments.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "View-once messages require an attachment.",
    );
  }
  return {
    conversationId: safeId(data.conversationId, "conversationId"),
    clientMessageId: safeId(data.clientMessageId, "clientMessageId"),
    text,
    attachments,
    replyToMessageId: optionalId(data.replyToMessageId, "replyToMessageId"),
    mediaMode,
  };
}

export function parseEditRequest(value: unknown): {
  conversationId: string;
  messageId: string;
  text: string;
} {
  const data = recordValue(value);
  const text = normalizedMessageText(data.text);
  if (text.length === 0) {
    throw new HttpsError("invalid-argument", "Message text cannot be empty.");
  }
  return {
    conversationId: safeId(data.conversationId, "conversationId"),
    messageId: safeId(data.messageId, "messageId"),
    text,
  };
}

export function parseMessageRequest(value: unknown): {
  conversationId: string;
  messageId: string;
} {
  const data = recordValue(value);
  return {
    conversationId: safeId(data.conversationId, "conversationId"),
    messageId: safeId(data.messageId, "messageId"),
  };
}

export function parseReactionRequest(value: unknown): {
  conversationId: string;
  messageId: string;
  emoji: string;
} {
  const request = parseMessageRequest(value);
  const data = recordValue(value);
  return {...request, emoji: reactionEmoji(data.emoji)};
}

export function parseReadRequest(value: unknown): {
  conversationId: string;
  messageId: string;
} {
  return parseMessageRequest(value);
}

export function parsePreferencesRequest(value: unknown): {
  conversationId: string;
  mutedUntil?: Date;
  notificationsEnabled?: boolean;
  archived?: boolean;
} {
  const data = recordValue(value);
  const mutedUntil = optionalDate(data.mutedUntil, "mutedUntil");
  return {
    conversationId: safeId(data.conversationId, "conversationId"),
    mutedUntil,
    notificationsEnabled: optionalBoolean(data.notificationsEnabled, "notificationsEnabled"),
    archived: optionalBoolean(data.archived, "archived"),
  };
}

export function parseReportRequest(value: unknown): {
  conversationId: string;
  messageId: string;
  reason: string;
  details: string;
} {
  const request = parseMessageRequest(value);
  const data = recordValue(value);
  return {
    ...request,
    reason: reportReason(data.reason),
    details: optionalDetails(data.details),
  };
}

function optionalBoolean(value: unknown, field: string): boolean | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}

function optionalDate(value: unknown, field: string): Date | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return date;
}

function optionalText(value: unknown, field: string, maximum: number): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

function optionalUrl(value: unknown, field: string): string | undefined {
  const candidate = optionalText(value, field, 2048);
  if (!candidate) return undefined;
  let url: URL;
  try {
    url = new URL(candidate);
  } catch {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  if (url.protocol !== "https:") {
    throw new HttpsError("invalid-argument", `${field} must use HTTPS.`);
  }
  return url.toString();
}
