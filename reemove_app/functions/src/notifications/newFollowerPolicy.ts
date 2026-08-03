import type {AccountPrivacy} from "../profile/profilePrivacyModel";

/**
 * "New follower" is only for public instant follows (direct_follow edges).
 * Accepted private follow requests use follow_request_accepted for the
 * requester and must never create a New follower item for the target.
 */
export function shouldDeliverNewFollowerNotification(input: {
  edgeSource: string;
  accountPrivacy: AccountPrivacy;
  followApprovalPolicy?: string;
}): boolean {
  if (input.edgeSource !== "direct_follow") {
    return false;
  }
  if (input.accountPrivacy !== "public") {
    return false;
  }
  if (input.followApprovalPolicy === "approvalRequired") {
    return false;
  }
  return true;
}

export function isConfirmedNewFollowerPayload(data: Record<string, unknown>): boolean {
  if (data.relationshipStatus !== "confirmed") return false;
  if (data.source !== "direct_follow") return false;
  if (data.status === "resolved" || data.status === "orphaned") return false;
  return true;
}
