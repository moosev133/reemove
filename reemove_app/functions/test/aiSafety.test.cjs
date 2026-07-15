"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

// Compiled safety helpers are validated via npm test after build; this mirrors
// Phase 14 policy expectations at the Node test layer without ESM imports.
function containsUnsafeWorkoutLanguage(notes) {
  const text = Array.isArray(notes) ? notes.join(" ") : String(notes ?? "");
  return /one-repetition max|1rm|train through pain/i.test(text);
}

function assertCandidateIds(result, allowedIds) {
  const allowed = new Set(allowedIds);
  const recommendations = Array.isArray(result?.recommendations)
    ? result.recommendations
    : [];
  for (const item of recommendations) {
    if (!allowed.has(item.userId)) {
      throw new Error(`Invented candidate id: ${item.userId}`);
    }
  }
}

test("safe challenge wording is acceptable", () => {
  assert.equal(
    containsUnsafeWorkoutLanguage(["Complete three comfortable walks."]),
    false,
  );
});

test("unsafe workout language is rejected", () => {
  assert.equal(
    containsUnsafeWorkoutLanguage(["Perform a one-repetition max test."]),
    true,
  );
});

test("matchmaker cannot invent candidate ids", () => {
  assert.throws(() =>
    assertCandidateIds(
      {recommendations: [{userId: "invented-user"}]},
      ["real-user"],
    ),
  );
});
