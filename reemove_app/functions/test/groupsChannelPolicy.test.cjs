const test = require("node:test");
const assert = require("node:assert/strict");

const {
  groupChannelContracts,
  groupMediaModes,
  isManagerRole,
} = require("../lib/groups/groupsPolicy");

const {
  parseGroupMediaMode,
  groupChannelStoragePrefix,
  isGroupChannelStoragePath,
  assertCanPublishInSportsChannel,
  sportsManagerCanModerate,
} = require("../lib/groups/groupChannelAccess");

const {
  channelSyncBatchSize,
  sportsGroupConversationSource,
} = require("../lib/groups/groupChannels");

const {
  viewOnceSignedUrlTtlMs,
  abandonedGroupMediaHours,
} = require("../lib/groups/groupMedia");

test("group channel contracts keep announcements without view_once", () => {
  const contracts = groupChannelContracts();
  const chat = contracts.find((c) => c.type === "member_chat");
  const announcements = contracts.find((c) => c.type === "announcements");
  assert.ok(chat.supportedMediaModes.includes("view_once"));
  assert.equal(announcements.supportedMediaModes.includes("view_once"), false);
  assert.deepEqual(announcements.publishRoles, ["owner", "admin"]);
  assert.deepEqual(groupMediaModes, ["normal", "keep_in_chat", "view_once"]);
});

test("parseGroupMediaMode defaults and rejects invalid", () => {
  assert.equal(parseGroupMediaMode(undefined), "normal");
  assert.equal(parseGroupMediaMode("keep_in_chat"), "keep_in_chat");
  assert.equal(parseGroupMediaMode("view_once"), "view_once");
  assert.throws(() => parseGroupMediaMode("forever"), (error) =>
    String(error.message || error).toLowerCase().includes("mediamode"),
  );
});

test("group channel storage paths are scoped", () => {
  const prefix = groupChannelStoragePrefix("g1", "member_chat", "m1", "a1");
  assert.equal(prefix, "groups/g1/channels/member_chat/m1/a1");
  assert.equal(
    isGroupChannelStoragePath(
      "groups/g1/channels/member_chat/m1/a1/photo.jpg",
      "g1",
      "member_chat",
      "m1",
      "a1",
    ),
    true,
  );
  assert.equal(
    isGroupChannelStoragePath(
      "messages/c1/m1/a1/photo.jpg",
      "g1",
      "member_chat",
      "m1",
      "a1",
    ),
    false,
  );
});

test("assertCanPublishInSportsChannel enforces announcement roles and modes", () => {
  assert.doesNotThrow(() =>
    assertCanPublishInSportsChannel("member_chat", "member", "view_once"),
  );
  assert.throws(
    () => assertCanPublishInSportsChannel("announcements", "member", "normal"),
    (error) => String(error.message || error).toLowerCase().includes("publish"),
  );
  assert.throws(
    () => assertCanPublishInSportsChannel("announcements", "admin", "view_once"),
    (error) => String(error.message || error).toLowerCase().includes("media"),
  );
  assert.doesNotThrow(() =>
    assertCanPublishInSportsChannel("announcements", "owner", "normal"),
  );
});

test("sportsManagerCanModerate maps owner/admin", () => {
  assert.equal(sportsManagerCanModerate("owner"), true);
  assert.equal(sportsManagerCanModerate("admin"), true);
  assert.equal(sportsManagerCanModerate("member"), false);
  assert.equal(sportsManagerCanModerate(null), false);
  assert.equal(isManagerRole("owner"), true);
});

test("channel sync constants", () => {
  assert.equal(sportsGroupConversationSource, "sports_group");
  assert.ok(channelSyncBatchSize <= 400);
  assert.equal(viewOnceSignedUrlTtlMs, 60_000);
  assert.equal(abandonedGroupMediaHours, 24);
});
