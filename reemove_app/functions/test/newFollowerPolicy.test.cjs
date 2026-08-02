const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  shouldDeliverNewFollowerNotification,
  isConfirmedNewFollowerPayload,
} = require("../lib/notifications/newFollowerPolicy.js");

describe("newFollowerPolicy", () => {
  it("allows only public direct_follow edges", () => {
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "direct_follow",
        accountPrivacy: "public",
        followApprovalPolicy: "automatic",
      }),
      true,
    );
  });

  it("rejects accepted private follow request edges", () => {
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "accepted_follow_request",
        accountPrivacy: "private",
        followApprovalPolicy: "approvalRequired",
      }),
      false,
    );
  });

  it("rejects private / ownerOnly accounts even with direct_follow source", () => {
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "direct_follow",
        accountPrivacy: "private",
      }),
      false,
    );
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "direct_follow",
        accountPrivacy: "ownerOnly",
      }),
      false,
    );
  });

  it("rejects public accounts that still require approval", () => {
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "direct_follow",
        accountPrivacy: "public",
        followApprovalPolicy: "approvalRequired",
      }),
      false,
    );
  });

  it("rejects missing or unknown edge sources", () => {
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "",
        accountPrivacy: "public",
      }),
      false,
    );
    assert.equal(
      shouldDeliverNewFollowerNotification({
        edgeSource: "legacy",
        accountPrivacy: "public",
      }),
      false,
    );
  });

  it("requires confirmed direct_follow payload for client-safe New follower", () => {
    assert.equal(
      isConfirmedNewFollowerPayload({
        relationshipStatus: "confirmed",
        source: "direct_follow",
        status: "confirmed",
      }),
      true,
    );
    assert.equal(
      isConfirmedNewFollowerPayload({
        relationshipStatus: "confirmed",
        source: "accepted_follow_request",
      }),
      false,
    );
    assert.equal(
      isConfirmedNewFollowerPayload({
        relationshipStatus: "confirmed",
        source: "direct_follow",
        status: "orphaned",
      }),
      false,
    );
    assert.equal(
      isConfirmedNewFollowerPayload({
        relationshipStatus: "confirmed",
      }),
      false,
    );
  });
});
