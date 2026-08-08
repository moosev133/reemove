const test = require("node:test");
const assert = require("node:assert/strict");

const {parseSendRequest} = require("../lib/messaging/requestData");

function baseSend(overrides = {}) {
  return {
    conversationId: "c1",
    clientMessageId: "m1",
    text: "hello",
    attachments: [],
    ...overrides,
  };
}

test("parseSendRequest defaults mediaMode to normal", () => {
  const parsed = parseSendRequest(baseSend());
  assert.equal(parsed.mediaMode, "normal");
});

test("parseSendRequest accepts keep_in_chat and view_once with attachments", () => {
  const keep = parseSendRequest(baseSend({
    text: "",
    mediaMode: "keep_in_chat",
    attachments: [{
      id: "a1",
      storagePath: "groups/g1/channels/member_chat/m1/a1/x.jpg",
      contentType: "image/jpeg",
      sizeBytes: 12,
      kind: "image",
    }],
  }));
  assert.equal(keep.mediaMode, "keep_in_chat");

  const viewOnce = parseSendRequest(baseSend({
    text: "",
    mediaMode: "view_once",
    attachments: [{
      id: "a1",
      storagePath: "groups/g1/channels/member_chat/m1/a1/x.jpg",
      contentType: "image/jpeg",
      sizeBytes: 12,
      kind: "image",
    }],
  }));
  assert.equal(viewOnce.mediaMode, "view_once");
});

test("parseSendRequest rejects view_once without attachments", () => {
  assert.throws(
    () => parseSendRequest(baseSend({mediaMode: "view_once", attachments: []})),
    (error) => String(error.message || error).toLowerCase().includes("view-once") ||
      String(error.message || error).toLowerCase().includes("attachment"),
  );
});

test("parseSendRequest rejects invalid mediaMode", () => {
  assert.throws(
    () => parseSendRequest(baseSend({mediaMode: "forever"})),
    (error) => String(error.message || error).toLowerCase().includes("mediamode"),
  );
});

test("parseSendRequest preserves replyTo with mediaMode", () => {
  const parsed = parseSendRequest(baseSend({
    replyToMessageId: "parent-1",
    mediaMode: "normal",
  }));
  assert.equal(parsed.replyToMessageId, "parent-1");
  assert.equal(parsed.mediaMode, "normal");
});
