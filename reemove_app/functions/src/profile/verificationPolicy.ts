import {HttpsError} from "firebase-functions/v2/https";

export type VerificationDocumentKind =
  | "identity"
  | "certification"
  | "registration"
  | "other";

export type VerificationEvidenceItem = {
  storagePath: string;
  label: string;
  documentKind: VerificationDocumentKind;
  contentType?: string;
  sizeBytes?: number;
  issuer?: string;
  issuedAt?: string;
  expiresAt?: string;
};

const DOCUMENT_KINDS = new Set<VerificationDocumentKind>([
  "identity",
  "certification",
  "registration",
  "other",
]);

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function safeString(
  value: unknown,
  label: string,
  max: number,
  min = 0,
): string {
  if (typeof value !== "string") {
    if (min <= 0) return "";
    throw new HttpsError("invalid-argument", `${label} is required.`);
  }
  const trimmed = value.trim();
  if (trimmed.length < min) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be at least ${min} characters.`,
    );
  }
  if (trimmed.length > max) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be at most ${max} characters.`,
    );
  }
  return trimmed;
}

function optionalIsoDate(value: unknown, label: string): string | undefined {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} must be an ISO date.`);
  }
  const trimmed = value.trim();
  const parsed = Date.parse(trimmed);
  if (Number.isNaN(parsed)) {
    throw new HttpsError("invalid-argument", `${label} must be an ISO date.`);
  }
  return new Date(parsed).toISOString();
}

function documentKind(value: unknown): VerificationDocumentKind {
  if (typeof value !== "string" || !DOCUMENT_KINDS.has(value as VerificationDocumentKind)) {
    return "other";
  }
  return value as VerificationDocumentKind;
}


const ALLOWED_EVIDENCE_CONTENT_TYPES = new Set<string>([
  "image/png",
  "image/jpeg",
  "image/jpg",
  "image/webp",
]);

export function isAllowedVerificationEvidenceContentType(
  value: unknown,
): boolean {
  if (typeof value !== "string") return false;
  const normalized = value.trim().toLowerCase().split(";")[0]?.trim() ?? "";
  return ALLOWED_EVIDENCE_CONTENT_TYPES.has(normalized);
}

export function parseVerificationEvidenceItem(
  value: unknown,
): VerificationEvidenceItem {
  const data = asRecord(value);
  const item: VerificationEvidenceItem = {
    storagePath: safeString(data.storagePath, "Evidence path", 500, 1),
    label: safeString(data.label, "Evidence label", 80, 1),
    documentKind: documentKind(data.documentKind),
  };
  if (typeof data.contentType === "string" && data.contentType.trim()) {
    const contentType = data.contentType.trim().slice(0, 120);
    if (!isAllowedVerificationEvidenceContentType(contentType)) {
      throw new HttpsError(
        "invalid-argument",
        "Evidence content type is not supported.",
      );
    }
    item.contentType = contentType;
  }
  if (typeof data.sizeBytes === "number" && Number.isFinite(data.sizeBytes)) {
    if (data.sizeBytes <= 0 || data.sizeBytes > 15 * 1024 * 1024) {
      throw new HttpsError(
        "invalid-argument",
        "Evidence files must be between 1 byte and 15 MB.",
      );
    }
    item.sizeBytes = Math.floor(data.sizeBytes);
  }
  const issuer = safeString(data.issuer, "Issuer", 120, 0);
  if (issuer) item.issuer = issuer;
  const issuedAt = optionalIsoDate(data.issuedAt, "Issued at");
  if (issuedAt) item.issuedAt = issuedAt;
  const expiresAt = optionalIsoDate(data.expiresAt, "Expires at");
  if (expiresAt) item.expiresAt = expiresAt;
  if (item.issuedAt && item.expiresAt) {
    if (Date.parse(item.expiresAt) < Date.parse(item.issuedAt)) {
      throw new HttpsError(
        "invalid-argument",
        "Evidence expiry must be on or after the issued date.",
      );
    }
  }
  return item;
}

export function parseVerificationEvidenceList(
  value: unknown,
  options: {min: number; max?: number} = {min: 1, max: 6},
): VerificationEvidenceItem[] {
  const max = options.max ?? 6;
  if (!Array.isArray(value)) {
    throw new HttpsError(
      "invalid-argument",
      "Evidence must be an array.",
    );
  }
  if (value.length < options.min || value.length > max) {
    throw new HttpsError(
      "invalid-argument",
      options.min <= 0 ?
        `Attach at most ${max} verification documents.` :
        `Attach between ${options.min} and ${max} verification documents.`,
    );
  }
  return value.map((item) => parseVerificationEvidenceItem(item));
}

export function parseVerificationType(value: unknown):
  "athlete" | "trainer" | "business" {
  if (value === "athlete" || value === "trainer" || value === "business") {
    return value;
  }
  throw new HttpsError("invalid-argument", "Verification category is invalid.");
}
