/**
 * Canonical ReeMove privacy model
 * ===============================
 *
 * Account privacy (who may view an account's profile surface):
 * - public: strangers may view the account per content rules.
 * - private: strangers see preview only; approved followers access follower-authorized content.
 * - ownerOnly: only the owner may view the account (legacy users.visibility = "private").
 *
 * Content visibility (posts, stories, reels):
 * - public: visible to anyone who can view the author's account.
 * - followers: visible only to approved followers of the author.
 * - private: owner-only content; never exposed to followers.
 *
 * Legacy storage on users.visibility (kept for rules + backward compatibility):
 * - public    -> accountPrivacy public
 * - followers -> accountPrivacy private   (Instagram-style private account)
 * - private   -> accountPrivacy ownerOnly
 *
 * Profile Settings "Private account" writes accountPrivacy private and
 * users.visibility followers. It does not remove existing followers.
 */

import type {DocumentSnapshot} from "firebase-admin/firestore";

export type AccountPrivacy = "public" | "private" | "ownerOnly";
export type ContentVisibility = "public" | "followers" | "private";
export type LegacyProfileVisibility = "public" | "followers" | "private";
export type ProfileAccessLevel = "full" | "preview" | "unavailable";

const ACCOUNT_PRIVACY_VALUES = new Set<AccountPrivacy>([
  "public",
  "private",
  "ownerOnly",
]);

export function accountPrivacyFromLegacyVisibility(
  legacy: unknown,
): AccountPrivacy {
  const value = String(legacy ?? "public");
  switch (value) {
  case "public":
    return "public";
  case "followers":
    return "private";
  case "private":
    return "ownerOnly";
  default:
    return "public";
  }
}

export function legacyVisibilityForAccountPrivacy(
  accountPrivacy: AccountPrivacy,
): LegacyProfileVisibility {
  switch (accountPrivacy) {
  case "public":
    return "public";
  case "private":
    return "followers";
  case "ownerOnly":
    return "private";
  }
}

export function normalizeLegacyProfileVisibility(
  value: unknown,
): LegacyProfileVisibility {
  const candidate = String(value ?? "public");
  if (candidate === "public" ||
      candidate === "followers" ||
      candidate === "private") {
    return candidate;
  }
  return "public";
}

export function resolveAccountPrivacy(
  source: DocumentSnapshot | Record<string, unknown>,
): AccountPrivacy {
  let accountPrivacy: unknown;
  let visibility: unknown;
  if ("get" in source && typeof source.get === "function") {
    accountPrivacy = source.get("accountPrivacy");
    visibility = source.get("visibility");
  } else {
    const record = source as Record<string, unknown>;
    accountPrivacy = record.accountPrivacy;
    visibility = record.visibility;
  }
  if (typeof accountPrivacy === "string" &&
      ACCOUNT_PRIVACY_VALUES.has(accountPrivacy as AccountPrivacy)) {
    return accountPrivacy as AccountPrivacy;
  }
  return accountPrivacyFromLegacyVisibility(visibility);
}

export function viewerCanViewFullAccount(
  accountPrivacy: AccountPrivacy,
  isOwner: boolean,
  isFollowing: boolean,
): boolean {
  if (isOwner) return true;
  if (accountPrivacy === "public") return true;
  if (accountPrivacy === "private") return isFollowing;
  return false;
}

export function viewerCanViewContent(
  contentVisibility: ContentVisibility,
  isOwner: boolean,
  isFollowing: boolean,
): boolean {
  if (isOwner) return true;
  if (contentVisibility === "public") return true;
  if (contentVisibility === "followers") return isFollowing;
  return false;
}

export function viewerCanViewAuthorContent(
  accountPrivacy: AccountPrivacy,
  contentVisibility: ContentVisibility,
  isOwner: boolean,
  isFollowing: boolean,
): boolean {
  return viewerCanViewFullAccount(accountPrivacy, isOwner, isFollowing) &&
    viewerCanViewContent(contentVisibility, isOwner, isFollowing);
}

export function normalizeContentVisibility(value: unknown): ContentVisibility {
  const candidate = String(value ?? "public");
  if (candidate === "public" ||
      candidate === "followers" ||
      candidate === "private") {
    return candidate;
  }
  return "public";
}

export function accountPrivacyFromSettingsToggle(isPublic: boolean): AccountPrivacy {
  return isPublic ? "public" : "private";
}

export function followApprovalPolicyForAccountPrivacy(
  accountPrivacy: AccountPrivacy,
  requested: unknown,
): "automatic" | "approvalRequired" {
  if (accountPrivacy !== "public") {
    return "approvalRequired";
  }
  return requested === "approvalRequired" ? "approvalRequired" : "automatic";
}

export function buildPublicProfileCallableResponse(input: {
  access: ProfileAccessLevel;
  profile?: Record<string, unknown>;
  preview?: Record<string, unknown>;
  relationship: Record<string, unknown>;
}): Record<string, unknown> {
  if (input.access === "full" && input.profile) {
    return {
      access: "full",
      profile: input.profile,
      relationship: input.relationship,
    };
  }
  if (input.access === "preview" && input.preview) {
    return {
      access: "preview",
      preview: input.preview,
      // Legacy clients read `profile`; mirror the safe preview payload.
      profile: input.preview,
      relationship: input.relationship,
    };
  }
  return {
    access: input.access,
    relationship: input.relationship,
  };
}
