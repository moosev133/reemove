import {createHash} from "node:crypto";

import {HttpsError} from "firebase-functions/v2/https";

export const maximumGroupMembers = 50;
export const maximumMessageLength = 4000;
export const maximumMessageAttachments = 4;
export const maximumGroupTitleLength = 80;
export const editableMessageMinutes = 15;
export const deletableMessageHours = 24;

export type MessageKind = "text" | "image" | "video" | "audio";
export type AttachmentInput = {
  id: string;
  storagePath: string;
  contentType: string;
  sizeBytes: number;
  kind: Exclude<MessageKind, "text">;
};

export function recordValue(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  return value as Record<string, unknown>;
}

export function safeId(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > 128 || normalized.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return normalized;
}

export function optionalId(value: unknown, field: string): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  return safeId(value, field);
}

export function normalizedMessageText(value: unknown): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Message text is invalid.");
  }
  const normalized = value
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/\r\n/g, "\n")
    .trim();
  if (normalized.length > maximumMessageLength) {
    throw new HttpsError(
      "invalid-argument",
      `Messages may contain at most ${maximumMessageLength} characters.`,
    );
  }
  return normalized;
}

export function groupTitle(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Group title is required.");
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length < 2 || normalized.length > maximumGroupTitleLength) {
    throw new HttpsError(
      "invalid-argument",
      `Group titles must be 2-${maximumGroupTitleLength} characters.`,
    );
  }
  return normalized;
}

export function uniqueIds(value: unknown, field: string, maximum: number): string[] {
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const result = [...new Set(value.map((item) => safeId(item, field)))];
  if (result.length > maximum) {
    throw new HttpsError("invalid-argument", `${field} contains too many people.`);
  }
  return result;
}

function attachmentKind(value: unknown): Exclude<MessageKind, "text"> {
  if (value === "image" || value === "video" || value === "audio") return value;
  throw new HttpsError("invalid-argument", "Attachment type is invalid.");
}

export function parseAttachments(value: unknown): AttachmentInput[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > maximumMessageAttachments) {
    throw new HttpsError(
      "invalid-argument",
      `Messages may contain up to ${maximumMessageAttachments} attachments.`,
    );
  }
  const attachments = value.map((item) => {
    const data = recordValue(item);
    const contentType = typeof data.contentType === "string" ? data.contentType.trim() : "";
    const sizeBytes = typeof data.sizeBytes === "number" && Number.isInteger(data.sizeBytes) ?
      data.sizeBytes : -1;
    if (contentType.length === 0 || contentType.length > 255 || sizeBytes <= 0) {
      throw new HttpsError("invalid-argument", "Attachment metadata is invalid.");
    }
    return {
      id: safeId(data.id, "attachmentId"),
      storagePath: storagePath(data.storagePath),
      contentType,
      sizeBytes,
      kind: attachmentKind(data.kind),
    };
  });
  const nonImages = attachments.filter((item) => item.kind !== "image");
  if (nonImages.length > 0 && attachments.length > 1) {
    throw new HttpsError(
      "invalid-argument",
      "Video and audio attachments must be sent individually.",
    );
  }
  return attachments;
}

function storagePath(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Attachment path is invalid.");
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > 1024 || normalized.startsWith("/")) {
    throw new HttpsError("invalid-argument", "Attachment path is invalid.");
  }
  return normalized;
}

export function messageKind(text: string, attachments: AttachmentInput[]): MessageKind {
  if (attachments.length === 0) return "text";
  return attachments[0].kind;
}

export function messagePreview(kind: MessageKind, text: string): string {
  if (text.length > 0) return text.length > 120 ? `${text.slice(0, 117)}...` : text;
  switch (kind) {
  case "image": return "Photo";
  case "video": return "Video";
  case "audio": return "Audio";
  case "text": return "Message";
  }
}

export function directConversationId(firstUid: string, secondUid: string): string {
  const pair = [firstUid, secondUid].sort().join("--");
  return `direct_${createHash("sha256").update(pair).digest("hex").slice(0, 40)}`;
}

export const allowedReactionEmojis = ["❤️", "👏", "🔥", "💪", "😂", "⚡"] as const;

export function reactionEmoji(value: unknown): string {
  if (typeof value === "string" && allowedReactionEmojis.includes(
    value as typeof allowedReactionEmojis[number],
  )) return value;
  throw new HttpsError("invalid-argument", "Reaction is invalid.");
}

export function reportReason(value: unknown): string {
  const allowed = ["spam", "harassment", "hate", "sexual", "violence", "scam", "other"];
  if (typeof value === "string" && allowed.includes(value)) return value;
  throw new HttpsError("invalid-argument", "Report reason is invalid.");
}

export function optionalDetails(value: unknown): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Report details are invalid.");
  }
  const normalized = value.trim();
  if (normalized.length > 1000) {
    throw new HttpsError("invalid-argument", "Report details are too long.");
  }
  return normalized;
}
