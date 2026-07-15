import assert from 'node:assert/strict';
import test from 'node:test';

import { assertCandidateIds, assertReeMoveSafety } from './safety';

test('safe challenge passes', () => {
  assert.doesNotThrow(() => assertReeMoveSafety('challenge', {
    difficulty: 'moderate',
    durationDays: 7,
    description: 'Complete three comfortable walks this week.',
  }));
});

test('unsafe workout language is rejected', () => {
  assert.throws(() => assertReeMoveSafety('workout', {
    notes: ['Perform a one-repetition max test.'],
  }));
});

test('matchmaker cannot invent candidate ids', () => {
  assert.throws(() => assertCandidateIds({
    recommendations: [{ userId: 'invented-user' }],
  }, ['real-user']));
});
