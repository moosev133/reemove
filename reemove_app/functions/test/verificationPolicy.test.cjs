const test = require("node:test");
const assert = require("node:assert/strict");

const {
  parseVerificationEvidenceItem,
  parseVerificationEvidenceList,
  parseVerificationType,
} = require("../lib/profile/verificationPolicy.js");

test("verification policy", async (t) => {
  await t.test("accepts backward-compatible evidence path+label only", () => {
    const item = parseVerificationEvidenceItem({
      storagePath: "verification/u1/u1/a.jpg",
      label: "Coach cert",
    });
    assert.equal(item.documentKind, "other");
    assert.equal(item.label, "Coach cert");
  });

  await t.test("parses certification metadata", () => {
    const item = parseVerificationEvidenceItem({
      storagePath: "verification/u1/u1/a.jpg",
      label: "NSCA CSCS",
      documentKind: "certification",
      contentType: "image/jpeg",
      sizeBytes: 1200,
      issuer: "NSCA",
      issuedAt: "2024-01-15T00:00:00.000Z",
      expiresAt: "2026-01-15T00:00:00.000Z",
    });
    assert.equal(item.documentKind, "certification");
    assert.equal(item.issuer, "NSCA");
    assert.ok(item.expiresAt);
  });

  await t.test("rejects inverted issued/expiry dates", () => {
    assert.throws(
      () => parseVerificationEvidenceItem({
        storagePath: "verification/u1/u1/a.jpg",
        label: "Cert",
        issuedAt: "2026-01-01T00:00:00.000Z",
        expiresAt: "2025-01-01T00:00:00.000Z",
      }),
      /expiry/i,
    );
  });

  await t.test("submit requires at least one evidence item", () => {
    assert.throws(
      () => parseVerificationEvidenceList([], {min: 1, max: 6}),
      /between 1 and 6/i,
    );
  });

  await t.test("draft allows empty evidence list", () => {
    const list = parseVerificationEvidenceList([], {min: 0, max: 6});
    assert.equal(list.length, 0);
  });

  await t.test("parses trainer verification type", () => {
    assert.equal(parseVerificationType("trainer"), "trainer");
    assert.throws(() => parseVerificationType("coach"), /invalid/i);
  });
});
