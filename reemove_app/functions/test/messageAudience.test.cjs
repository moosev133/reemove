const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  isMessageAudienceAllowed,
} = require("../lib/messaging/messageAudiencePolicy.js");

describe("messageAudience gate", () => {
  it("allows everyone including non-followers", () => {
    assert.equal(isMessageAudienceAllowed("everyone", false), true);
    assert.equal(isMessageAudienceAllowed("everyone", true), true);
  });

  it("requires sender to follow target when audience is followers", () => {
    assert.equal(isMessageAudienceAllowed("followers", false), false);
    assert.equal(isMessageAudienceAllowed("followers", true), true);
  });

  it("denies all senders when audience is noOne", () => {
    assert.equal(isMessageAudienceAllowed("noOne", false), false);
    assert.equal(isMessageAudienceAllowed("noOne", true), false);
  });

  it("treats unknown audience as allow for legacy-safe defaults", () => {
    assert.equal(isMessageAudienceAllowed("legacy", false), true);
  });
});
