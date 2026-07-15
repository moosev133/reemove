const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {parseOnboardingDraft} = require("../lib/onboarding/requestData.js");

function validDraft() {
  return {
    version: 1,
    currentStep: "review",
    dateOfBirth: "2000-01-01",
    avatarUrl: null,
    avatarStoragePath: null,
    favoriteSportIds: ["football"],
    sportLevels: {football: "intermediate"},
    goals: ["stay_active"],
    location: null,
    locationPermission: "notAsked",
    discovery: {
      radiusKm: 25,
      showNearbyPeople: true,
      recommendEvents: true,
      allowTrainerDiscovery: true,
      visibility: "public",
    },
    accessibility: {},
    notifications: {
      masterEnabled: false,
      permissionStatus: "notAsked",
    },
  };
}

describe("onboarding request parsing", () => {
  it("normalizes a valid bounded draft", () => {
    const parsed = parseOnboardingDraft(validDraft());
    assert.deepEqual(parsed.favoriteSportIds, ["football"]);
    assert.equal(parsed.discovery.radiusKm, 25);
    assert.equal(parsed.notifications.activity, true);
  });

  it("rejects unsupported versions and unknown goals", () => {
    assert.throws(
      () => parseOnboardingDraft({...validDraft(), version: 2}),
      (error) => error.code === "invalid-argument",
    );
    assert.throws(
      () => parseOnboardingDraft({...validDraft(), goals: ["become_invisible"]}),
      (error) => error.code === "invalid-argument",
    );
  });

  it("rejects invalid coordinates and oversized sport selections", () => {
    assert.throws(
      () => parseOnboardingDraft({
        ...validDraft(),
        location: {latitude: 91, longitude: 35},
      }),
      (error) => error.code === "invalid-argument",
    );
    assert.throws(
      () => parseOnboardingDraft({
        ...validDraft(),
        favoriteSportIds: Array.from({length: 9}, (_, index) => `sport-${index}`),
      }),
      (error) => error.code === "invalid-argument",
    );
  });
});
