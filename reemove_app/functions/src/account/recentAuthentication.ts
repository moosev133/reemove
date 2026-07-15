import {HttpsError} from "firebase-functions/v2/https";

const recentAuthenticationWindowSeconds = 10 * 60;

export function requireRecentAuthentication(authTime: unknown): void {
  if (typeof authTime !== "number") {
    throw new HttpsError(
      "failed-precondition",
      "Sign in again before completing this security action.",
    );
  }
  const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
  if (ageSeconds > recentAuthenticationWindowSeconds || ageSeconds < -60) {
    throw new HttpsError(
      "failed-precondition",
      "Sign in again before completing this security action.",
    );
  }
}
