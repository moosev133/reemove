"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const allowedCodes = new Set([
  "unauthenticated",
  "permission-denied",
  "invalid-argument",
  "failed-precondition",
  "resource-exhausted",
  "deadline-exceeded",
  "unavailable",
  "internal",
]);

function assertSafeError(error) {
  assert.equal(typeof error.code, "string");
  assert.ok(allowedCodes.has(error.code));
  assert.equal(typeof error.message, "string");
  assert.ok(error.message.length > 0 && error.message.length <= 240);
  assert.doesNotMatch(
    error.message,
    /api[_ -]?key|system prompt|stack trace|authorization:/i,
  );
}

test("safe callable error contract accepts stable public errors", () => {
  assert.doesNotThrow(() =>
    assertSafeError({
      code: "resource-exhausted",
      message: "Daily AI request limit reached. Try again later.",
    }),
  );
});

test("safe callable error contract rejects leaked internals", () => {
  assert.throws(() =>
    assertSafeError({
      code: "internal",
      message: "API key abc and stack trace: internal/path.ts:20",
    }),
  );
});
