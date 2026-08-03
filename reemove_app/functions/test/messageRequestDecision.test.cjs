const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  isMessageAudienceAllowed,
} = require("../lib/messaging/messageAudiencePolicy.js");

describe("message request vs direct decision matrix", () => {
  function outcome({
    directAudience,
    requestAudience,
    isFollower,
  }) {
    const canDirect = isMessageAudienceAllowed(directAudience, isFollower);
    if (canDirect) return "direct";
    const canRequest = isMessageAudienceAllowed(requestAudience, isFollower);
    if (canRequest) return "request";
    return "deny";
  }

  it("direct everyone skips requests", () => {
    assert.equal(
      outcome({
        directAudience: "everyone",
        requestAudience: "everyone",
        isFollower: false,
      }),
      "direct",
    );
  });

  it("followers-only direct with everyone request allows stranger request", () => {
    assert.equal(
      outcome({
        directAudience: "followers",
        requestAudience: "everyone",
        isFollower: false,
      }),
      "request",
    );
  });

  it("follower gets direct when audience is followers", () => {
    assert.equal(
      outcome({
        directAudience: "followers",
        requestAudience: "everyone",
        isFollower: true,
      }),
      "direct",
    );
  });

  it("noOne direct + noOne request denies", () => {
    assert.equal(
      outcome({
        directAudience: "noOne",
        requestAudience: "noOne",
        isFollower: true,
      }),
      "deny",
    );
  });

  it("noOne direct + followers request allows follower request only", () => {
    assert.equal(
      outcome({
        directAudience: "noOne",
        requestAudience: "followers",
        isFollower: false,
      }),
      "deny",
    );
    assert.equal(
      outcome({
        directAudience: "noOne",
        requestAudience: "followers",
        isFollower: true,
      }),
      "request",
    );
  });
});
