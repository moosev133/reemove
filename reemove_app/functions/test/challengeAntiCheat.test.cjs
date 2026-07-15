const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {assessSubmissionRisk} = require('../lib/challenges/antiCheat.js');

describe('challenge submission risk', () => {
  it('auto-verifies a low-risk activity-backed submission', () => {
    const result = assessSubmissionRisk({
      progressDelta: 2,
      maximumDailyProgress: 5,
      metric: 'distance',
      activityVerified: true,
      hasRequiredProof: true,
      duplicateActivity: false,
      submissionCountToday: 1,
      minutesSincePreviousSubmission: 90,
    });
    assert.equal(result.score, 0);
    assert.equal(result.autoVerify, true);
  });

  it('blocks duplicate activity and daily-cap abuse', () => {
    const result = assessSubmissionRisk({
      progressDelta: 8,
      maximumDailyProgress: 5,
      metric: 'distance',
      activityVerified: false,
      hasRequiredProof: false,
      duplicateActivity: true,
      submissionCountToday: 5,
      minutesSincePreviousSubmission: 1,
    });
    assert.equal(result.score, 100);
    assert.equal(result.autoVerify, false);
    assert.ok(result.reasons.includes('duplicate_activity'));
    assert.ok(result.reasons.includes('daily_cap_exceeded'));
  });
});
