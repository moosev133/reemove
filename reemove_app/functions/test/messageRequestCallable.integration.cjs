const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  baseProfile,
  callableFor,
  createBlock,
  ensureAuthUser,
  establishFollowing,
  expectCallableError,
  initAdmin,
  seedProfile,
  signInClient,
  updateProfilePayload,
} = require("./helpers/emulatorHarness.cjs");

const {auth, db} = initAdmin();

async function provisionUser(uid, profileOverrides = {}, claims) {
  const email = `${uid}@msgreq.test`;
  await ensureAuthUser(auth, {uid, email, claims});
  const profile = baseProfile(uid, profileOverrides);
  await seedProfile(db, profile);
  const client = await signInClient(email);
  return {uid, email, profile, client};
}

async function setMessagingPrivacy(user, {
  messageAudience = "noOne",
  messageRequestAudience = "everyone",
} = {}) {
  const updateProfile = callableFor(user.client.functions, "updateProfile");
  await updateProfile(updateProfilePayload(user.profile, "public", {
    messageAudience,
    messageRequestAudience,
  }));
}

describe("message request callable emulator integration", () => {
  it("createMessageRequest stores pending request and inbox notification", async () => {
    const target = await provisionUser("mr-target", {
      username: "mr.target",
      usernameNormalized: "mr.target",
    });
    const requester = await provisionUser("mr-requester", {
      username: "mr.requester",
      usernameNormalized: "mr.requester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });

    const createMessageRequest = callableFor(
      requester.client.functions,
      "createMessageRequest",
    );
    const response = await createMessageRequest({targetUserId: target.uid});
    assert.equal(response.data.status, "pending");
    assert.equal(response.data.created, true);

    const requestId = `${requester.uid}--${target.uid}`;
    const requestDoc = await db.collection("message_requests").doc(requestId).get();
    assert.equal(requestDoc.exists, true);
    assert.equal(requestDoc.get("status"), "pending");
    assert.equal(requestDoc.get("requesterId"), requester.uid);
    assert.equal(requestDoc.get("targetId"), target.uid);

    const notifications = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "message_request")
      .limit(10)
      .get();
    assert.ok(notifications.size >= 1);
    const pending = notifications.docs.find(
      (doc) => doc.get("entityId") === requester.uid,
    );
    assert.ok(pending);
    assert.equal(pending.get("category"), "activity");
    assert.equal(pending.get("data")?.status, "pending");
  });

  it("duplicate createMessageRequest does not create a second pending request", async () => {
    const target = await provisionUser("mr-dup-target", {
      username: "mr.duptarget",
      usernameNormalized: "mr.duptarget",
    });
    const requester = await provisionUser("mr-dup-requester", {
      username: "mr.duprequester",
      usernameNormalized: "mr.duprequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });
    const createMessageRequest = callableFor(
      requester.client.functions,
      "createMessageRequest",
    );
    const first = await createMessageRequest({targetUserId: target.uid});
    const second = await createMessageRequest({targetUserId: target.uid});
    assert.equal(first.data.created, true);
    assert.equal(second.data.existingRequest, true);
    assert.equal(second.data.created, false);

    const requests = await db.collection("message_requests")
      .where("requesterId", "==", requester.uid)
      .where("targetId", "==", target.uid)
      .get();
    assert.equal(requests.size, 1);
  });

  it("accept creates conversation and notifies requester", async () => {
    const target = await provisionUser("mr-accept-target", {
      username: "mr.accepttarget",
      usernameNormalized: "mr.accepttarget",
    });
    const requester = await provisionUser("mr-accept-requester", {
      username: "mr.acceptrequester",
      usernameNormalized: "mr.acceptrequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });
    await callableFor(requester.client.functions, "createMessageRequest")({
      targetUserId: target.uid,
    });

    const respond = callableFor(
      target.client.functions,
      "respondToMessageRequest",
    );
    const response = await respond({
      requesterId: requester.uid,
      decision: "accept",
    });
    assert.equal(response.data.decision, "accept");
    assert.ok(typeof response.data.conversationId === "string");
    assert.ok(response.data.conversationId.length > 0);

    const requestDoc = await db.collection("message_requests")
      .doc(`${requester.uid}--${target.uid}`).get();
    assert.equal(requestDoc.exists, false);

    const conversation = await db.collection("conversations")
      .doc(response.data.conversationId).get();
    assert.equal(conversation.exists, true);

    const acceptedNotifs = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .where("kind", "==", "message_request_accepted")
      .limit(5)
      .get();
    assert.ok(acceptedNotifs.size >= 1);
  });

  it("decline removes request without notifying requester", async () => {
    const target = await provisionUser("mr-decline-target", {
      username: "mr.declinetarget",
      usernameNormalized: "mr.declinetarget",
    });
    const requester = await provisionUser("mr-decline-requester", {
      username: "mr.declinerequester",
      usernameNormalized: "mr.declinerequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });
    await callableFor(requester.client.functions, "createMessageRequest")({
      targetUserId: target.uid,
    });

    const respond = callableFor(
      target.client.functions,
      "respondToMessageRequest",
    );
    const response = await respond({
      requesterId: requester.uid,
      decision: "decline",
    });
    assert.equal(response.data.decision, "decline");
    assert.equal(response.data.conversationId, null);

    const requestDoc = await db.collection("message_requests")
      .doc(`${requester.uid}--${target.uid}`).get();
    assert.equal(requestDoc.exists, false);

    const requesterNotifs = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .where("kind", "in", ["message_request_accepted", "message_request"])
      .limit(10)
      .get();
    assert.equal(requesterNotifs.size, 0);
  });

  it("createMessageRequest is denied when request audience is noOne", async () => {
    const target = await provisionUser("mr-deny-target", {
      username: "mr.denytarget",
      usernameNormalized: "mr.denytarget",
    });
    const requester = await provisionUser("mr-deny-requester", {
      username: "mr.denyrequester",
      usernameNormalized: "mr.denyrequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "noOne",
    });
    await expectCallableError(
      callableFor(requester.client.functions, "createMessageRequest")({
        targetUserId: target.uid,
      }),
      "permission-denied",
    );
  });

  it("followers-only request audience allows followers and denies strangers", async () => {
    const target = await provisionUser("mr-fol-target", {
      username: "mr.foltarget",
      usernameNormalized: "mr.foltarget",
    });
    const follower = await provisionUser("mr-fol-follower", {
      username: "mr.folfollower",
      usernameNormalized: "mr.folfollower",
    });
    const stranger = await provisionUser("mr-fol-stranger", {
      username: "mr.folstranger",
      usernameNormalized: "mr.folstranger",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "followers",
    });
    await establishFollowing(follower, target);

    await expectCallableError(
      callableFor(stranger.client.functions, "createMessageRequest")({
        targetUserId: target.uid,
      }),
      "permission-denied",
    );

    const allowed = await callableFor(
      follower.client.functions,
      "createMessageRequest",
    )({targetUserId: target.uid});
    assert.equal(allowed.data.status, "pending");
  });

  it("blocked users cannot create message requests", async () => {
    const target = await provisionUser("mr-block-target", {
      username: "mr.blocktarget",
      usernameNormalized: "mr.blocktarget",
    });
    const blocked = await provisionUser("mr-block-user", {
      username: "mr.blockuser",
      usernameNormalized: "mr.blockuser",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });
    await createBlock(db, target.uid, blocked.uid);

    await expectCallableError(
      callableFor(blocked.client.functions, "createMessageRequest")({
        targetUserId: target.uid,
      }),
      "failed-precondition",
    );
  });

  it("block purges pending message requests both directions", async () => {
    const target = await provisionUser("mr-purge-target", {
      username: "mr.purgetarget",
      usernameNormalized: "mr.purgetarget",
    });
    const requester = await provisionUser("mr-purge-requester", {
      username: "mr.purgerequester",
      usernameNormalized: "mr.purgerequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });
    await callableFor(requester.client.functions, "createMessageRequest")({
      targetUserId: target.uid,
    });
    const requestId = `${requester.uid}--${target.uid}`;
    assert.equal(
      (await db.collection("message_requests").doc(requestId).get()).exists,
      true,
    );

    await callableFor(target.client.functions, "blockUser")({
      targetUserId: requester.uid,
    });

    assert.equal(
      (await db.collection("message_requests").doc(requestId).get()).exists,
      false,
    );
  });

  it("relationship exposes canRequestMessage and pending status", async () => {
    const target = await provisionUser("mr-rel-target", {
      username: "mr.reltarget",
      usernameNormalized: "mr.reltarget",
    });
    const requester = await provisionUser("mr-rel-requester", {
      username: "mr.relrequester",
      usernameNormalized: "mr.relrequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "noOne",
      messageRequestAudience: "everyone",
    });

    const getPublicProfile = callableFor(
      requester.client.functions,
      "getPublicProfile",
    );
    const before = await getPublicProfile({username: target.profile.username});
    assert.equal(before.data.relationship.canMessage, false);
    assert.equal(before.data.relationship.canRequestMessage, true);
    assert.equal(before.data.relationship.messageRequestStatus, null);

    await callableFor(requester.client.functions, "createMessageRequest")({
      targetUserId: target.uid,
    });
    const after = await getPublicProfile({username: target.profile.username});
    assert.equal(after.data.relationship.messageRequestStatus, "pending");
    assert.equal(after.data.relationship.canRequestMessage, true);
  });

  it("direct messageAudience everyone opens conversation without request", async () => {
    const target = await provisionUser("mr-direct-target", {
      username: "mr.directtarget",
      usernameNormalized: "mr.directtarget",
    });
    const requester = await provisionUser("mr-direct-requester", {
      username: "mr.directrequester",
      usernameNormalized: "mr.directrequester",
    });
    await setMessagingPrivacy(target, {
      messageAudience: "everyone",
      messageRequestAudience: "everyone",
    });
    const response = await callableFor(
      requester.client.functions,
      "createMessageRequest",
    )({targetUserId: target.uid});
    assert.equal(response.data.direct, true);
    assert.ok(typeof response.data.conversationId === "string");
    assert.equal(
      (await db.collection("message_requests")
        .doc(`${requester.uid}--${target.uid}`).get()).exists,
      false,
    );
  });
});
