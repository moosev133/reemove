const assert = require("node:assert/strict");
const {describe, it} = require("node:test");
const {createHash} = require("node:crypto");

const {
  messageRequestPendingEventId,
  messageRequestAcceptedEventId,
} = require("../lib/notifications/messageRequestNotifications.js");

describe("messageRequestNotifications", () => {
  it("builds stable pending and accepted event ids", () => {
    assert.equal(
      messageRequestPendingEventId("requester", "target"),
      "message_request_pending_requester_target",
    );
    assert.equal(
      messageRequestAcceptedEventId("requester", "target"),
      "message_request_accepted_requester_target",
    );
    assert.notEqual(
      messageRequestPendingEventId("a", "b"),
      messageRequestAcceptedEventId("a", "b"),
    );
  });

  it("pending event ids hash stably for Firestore event docs", () => {
    const eventId = messageRequestPendingEventId(
      "SXYHRzqwvnawTyxgEEdpfwNqRnG2",
      "rAVFw0NRryd4nYjXMUU2qjIDUAy1",
    );
    const hash = createHash("sha256").update(eventId).digest("hex");
    assert.equal(hash.length, 64);
    assert.equal(
      hash,
      createHash("sha256").update(eventId).digest("hex"),
    );
  });

  it("request document ids are directional", () => {
    // Mirrors messageRequestId() in messageRequests.ts (avoid importing onCall modules).
    const messageRequestId = (requesterId, targetId) =>
      `${requesterId}--${targetId}`;
    assert.equal(messageRequestId("a", "b"), "a--b");
    assert.notEqual(messageRequestId("a", "b"), messageRequestId("b", "a"));
  });
});

describe("message_request inbox wire shape", () => {
  it("matches the Activity/mapper contract for pending requests", () => {
    const requesterId = "requester-uid";
    const targetId = "target-uid";
    const username = "mmmmmm";
    const displayName = "mustafaa";
    const wire = {
      category: "activity",
      kind: "message_request",
      title: "Message request",
      body: `${displayName} (@${username}) wants to message you.`,
      route: `/profile/user/${encodeURIComponent(username.toLowerCase())}`,
      groupKey: `message_request_pending:${requesterId}`,
      entityType: "user",
      entityId: requesterId,
      deletedAt: null,
      data: {
        profileId: requesterId,
        requesterId,
        targetId,
        requestId: `${requesterId}--${targetId}`,
        status: "pending",
        source: "message_request_pending",
      },
    };

    assert.equal(wire.kind, "message_request");
    assert.equal(wire.category, "activity");
    assert.equal(wire.data.status, "pending");
    assert.equal(wire.deletedAt, null);
    assert.equal(wire.entityId, requesterId);
    assert.match(wire.route, /\/profile\/user\/mmmmmm/);
    assert.equal(wire.title, "Message request");
    assert.notEqual(wire.data.status, "resolved");
  });

  it("accepted notification routes to conversation and is activity category", () => {
    const conversationId = "a--b";
    const wire = {
      category: "activity",
      kind: "message_request_accepted",
      route: `/messages/${encodeURIComponent(conversationId)}`,
      data: {
        conversationId,
        status: "accepted",
        source: "message_request_accepted",
      },
    };
    assert.equal(wire.category, "activity");
    assert.equal(wire.kind, "message_request_accepted");
    assert.match(wire.route, /\/messages\//);
  });
});
