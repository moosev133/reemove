const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {safeProfilePreview} = require("../lib/profile/privacyEnforcement.js");
const {
  viewerCanViewFullAccount,
} = require("../lib/profile/profilePrivacyModel.js");

function profileDoc(id, data) {
  return {
    id,
    exists: true,
    get(field) {
      return data[field];
    },
  };
}

describe("privacy enforcement helpers", () => {
  it("builds a minimal preview payload", () => {
    const preview = safeProfilePreview(profileDoc("user-1", {
      username: "athlete",
      displayName: "Athlete One",
      avatarUrl: "https://cdn.example/avatar.jpg",
      visibility: "followers",
      isVerified: true,
      verificationType: "athlete",
    }));

    assert.equal(preview.uid, "user-1");
    assert.equal(preview.accountPrivacy, "private");
    assert.equal(preview.visibility, "followers");
  });

  it("allows public accounts and approved followers on private accounts", () => {
    assert.equal(viewerCanViewFullAccount("public", false, false), true);
    assert.equal(viewerCanViewFullAccount("private", false, false), false);
    assert.equal(viewerCanViewFullAccount("private", false, true), true);
    assert.equal(viewerCanViewFullAccount("ownerOnly", true, false), true);
  });
});
