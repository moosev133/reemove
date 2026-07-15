const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  ageBandFor,
  calculateAge,
  isValidIsoBirthDate,
  validateAge,
} = require("../lib/onboarding/onboardingPolicy.js");
const {encodeGeohash, roundCoordinate} = require("../lib/onboarding/geohash.js");

describe("onboarding age policy", () => {
  const today = new Date("2026-07-13T12:00:00.000Z");

  it("calculates age around the birthday boundary", () => {
    assert.equal(calculateAge("2013-07-13", today), 13);
    assert.equal(calculateAge("2013-07-14", today), 12);
  });

  it("rejects impossible dates and users below the configured minimum", () => {
    assert.equal(isValidIsoBirthDate("2010-02-30"), false);
    assert.match(validateAge("2015-01-01", 13, 120, today), /at least 13/);
    assert.equal(validateAge("2000-05-20", 13, 120, today), null);
  });

  it("creates privacy-safe age bands", () => {
    assert.equal(ageBandFor(16), "minor");
    assert.equal(ageBandFor(21), "18_24");
    assert.equal(ageBandFor(40), "35_44");
  });
});

describe("onboarding geospatial policy", () => {
  it("produces stable geohashes and coarse public coordinates", () => {
    assert.equal(encodeGeohash(32.794, 34.9896, 6), "svbfs1");
    assert.equal(roundCoordinate(32.794, 2), 32.79);
    assert.equal(roundCoordinate(34.9896, 2), 34.99);
  });
});
