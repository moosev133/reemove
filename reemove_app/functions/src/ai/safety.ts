import { HttpsError } from 'firebase-functions/v2/https';

const unsafePatterns: RegExp[] = [
  /\b1\s*rm\b/i,
  /\bone[- ]rep(?:etition)? max\b/i,
  /\bmax(?:imum)? out\b/i,
  /\btrain through pain\b/i,
  /\bstarv(?:e|ation|ing)\b/i,
  /\bpurge|purging\b/i,
  /\bdiet pills?\b/i,
  /\bdehydrat(?:e|ion)\b/i,
  /\bsleep deprivation\b/i,
  /\bbreath[- ]holding contest\b/i,
  /\brooftop challenge\b/i,
];

export function assertReeMoveSafety(module: string, result: unknown): void {
  const text = JSON.stringify(result);
  if (unsafePatterns.some((pattern) => pattern.test(text))) {
    throw new HttpsError(
      'failed-precondition',
      'The generated result did not pass ReeMove safety checks.',
      { reasonCode: 'reemove_safety_filter' },
    );
  }

  if (module === 'challenge') {
    const value = result as { difficulty?: unknown; durationDays?: unknown };
    if (!['low', 'moderate'].includes(String(value.difficulty))) {
      throw new HttpsError('failed-precondition', 'Unsafe challenge difficulty.');
    }
    const duration = Number(value.durationDays);
    if (!Number.isInteger(duration) || duration < 1 || duration > 30) {
      throw new HttpsError('failed-precondition', 'Invalid challenge duration.');
    }
  }
}

export function assertCandidateIds(
  result: unknown,
  allowedCandidateIds: string[],
): void {
  const allowed = new Set(allowedCandidateIds);
  const recommendations = (result as { recommendations?: unknown }).recommendations;
  if (!Array.isArray(recommendations)) {
    throw new HttpsError('internal', 'Invalid matchmaker output.');
  }
  for (const item of recommendations) {
    const userId = (item as { userId?: unknown }).userId;
    if (typeof userId !== 'string' || !allowed.has(userId)) {
      throw new HttpsError('failed-precondition', 'Matchmaker returned an invalid candidate.');
    }
  }
}
