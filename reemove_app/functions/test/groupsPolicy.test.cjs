const test = require("node:test");
const assert = require("node:assert/strict");

const {
  canRemoveMember,
  groupChannelContracts,
  normalizeJoinPolicy,
  nextMemberCount,
  parseCreateGroupInput,
  isManagerRole,
} = require("../lib/groups/groupsPolicy");

test("normalizeJoinPolicy forces inviteOnly for hidden groups", () => {
  assert.equal(normalizeJoinPolicy("hidden", "open"), "inviteOnly");
  assert.equal(normalizeJoinPolicy("hidden", "approvalRequired"), "inviteOnly");
});

test("normalizeJoinPolicy upgrades private open to approvalRequired", () => {
  assert.equal(normalizeJoinPolicy("private", "open"), "approvalRequired");
  assert.equal(normalizeJoinPolicy("private", "inviteOnly"), "inviteOnly");
  assert.equal(normalizeJoinPolicy("public", "open"), "open");
});

test("canRemoveMember permission matrix", () => {
  assert.equal(canRemoveMember("owner", "admin"), true);
  assert.equal(canRemoveMember("owner", "member"), true);
  assert.equal(canRemoveMember("owner", "owner"), false);
  assert.equal(canRemoveMember("admin", "member"), true);
  assert.equal(canRemoveMember("admin", "admin"), false);
  assert.equal(canRemoveMember("admin", "owner"), false);
  assert.equal(canRemoveMember("member", "member"), false);
});

test("nextMemberCount never goes negative", () => {
  assert.equal(nextMemberCount(0, -1), 0);
  assert.equal(nextMemberCount(2, -1), 1);
  assert.equal(nextMemberCount(1, 1), 2);
});

test("isManagerRole", () => {
  assert.equal(isManagerRole("owner"), true);
  assert.equal(isManagerRole("admin"), true);
  assert.equal(isManagerRole("member"), false);
});

test("parseCreateGroupInput defaults and validation", () => {
  const parsed = parseCreateGroupInput({
    name: "Trail Crew",
    description: "Weekend runs",
    category: "running",
    privacy: "public",
    location: {locality: "Haifa", countryCode: "IL"},
  });
  assert.equal(parsed.joinPolicy, "open");
  assert.equal(parsed.name, "Trail Crew");
  assert.equal(parsed.location.locality, "Haifa");

  assert.throws(
    () => parseCreateGroupInput({name: "", description: "x", category: "running"}),
    (error) => String(error.message || error).toLowerCase().includes("name"),
  );
});

test("groupChannelContracts expose C1 media modes including view_once", () => {
  const contracts = groupChannelContracts();
  assert.equal(contracts.length, 2);
  const chat = contracts.find((c) => c.type === "member_chat");
  assert.ok(chat.supportedMediaModes.includes("view_once"));
  assert.ok(chat.supportedMediaModes.includes("keep_in_chat"));
  assert.ok(chat.supportedMediaModes.includes("normal"));
  const announcements = contracts.find((c) => c.type === "announcements");
  assert.deepEqual(announcements.publishRoles, ["owner", "admin"]);
});
