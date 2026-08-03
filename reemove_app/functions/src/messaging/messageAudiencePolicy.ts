/**
 * Pure gate used by createDirectConversation / relationship.canMessage.
 * Kept free of firebase-admin so unit tests can import it directly.
 */
export function isMessageAudienceAllowed(
  audience: string,
  senderIsFollowerOfTarget: boolean,
): boolean {
  if (audience === "noOne") return false;
  if (audience === "followers" && !senderIsFollowerOfTarget) return false;
  return true;
}
