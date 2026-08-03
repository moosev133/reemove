const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {safeProfilePreview, canViewConnectionLists} =
  require("../lib/profile/privacyEnforcement.js");
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
  it("builds a sanitized preview payload with public fields and counts", () => {
    const preview = safeProfilePreview(profileDoc("user-1", {
      username: "athlete",
      usernameNormalized: "athlete",
      displayName: "Athlete One",
      bio: "Runner and climber",
      avatarUrl: "https://cdn.example/avatar.jpg",
      visibility: "followers",
      isVerified: true,
      verificationType: "athlete",
      followersCount: 12,
      followingCount: 4,
      postsCount: 8,
      reelsCount: 2,
      followApprovalPolicy: "approvalRequired",
      schemaVersion: 2,
      createdAt: {
        toDate() {
          return new Date("2026-01-01T00:00:00.000Z");
        },
      },
      updatedAt: {
        toDate() {
          return new Date("2026-01-02T00:00:00.000Z");
        },
      },
      email: "secret@example.com",
      phoneNumber: "+10000000000",
    }));

    assert.equal(preview.uid, "user-1");
    assert.equal(preview.accountPrivacy, "private");
    assert.equal(preview.visibility, "followers");
    assert.equal(preview.usernameNormalized, "athlete");
    assert.equal(preview.bio, "Runner and climber");
    assert.equal(preview.followersCount, 12);
    assert.equal(preview.followingCount, 4);
    assert.equal(preview.postsCount, 8);
    assert.equal(preview.reelsCount, 2);
    assert.equal(preview.createdAt, "2026-01-01T00:00:00.000Z");
    assert.equal(preview.updatedAt, "2026-01-02T00:00:00.000Z");
    assert.equal(preview.email, undefined);
    assert.equal(preview.phoneNumber, undefined);
  });

  it("allows public accounts and approved followers on private accounts", () => {
    assert.equal(viewerCanViewFullAccount("public", false, false), true);
    assert.equal(viewerCanViewFullAccount("private", false, false), false);
    assert.equal(viewerCanViewFullAccount("private", false, true), true);
    assert.equal(viewerCanViewFullAccount("ownerOnly", true, false), true);
  });

  it("enforces follower-list audience rules", () => {
    assert.equal(
      canViewConnectionLists("viewer", "owner", "everyone", false, false),
      true,
    );
    assert.equal(
      canViewConnectionLists("viewer", "owner", "owner", true, false),
      false,
    );
    assert.equal(
      canViewConnectionLists("owner", "owner", "owner", true, false),
      true,
    );
    assert.equal(
      canViewConnectionLists("viewer", "owner", "followers", false, true),
      true,
    );
    assert.equal(
      canViewConnectionLists("viewer", "owner", "followers", true, false),
      false,
    );
  });
});
