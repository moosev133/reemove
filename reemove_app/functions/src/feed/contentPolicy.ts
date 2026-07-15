import {HttpsError} from "firebase-functions/v2/https";

export const maxCaptionLength = 2200;
export const maxStoryCaptionLength = 280;
export const maxCommentLength = 2200;
export const maxMediaItems = 10;
export const storyLifetimeHours = 24;

export type ContentVisibility = "public" | "followers" | "private";
export type PublishKind = "post" | "story" | "reel";
export type MediaKind = "image" | "video";

export type MediaInput = {
  id: string;
  storagePath: string;
  kind: MediaKind;
  processingState: "pending" | "ready" | "failed";
  downloadUrl?: string;
  thumbnailUrl?: string;
  width?: number;
  height?: number;
  durationMs?: number;
  contentType?: string;
  sizeBytes?: number;
};

export type PublishRequest = {
  draftId: string;
  kind: PublishKind;
  caption: string;
  media: MediaInput[];
  sportId?: string;
  locationLabel?: string;
  visibility: ContentVisibility;
  allowComments: boolean;
};

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  return value as Record<string, unknown>;
}

function stringValue(
  data: Record<string, unknown>,
  key: string,
  maximum: number,
): string {
  const value = data[key];
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${key} is required.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new HttpsError("invalid-argument", `${key} is invalid.`);
  }
  return normalized;
}

function optionalString(
  data: Record<string, unknown>,
  key: string,
  maximum: number,
): string | undefined {
  const value = data[key];
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${key} is invalid.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new HttpsError("invalid-argument", `${key} is invalid.`);
  }
  return normalized;
}

function publishKind(value: unknown): PublishKind {
  if (value === "post" || value === "story" || value === "reel") return value;
  throw new HttpsError("invalid-argument", "Content type is invalid.");
}

function visibility(value: unknown): ContentVisibility {
  if (value === "public" || value === "followers" || value === "private") {
    return value;
  }
  throw new HttpsError("invalid-argument", "Visibility is invalid.");
}

function mediaKind(value: unknown): MediaKind {
  if (value === "image" || value === "video") return value;
  throw new HttpsError("invalid-argument", "Media type is invalid.");
}

function mediaState(value: unknown): "pending" | "ready" | "failed" {
  if (value === "pending" || value === "ready" || value === "failed") {
    return value;
  }
  return "pending";
}

function optionalNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function parseMedia(value: unknown): MediaInput[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > maxMediaItems) {
    throw new HttpsError(
      "invalid-argument",
      `Choose between 1 and ${maxMediaItems} media items.`,
    );
  }
  return value.map((item) => {
    const data = record(item);
    return {
      id: stringValue(data, "id", 128),
      storagePath: stringValue(data, "storagePath", 1024),
      kind: mediaKind(data.kind),
      processingState: mediaState(data.processingState),
      downloadUrl: optionalString(data, "downloadUrl", 4096),
      thumbnailUrl: optionalString(data, "thumbnailUrl", 4096),
      width: optionalNumber(data.width),
      height: optionalNumber(data.height),
      durationMs: optionalNumber(data.durationMs),
      contentType: optionalString(data, "contentType", 255),
      sizeBytes: optionalNumber(data.sizeBytes),
    };
  });
}

export function parsePublishRequest(value: unknown): PublishRequest {
  const data = record(value);
  const kind = publishKind(data.kind);
  const captionLimit = kind === "story" ? maxStoryCaptionLength : maxCaptionLength;
  const rawCaption = data.caption;
  if (typeof rawCaption !== "string" || rawCaption.length > captionLimit) {
    throw new HttpsError("invalid-argument", "Caption is too long.");
  }
  const caption = normalizeUserText(rawCaption);
  const media = parseMedia(data.media);
  if (kind === "story" && media.length !== 1) {
    throw new HttpsError("invalid-argument", "A story needs exactly one media item.");
  }
  if (kind === "reel" &&
      (media.length !== 1 || media[0].kind !== "video")) {
    throw new HttpsError("invalid-argument", "A reel needs exactly one video.");
  }
  if (media.some((item) => item.kind === "video") && media.length > 1) {
    throw new HttpsError(
      "invalid-argument",
      "Video cannot be combined with other media in one post.",
    );
  }
  return {
    draftId: stringValue(data, "draftId", 128),
    kind,
    caption,
    media,
    sportId: optionalString(data, "sportId", 128),
    locationLabel: optionalString(data, "locationLabel", 160),
    visibility: visibility(data.visibility),
    allowComments: data.allowComments !== false,
  };
}

export function parseCommentText(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Comment text is required.");
  }
  const normalized = normalizeUserText(value);
  if (normalized.length === 0 || normalized.length > maxCommentLength) {
    throw new HttpsError("invalid-argument", "Comment text is invalid.");
  }
  return normalized;
}

export function normalizeUserText(value: string): string {
  return value
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/\r\n/g, "\n")
    .trim();
}

export function extractHashtags(value: string): string[] {
  const matches = value.match(/(?:^|\s)#([\p{L}\p{N}_]{1,50})/gu) ?? [];
  return [...new Set(matches.map((item) => item.trim().slice(1).toLowerCase()))]
    .slice(0, 30);
}

export function extractMentions(value: string): string[] {
  const matches = value.match(/(?:^|\s)@([a-zA-Z0-9._]{3,30})/g) ?? [];
  return [...new Set(matches.map((item) => item.trim().slice(1).toLowerCase()))]
    .slice(0, 30);
}

export function safeDocumentId(value: unknown, field: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 128 ||
      value.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}
