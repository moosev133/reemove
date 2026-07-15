import {HttpsError} from "firebase-functions/v2/https";

export type ProvisionAccountData = {
  username: string;
  displayName: string;
  acceptedTerms: boolean;
  acceptedPrivacy: boolean;
  ageConfirmed: boolean;
};

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Invalid request payload.");
  }
  return value as Record<string, unknown>;
}

export function parseProvisionAccountData(value: unknown): ProvisionAccountData {
  const data = asRecord(value);
  if (
    typeof data.username !== "string" ||
    typeof data.displayName !== "string" ||
    typeof data.acceptedTerms !== "boolean" ||
    typeof data.acceptedPrivacy !== "boolean" ||
    typeof data.ageConfirmed !== "boolean"
  ) {
    throw new HttpsError("invalid-argument", "Complete all required account fields.");
  }
  return {
    username: data.username,
    displayName: data.displayName,
    acceptedTerms: data.acceptedTerms,
    acceptedPrivacy: data.acceptedPrivacy,
    ageConfirmed: data.ageConfirmed,
  };
}
