const usernamePattern = /^[a-z0-9._]{3,30}$/;
const repeatedSeparatorPattern = /[._]{2,}/;
const reservedUsernames = new Set([
  "admin",
  "administrator",
  "api",
  "app",
  "auth",
  "contact",
  "help",
  "moderator",
  "reemove",
  "security",
  "staff",
  "support",
  "system",
  "team",
  "verified",
]);

export function normalizeUsername(value: string): string {
  return value.trim().toLowerCase();
}

export function validateUsername(value: string): string | null {
  const normalized = normalizeUsername(value);
  if (!usernamePattern.test(normalized)) {
    return "Use 3-30 lowercase letters, numbers, dots, or underscores.";
  }
  if (!/^[a-z0-9]/.test(normalized) || !/[a-z0-9]$/.test(normalized)) {
    return "The username must start and end with a letter or number.";
  }
  if (repeatedSeparatorPattern.test(normalized)) {
    return "Do not repeat dots or underscores.";
  }
  if (reservedUsernames.has(normalized)) {
    return "That username is reserved.";
  }
  return null;
}

export function validateDisplayName(value: string): string | null {
  const displayName = value.trim().replace(/\s+/g, " ");
  if (displayName.length < 1 || displayName.length > 80) {
    return "Display name must contain between 1 and 80 characters.";
  }
  return null;
}
