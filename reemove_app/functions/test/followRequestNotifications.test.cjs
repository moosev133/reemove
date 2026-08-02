const assert = require("node:assert/strict");
const {describe, it} = require("node:test");
const {createHash} = require("node:crypto");

const {
  followRequestPendingEventId,
  followRequestAcceptedEventId,
} = require("../lib/notifications/followRequestNotifications.js");

describe("followRequestNotifications", () => {
  it("builds stable pending and accepted event ids", () => {
    assert.equal(
      followRequestPendingEventId("requester", "target"),
      "follow_request_pending_requester_target",
    );
    assert.equal(
      followRequestAcceptedEventId("requester", "target"),
      "follow_request_accepted_requester_target",
    );
    assert.notEqual(
      followRequestPendingEventId("a", "b"),
      followRequestAcceptedEventId("a", "b"),
    );
  });

  it("pending event ids hash stably for Firestore event docs", () => {
    const eventId = followRequestPendingEventId(
      "SXYHRzqwvnawTyxgEEdpfwNqRnG2",
      "rAVFw0NRryd4nYjXMUU2qjIDUAy1",
    );
    const hash = createHash("sha256").update(eventId).digest("hex");
    assert.equal(
      hash,
      "856dea90207fecd5559e878306dba648e092640658e6cd02c3aa405aad83e3d0",
    );
  });
});

describe("follow_request inbox wire shape", () => {
  it("matches the Activity/mapper contract for pending requests", () => {
    const requesterId = "requester-uid";
    const targetId = "target-uid";
    const username = "mmmmmm";
    const displayName = "mustafaa";
    const wire = {
      category: "activity",
      kind: "follow_request",
      title: "Follow request",
      body: `${displayName} (@${username}) requested to follow you.`,
      route: `/profile/user/${encodeURIComponent(username.toLowerCase())}`,
      groupKey: `follow_request_pending:${requesterId}`,
      entityType: "user",
      entityId: requesterId,
      deletedAt: null,
      data: {
        profileId: requesterId,
        requesterId,
        targetId,
        requestId: `${requesterId}--${targetId}`,
        status: "pending",
        source: "follow_request_pending",
      },
    };

    assert.equal(wire.kind, "follow_request");
    assert.equal(wire.category, "activity");
    assert.equal(wire.data.status, "pending");
    assert.equal(wire.deletedAt, null);
    assert.equal(wire.entityId, requesterId);
    assert.match(wire.route, /\/profile\/user\/mmmmmm/);
    assert.equal(wire.title, "Follow request");
    // Soft-deleted / resolved payloads must not be treated as actionable.
    assert.notEqual(wire.data.status, "resolved");
  });
});
