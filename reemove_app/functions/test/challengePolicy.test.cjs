const assert = require('node:assert/strict');
const {describe, it} = require('node:test');

const {
  calculateAge,
  containsUnsafeChallengeLanguage,
  parseChallengeInput,
  progressPercent,
  validateChallengeTarget,
} = require('../lib/challenges/challengePolicy.js');

describe('challenge safety policy', () => {
  it('accepts a bounded beginner distance challenge', () => {
    const now = new Date('2026-07-14T06:00:00.000Z');
    const result = parseChallengeInput({
      sportId: 'running',
      title: 'Steady five kilometre week',
      description: 'Record five kilometres across comfortable sessions with recovery.',
      difficulty: 'beginner',
      startsAt: '2026-07-14T07:00:00.000Z',
      endsAt: '2026-07-21T07:00:00.000Z',
      metric: 'distance',
      target: 5,
      unit: 'km',
      verificationMethod: 'automaticActivity',
      maximumDailyProgress: 3,
      minimumAge: 14,
      requiresRestDays: true,
      maximumEffortMinutesPerDay: 90,
    }, now);
    assert.equal(result.metric, 'distance');
    assert.equal(result.maximumDailyProgress, 3);
  });

  it('rejects unsafe language and invalid duration', () => {
    const now = new Date('2026-07-14T06:00:00.000Z');
    assert.throws(() => parseChallengeInput({
      sportId: 'gym', title: 'Ignore pain challenge',
      description: 'Keep lifting even when your body tells you to stop immediately.',
      difficulty: 'beginner', startsAt: '2026-07-14T07:00:00.000Z',
      endsAt: '2026-07-14T07:30:00.000Z', metric: 'sessions', target: 2,
      unit: 'sessions', verificationMethod: 'organizerReview',
      maximumDailyProgress: 1, minimumAge: 14, requiresRestDays: true,
      maximumEffortMinutesPerDay: 90,
    }, now));
  });

  it('rejects unsafe target, unit, and daily caps', () => {
    assert.throws(() => validateChallengeTarget({
      metric: 'distance', target: 600, unit: 'km',
      maximumDailyProgress: 60, maximumEffortMinutesPerDay: 90,
    }));
    assert.throws(() => validateChallengeTarget({
      metric: 'sessions', target: 3, unit: 'km',
      maximumDailyProgress: 1, maximumEffortMinutesPerDay: 90,
    }));
  });

  it('detects explicitly prohibited wording', () => {
    assert.equal(containsUnsafeChallengeLanguage('Safe week', 'Rest normally'), false);
    assert.equal(containsUnsafeChallengeLanguage('No sleep challenge'), true);
  });
});

describe('challenge calculations', () => {
  it('calculates age at the birthday boundary', () => {
    assert.equal(calculateAge('2010-07-14', new Date('2026-07-14T00:00:00Z')), 16);
    assert.equal(calculateAge('2010-07-15', new Date('2026-07-14T00:00:00Z')), 15);
  });

  it('clamps progress percentages', () => {
    assert.equal(progressPercent(2.5, 5), 50);
    assert.equal(progressPercent(7, 5), 100);
    assert.equal(progressPercent(-1, 5), 0);
  });
});
