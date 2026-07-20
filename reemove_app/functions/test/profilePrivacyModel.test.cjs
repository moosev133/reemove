const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  accountPrivacyFromLegacyVisibility,
  buildPublicProfileCallableResponse,
  legacyVisibilityForAccountPrivacy,
  resolveAccountPrivacy,
  viewerCanViewAuthorContent,
  viewerCanViewContent,
  viewerCanViewFullAccount,
} = require("../lib/profile/profilePrivacyModel.js");

describe("profile privacy model", () => {
  it("maps legacy visibility to account privacy", () => {
    assert.equal(accountPrivacyFromLegacyVisibility("public"), "public");
    assert.equal(accountPrivacyFromLegacyVisibility("followers"), "private");
    assert.equal(accountPrivacyFromLegacyVisibility("private"), "ownerOnly");
  });

  it("maps account privacy back to legacy visibility storage", () => {
    assert.equal(legacyVisibilityForAccountPrivacy("public"), "public");
    assert.equal(legacyVisibilityForAccountPrivacy("private"), "followers");
    assert.equal(legacyVisibilityForAccountPrivacy("ownerOnly"), "private");
  });

  it("allows approved followers on private accounts but denies strangers", () => {
    assert.equal(
      viewerCanViewFullAccount("private", false, true),
      true,
    );
    assert.equal(
      viewerCanViewFullAccount("private", false, false),
      false,
    );
  });

  it("denies followers on owner-only accounts", () => {
    assert.equal(
      viewerCanViewFullAccount("ownerOnly", false, true),
      false,
    );
    assert.equal(
      viewerCanViewFullAccount("ownerOnly", true, false),
      true,
    );
  });

  it("does not expose owner-only content to followers", () => {
    assert.equal(viewerCanViewContent("private", false, true), false);
    assert.equal(viewerCanViewContent("followers", false, true), true);
    assert.equal(viewerCanViewContent("public", false, false), true);
  });

  it("requires account access before public content visibility", () => {
    assert.equal(
      viewerCanViewAuthorContent("private", "public", false, false),
      false,
    );
    assert.equal(
      viewerCanViewAuthorContent("private", "public", false, true),
      true,
    );
    assert.equal(
      viewerCanViewAuthorContent("private", "followers", false, true),
      true,
    );
    assert.equal(
      viewerCanViewAuthorContent("public", "public", false, false),
      true,
    );
    assert.equal(
      viewerCanViewAuthorContent("ownerOnly", "public", false, true),
      false,
    );
  });

  it("prefers explicit accountPrivacy when present", () => {
    const privacy = resolveAccountPrivacy({
      accountPrivacy: "private",
      visibility: "public",
    });
    assert.equal(privacy, "private");
  });
});

describe("getPublicProfile callable contract", () => {
  const relationship = {viewerId: "a", profileId: "b", state: "none"};
  const preview = {uid: "b", username: "athlete", displayName: "Athlete"};
  const profile = {...preview, bio: "Hello"};

  it("returns full profile payload for authorized viewers", () => {
    const response = buildPublicProfileCallableResponse({
      access: "full",
      profile,
      relationship,
    });
    assert.equal(response.access, "full");
    assert.deepEqual(response.profile, profile);
    assert.equal(response.preview, undefined);
  });

  it("returns preview plus legacy profile mirror for strangers", () => {
    const response = buildPublicProfileCallableResponse({
      access: "preview",
      preview,
      relationship,
    });
    assert.equal(response.access, "preview");
    assert.deepEqual(response.preview, preview);
    assert.deepEqual(response.profile, preview);
  });
});
