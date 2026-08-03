const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  planPrivacyBackfillUpdates,
} = require("../lib/profile/profilePrivacyBackfill.js");

function doc(id, data) {
  return {
    id,
    get(field) {
      return data[field];
    },
  };
}

describe("profile privacy backfill planning", () => {
  it("preserves explicit visibility and accountPrivacy values", () => {
    const plan = planPrivacyBackfillUpdates(doc("user-1", {
      visibility: "private",
      accountPrivacy: "ownerOnly",
      followApprovalPolicy: "approvalRequired",
      visibilityRevision: 2,
    }));
    assert.equal(plan, null);
  });

  it("fills missing fields with safe defaults without overwriting visibility", () => {
    const plan = planPrivacyBackfillUpdates(doc("user-2", {
      visibility: "followers",
      followApprovalPolicy: "approvalRequired",
    }));
    assert.notEqual(plan, null);
    assert.equal(plan.updates.accountPrivacy, "private");
    assert.equal(plan.updates.visibility, undefined);
    assert.equal(plan.updates.visibilityRevision, 0);
  });

  it("defaults completely missing privacy fields to public account", () => {
    const plan = planPrivacyBackfillUpdates(doc("user-3", {}));
    assert.notEqual(plan, null);
    assert.equal(plan.updates.accountPrivacy, "public");
    assert.equal(plan.updates.visibility, "public");
    assert.equal(plan.updates.followApprovalPolicy, "automatic");
    assert.equal(plan.updates.visibilityRevision, 0);
  });

  it("derives accountPrivacy from legacy visibility when only visibility exists", () => {
    const plan = planPrivacyBackfillUpdates(doc("user-4", {
      visibility: "private",
    }));
    assert.notEqual(plan, null);
    assert.equal(plan.updates.accountPrivacy, "ownerOnly");
    assert.equal(plan.updates.visibility, undefined);
    assert.equal(plan.updates.followApprovalPolicy, "approvalRequired");
  });
});
