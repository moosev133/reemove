import type {ChallengeMetric} from "./challengePolicy";

export type SubmissionRiskInput = {
  progressDelta: number;
  maximumDailyProgress: number;
  metric: ChallengeMetric;
  activityVerified: boolean;
  hasRequiredProof: boolean;
  duplicateActivity: boolean;
  submissionCountToday: number;
  minutesSincePreviousSubmission?: number;
};

export type SubmissionRisk = {
  score: number;
  reasons: string[];
  autoVerify: boolean;
};

export function assessSubmissionRisk(input: SubmissionRiskInput): SubmissionRisk {
  const reasons: string[] = [];
  let score = 0;
  if (input.progressDelta <= 0) {
    score += 100;
    reasons.push("non_positive_progress");
  }
  if (input.progressDelta > input.maximumDailyProgress) {
    score += 100;
    reasons.push("daily_cap_exceeded");
  } else if (input.progressDelta > input.maximumDailyProgress * 0.8) {
    score += 15;
    reasons.push("near_daily_cap");
  }
  if (input.duplicateActivity) {
    score += 100;
    reasons.push("duplicate_activity");
  }
  if (!input.activityVerified) {
    score += 25;
    reasons.push("activity_not_verified");
  }
  if (!input.hasRequiredProof) {
    score += 40;
    reasons.push("required_proof_missing");
  }
  if (input.submissionCountToday >= 4) {
    score += 25;
    reasons.push("high_submission_frequency");
  }
  if (input.minutesSincePreviousSubmission !== undefined &&
      input.minutesSincePreviousSubmission < 2) {
    score += 20;
    reasons.push("rapid_resubmission");
  }
  const normalizedScore = Math.min(100, score);
  return {
    score: normalizedScore,
    reasons,
    autoVerify: normalizedScore < 30,
  };
}
