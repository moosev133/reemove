const assert = require("node:assert/strict");
const {describe, it} = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");

const {
  assertCleanRelationshipState,
  assertNonNegativeCounters,
  assertRelationshipGraph,
  baseProfile,
  callableFor,
  callUnauthenticated,
  createBlock,
  ensureAuthUser,
  establishFollowing,
  expectCallableError,
  initAdmin,
  readRelationshipCounters,
  seedPost,
  seedProfile,
  seedStory,
  signedOutCallable,
  signInClient,
  updateProfilePayload,
} = require("./helpers/emulatorHarness.cjs");

const {auth, db} = initAdmin();

async function provisionUser(uid, profileOverrides = {}, claims) {
  const email = `${uid}@privacy.test`;
  await ensureAuthUser(auth, {uid, email, claims});
  const profile = baseProfile(uid, profileOverrides);
  await seedProfile(db, profile);
  const client = await signInClient(email);
  return {uid, email, profile, client};
}

describe("profile privacy callable emulator integration", () => {
  it("getPublicProfile returns full profile for public account", async () => {
    const target = await provisionUser("pp-public", {
      username: "pp.public",
      usernameNormalized: "pp.public",
    });
    const viewer = await provisionUser("pp-stranger", {
      username: "pp.stranger",
      usernameNormalized: "pp.stranger",
    });
    const getPublicProfile = callableFor(viewer.client.functions, "getPublicProfile");
    const response = await getPublicProfile({username: target.profile.username});
    const payload = response.data;
    assert.equal(payload.access, "full");
    assert.equal(payload.profile.uid, target.uid);
    assert.equal(payload.relationship.state, "none");
  });

  it("getPublicProfile returns preview for private account stranger", async () => {
    const target = await provisionUser("pp-private", {
      username: "pp.private",
      usernameNormalized: "pp.private",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const viewer = await provisionUser("pp-stranger2", {
      username: "pp.stranger2",
      usernameNormalized: "pp.stranger2",
    });
    const getPublicProfile = callableFor(viewer.client.functions, "getPublicProfile");
    const response = await getPublicProfile({username: target.profile.username});
    const payload = response.data;
    assert.equal(payload.access, "preview");
    assert.ok(payload.preview);
    assert.equal(payload.profile.uid, target.uid);
    assert.equal(payload.relationship.canViewProfile, false);
    assert.equal(payload.preview.username, target.profile.username);
    assert.equal(payload.preview.usernameNormalized, "pp.private");
    assert.equal(typeof payload.preview.displayName, "string");
    assert.equal(typeof payload.preview.bio, "string");
    assert.equal(typeof payload.preview.followersCount, "number");
    assert.equal(typeof payload.preview.followingCount, "number");
    assert.equal(typeof payload.preview.postsCount, "number");
    assert.equal(typeof payload.preview.createdAt, "string");
    assert.equal(typeof payload.preview.updatedAt, "string");
    assert.equal(payload.preview.email, undefined);
    assert.equal(payload.preview.phoneNumber, undefined);
    assert.equal(payload.preview.location, undefined);
  });

  it("followProfile creates an inbox notification for the private target", async () => {
    const target = await provisionUser("pp-notify-target", {
      username: "pp.notifytarget",
      usernameNormalized: "pp.notifytarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const requester = await provisionUser("pp-notify-requester", {
      username: "pp.notifyrequester",
      usernameNormalized: "pp.notifyrequester",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const followProfile = callableFor(requester.client.functions, "followProfile");
    const followResult = await followProfile({profileId: target.uid});
    assert.equal(followResult.data.state, "requestSent");

    const requestRef = db.collection("follow_requests")
      .doc(`${requester.uid}--${target.uid}`);
    const requestDoc = await requestRef.get();
    assert.equal(requestDoc.exists, true);
    assert.equal(requestDoc.get("status"), "pending");
    assert.equal(requestDoc.get("requesterId"), requester.uid);
    assert.equal(requestDoc.get("targetId"), target.uid);
    await assertRelationshipGraph(db, requester.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });

    // Allow trigger + callable delivery to settle.
    await new Promise((resolve) => setTimeout(resolve, 1500));
    const notifications = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request")
      .limit(5)
      .get();
    assert.ok(notifications.size >= 1, "expected follow_request notification");
    const notification = notifications.docs[0].data();
    assert.equal(notification.category, "activity");
    assert.equal(notification.entityId, requester.uid);
    assert.match(String(notification.route), /\/profile\/user\//);
    assert.equal(notification.data?.status, "pending");
    assert.equal(notification.data?.requestId, `${requester.uid}--${target.uid}`);
    assert.equal(notification.data?.source, "follow_request_pending");
    assert.equal(notification.title, "Follow request");
    assert.match(String(notification.body), /requested to follow you/);

    const newFollowerNotifs = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "new_follower")
      .get();
    assert.equal(
      newFollowerNotifs.size,
      0,
      "pending private request must not create a new_follower notification",
    );

    // Sender must never receive their own outbound follow-request notification.
    const requesterInbox = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request")
      .get();
    assert.equal(requesterInbox.size, 0);

    const summary = await db.doc(`users/${target.uid}/private/notification_summary`).get();
    assert.equal(summary.exists, true);
    assert.ok(Number(summary.get("unreadCount")) >= 1);

    const followAgain = await followProfile({profileId: target.uid});
    assert.equal(followAgain.data.state, "requestSent");
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const afterDuplicate = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request")
      .get();
    assert.equal(afterDuplicate.size, notifications.size);

    const listProfileConnections = callableFor(
      target.client.functions,
      "listProfileConnections",
    );
    const requests = await listProfileConnections({
      profileId: target.uid,
      type: "requests",
      limit: 10,
    });
    assert.ok(requests.data.items.some((item) => item.uid === requester.uid));
  });

  it("getPublicProfile keeps pending follow request as Requested preview", async () => {
    const target = await provisionUser("pp-private-req", {
      username: "pp.privatereq",
      usernameNormalized: "pp.privatereq",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const viewer = await provisionUser("pp-requester", {
      username: "pp.requester",
      usernameNormalized: "pp.requester",
    });
    const followProfile = callableFor(viewer.client.functions, "followProfile");
    const followResult = await followProfile({profileId: target.uid});
    assert.equal(followResult.data.state, "requestSent");
    const getPublicProfile = callableFor(viewer.client.functions, "getPublicProfile");
    const response = await getPublicProfile({username: "pp.privatereq"});
    assert.equal(response.data.access, "preview");
    assert.equal(response.data.relationship.state, "requestSent");
    assert.equal(response.data.relationship.canViewProfile, false);
  });

  it("approved follower receives authorized profile for private account", async () => {
    const target = await provisionUser("pp-private-owner", {
      username: "pp.privateowner",
      usernameNormalized: "pp.privateowner",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const follower = await provisionUser("pp-follower", {
      username: "pp.follower",
      usernameNormalized: "pp.follower",
    });
    await establishFollowing(follower, target);
    const getPublicProfile = callableFor(
      follower.client.functions,
      "getPublicProfile",
    );
    const response = await getPublicProfile({profileId: target.uid});
    const payload = response.data;
    assert.equal(payload.access, "full");
    assert.equal(payload.relationship.state, "following");
    assert.equal(payload.relationship.canViewProfile, true);
    await assertRelationshipGraph(db, follower.uid, target.uid, {
      connected: true,
      followerFollowingCount: 1,
      targetFollowersCount: 1,
    });
  });

  it("owner-only profile denies followers and strangers with preview only", async () => {
    const ownerOnly = await provisionUser("pp-owneronly", {
      username: "pp.owneronly",
      usernameNormalized: "pp.owneronly",
      visibility: "private",
      accountPrivacy: "ownerOnly",
      followApprovalPolicy: "approvalRequired",
    });
    const follower = await provisionUser("pp-owneronly-follower", {
      username: "pp.ownerfollower",
      usernameNormalized: "pp.ownerfollower",
    });
    await establishFollowing(follower, ownerOnly);
    const getPublicProfile = callableFor(
      follower.client.functions,
      "getPublicProfile",
    );
    const response = await getPublicProfile({profileId: ownerOnly.uid});
    assert.equal(response.data.access, "preview");
    assert.equal(response.data.relationship.canViewProfile, false);
  });

  it("blocked user receives unavailable result", async () => {
    const target = await provisionUser("pp-block-target", {
      username: "pp.blocktarget",
      usernameNormalized: "pp.blocktarget",
    });
    const viewer = await provisionUser("pp-block-viewer", {
      username: "pp.blockviewer",
      usernameNormalized: "pp.blockviewer",
    });
    await createBlock(db, target.uid, viewer.uid);
    const getPublicProfile = callableFor(viewer.client.functions, "getPublicProfile");
    await expectCallableError(
      getPublicProfile({profileId: target.uid}),
      "not-found",
    );
  });

  it("followProfile on public account creates following relationship", async () => {
    const target = await provisionUser("pp-follow-public-target", {
      username: "pp.fpubtarget",
      usernameNormalized: "pp.fpubtarget",
    });
    const viewer = await provisionUser("pp-follow-public-viewer", {
      username: "pp.fpubviewer",
      usernameNormalized: "pp.fpubviewer",
    });
    const followProfile = callableFor(viewer.client.functions, "followProfile");
    const response = await followProfile({profileId: target.uid});
    assert.equal(response.data.state, "following");
    assert.equal(response.data.canViewProfile, true);
    const edge = await db.doc(
      `users/${viewer.uid}/following/${target.uid}`,
    ).get();
    assert.equal(edge.exists, true);
    await assertRelationshipGraph(db, viewer.uid, target.uid, {
      connected: true,
      followerFollowingCount: 1,
      targetFollowersCount: 1,
    });
  });

  it("followProfile on private account creates pending request", async () => {
    const target = await provisionUser("pp-follow-private-target", {
      username: "pp.fprivtarget",
      usernameNormalized: "pp.fprivtarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const viewer = await provisionUser("pp-follow-private-viewer", {
      username: "pp.fprivviewer",
      usernameNormalized: "pp.fprivviewer",
    });
    const followProfile = callableFor(viewer.client.functions, "followProfile");
    const response = await followProfile({profileId: target.uid});
    assert.equal(response.data.state, "requestSent");
    const requestDoc = await db.collection("follow_requests")
      .doc(`${viewer.uid}--${target.uid}`)
      .get();
    assert.equal(requestDoc.exists, true);
    assert.equal(requestDoc.get("status"), "pending");
    await assertRelationshipGraph(db, viewer.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });
  });

  it("cancelFollowRequest removes pending request", async () => {
    const target = await provisionUser("pp-cancel-target", {
      username: "pp.canceltarget",
      usernameNormalized: "pp.canceltarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const viewer = await provisionUser("pp-cancel-viewer", {
      username: "pp.cancelviewer",
      usernameNormalized: "pp.cancelviewer",
    });
    const followProfile = callableFor(viewer.client.functions, "followProfile");
    await followProfile({profileId: target.uid});
    const cancelFollowRequest = callableFor(
      viewer.client.functions,
      "cancelFollowRequest",
    );
    const response = await cancelFollowRequest({profileId: target.uid});
    assert.equal(response.data.state, "none");
    const requestDoc = await db.collection("follow_requests")
      .doc(`${viewer.uid}--${target.uid}`)
      .get();
    assert.equal(requestDoc.exists, false);
    await assertRelationshipGraph(db, viewer.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });
  });

  it("respondToFollowRequest accepts pending request", async () => {
    const target = await provisionUser("pp-respond-target", {
      username: "pp.responsetarget",
      usernameNormalized: "pp.responsetarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const requester = await provisionUser("pp-respond-accept", {
      username: "pp.respondaccept",
      usernameNormalized: "pp.respondaccept",
    });
    const follow = await callableFor(
      requester.client.functions,
      "followProfile",
    )({profileId: target.uid});
    assert.equal(follow.data.state, "requestSent");
    const accepted = await callableFor(
      target.client.functions,
      "respondToFollowRequest",
    )({
      profileId: requester.uid,
      response: "accept",
    });
    assert.equal(accepted.data.state, "followedBy");
    assert.equal(accepted.data.viewerId, target.uid);
    assert.equal(accepted.data.profileId, requester.uid);
    const edge = await db.doc(
      `users/${requester.uid}/following/${target.uid}`,
    ).get();
    assert.equal(edge.exists, true);
    const reverseEdge = await db.doc(
      `users/${target.uid}/followers/${requester.uid}`,
    ).get();
    assert.equal(reverseEdge.exists, true);
    const requestDoc = await db.collection("follow_requests")
      .doc(`${requester.uid}--${target.uid}`)
      .get();
    assert.equal(requestDoc.exists, false);
    await assertRelationshipGraph(db, requester.uid, target.uid, {
      connected: true,
      followerFollowingCount: 1,
      targetFollowersCount: 1,
    });

    await new Promise((resolve) => setTimeout(resolve, 1000));
    const targetPending = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request")
      .get();
    const activePending = targetPending.docs.filter(
      (doc) => !(doc.get("deletedAt")),
    );
    assert.equal(activePending.length, 0);

    const acceptedNotifs = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request_accepted")
      .get();
    assert.equal(acceptedNotifs.size, 1);
    assert.equal(acceptedNotifs.docs[0].get("entityId"), target.uid);
    assert.equal(acceptedNotifs.docs[0].get("data")?.status, "accepted");
    assert.equal(
      acceptedNotifs.docs[0].get("data")?.requestId,
      `${requester.uid}--${target.uid}`,
    );

    const targetFollowerNotifs = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "new_follower")
      .get();
    assert.equal(
      targetFollowerNotifs.size,
      0,
      "accepting a private follow request must not notify the target as New follower",
    );
  });

  it("respondToFollowRequest declines pending request", async () => {
    const target = await provisionUser("pp-respond-decline-target", {
      username: "pp.respdeclinetarget",
      usernameNormalized: "pp.respdeclinetarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const requester = await provisionUser("pp-respond-decline", {
      username: "pp.responddecline",
      usernameNormalized: "pp.responddecline",
    });
    await callableFor(
      requester.client.functions,
      "followProfile",
    )({profileId: target.uid});
    const declined = await callableFor(
      target.client.functions,
      "respondToFollowRequest",
    )({
      profileId: requester.uid,
      response: "decline",
    });
    assert.equal(declined.data.state, "none");
    assert.equal(declined.data.viewerId, target.uid);
    assert.equal(declined.data.profileId, requester.uid);
    const requestDoc = await db.collection("follow_requests")
      .doc(`${requester.uid}--${target.uid}`)
      .get();
    assert.equal(requestDoc.exists, false);
    const requesterView = await callableFor(
      requester.client.functions,
      "getProfileRelationship",
    )({profileId: target.uid});
    assert.equal(requesterView.data.state, "none");
    await assertRelationshipGraph(db, requester.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });

    await new Promise((resolve) => setTimeout(resolve, 1000));
    const requesterNotifs = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .get();
    assert.equal(
      requesterNotifs.docs.filter((doc) =>
        ["follow_request", "follow_request_accepted"].includes(doc.get("kind"))
      ).length,
      0,
      "decline must not notify the requester",
    );
    const targetPending = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request")
      .get();
    const activePending = targetPending.docs.filter(
      (doc) => !(doc.get("deletedAt")),
    );
    assert.equal(activePending.length, 0);

    const targetFollowerNotifs = await db.collection("users").doc(target.uid)
      .collection("notifications")
      .where("kind", "==", "new_follower")
      .get();
    assert.equal(
      targetFollowerNotifs.size,
      0,
      "decline must not create a new_follower notification",
    );
  });

  it("removeFollower and unfollowProfile", async () => {
    const target = await provisionUser("pp-remove-target", {
      username: "pp.removetarget",
      usernameNormalized: "pp.removetarget",
    });
    const follower = await provisionUser("pp-remove-follower", {
      username: "pp.removefollower",
      usernameNormalized: "pp.removefollower",
    });
    await establishFollowing(follower, target);
    await assertRelationshipGraph(db, follower.uid, target.uid, {
      connected: true,
      followerFollowingCount: 1,
      targetFollowersCount: 1,
    });
    const removeFollower = callableFor(target.client.functions, "removeFollower");
    const removed = await removeFollower({profileId: follower.uid});
    assert.equal(removed.data.removed, true);
    let edge = await db.doc(
      `users/${follower.uid}/following/${target.uid}`,
    ).get();
    assert.equal(edge.exists, false);
    const reverseEdge = await db.doc(
      `users/${target.uid}/followers/${follower.uid}`,
    ).get();
    assert.equal(reverseEdge.exists, false);
    await assertRelationshipGraph(db, follower.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });
    const noop = await removeFollower({profileId: follower.uid});
    assert.equal(noop.data.removed, false);
    await assertRelationshipGraph(db, follower.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });

    await establishFollowing(follower, target);
    const unfollowProfile = callableFor(
      follower.client.functions,
      "unfollowProfile",
    );
    const response = await unfollowProfile({profileId: target.uid});
    assert.equal(response.data.state, "none");
    edge = await db.doc(
      `users/${follower.uid}/following/${target.uid}`,
    ).get();
    assert.equal(edge.exists, false);
    await assertRelationshipGraph(db, follower.uid, target.uid, {
      connected: false,
      followerFollowingCount: 0,
      targetFollowersCount: 0,
    });
  });

  it("removeFollower does not decrement counters when edge is missing", async () => {
    const target = await provisionUser("pp-remove-noedge-target", {
      username: "pp.remnoedgetarget",
      usernameNormalized: "pp.remnoedgetarget",
    });
    const follower = await provisionUser("pp-remove-noedge-follower", {
      username: "pp.remnoedgefollower",
      usernameNormalized: "pp.remnoedgefollower",
    });
    await db.collection("users").doc(target.uid).set({
      followersCount: 4,
      followingCount: 2,
    }, {merge: true});
    await db.collection("users").doc(follower.uid).set({
      followersCount: 1,
      followingCount: 5,
    }, {merge: true});
    const removeFollower = callableFor(target.client.functions, "removeFollower");
    const response = await removeFollower({profileId: follower.uid});
    assert.equal(response.data.removed, false);
    const targetCounters = await readRelationshipCounters(db, target.uid);
    const followerCounters = await readRelationshipCounters(db, follower.uid);
    assert.equal(targetCounters.followersCount, 4);
    assert.equal(followerCounters.followingCount, 5);
  });

  it("duplicate follow calls are idempotent", async () => {
    const target = await provisionUser("pp-idempotent-target", {
      username: "pp.idemptarget",
      usernameNormalized: "pp.idemptarget",
    });
    const viewer = await provisionUser("pp-idempotent-viewer", {
      username: "pp.idempviewer",
      usernameNormalized: "pp.idempviewer",
    });
    const followProfile = callableFor(viewer.client.functions, "followProfile");
    await followProfile({profileId: target.uid});
    const second = await followProfile({profileId: target.uid});
    assert.equal(second.data.state, "following");
    const edges = await db.collection(`users/${viewer.uid}/following`).get();
    assert.equal(edges.size, 1);
    await assertRelationshipGraph(db, viewer.uid, target.uid, {
      connected: true,
      followerFollowingCount: 1,
      targetFollowersCount: 1,
    });
  });

  it("concurrent accept and cancel yields one valid final state", async () => {
    const target = await provisionUser("pp-race-target", {
      username: "pp.racetarget",
      usernameNormalized: "pp.racetarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const viewer = await provisionUser("pp-race-viewer", {
      username: "pp.raceviewer",
      usernameNormalized: "pp.raceviewer",
    });
    await callableFor(viewer.client.functions, "followProfile")({
      profileId: target.uid,
    });
    const accept = callableFor(target.client.functions, "respondToFollowRequest")({
      profileId: viewer.uid,
      response: "accept",
    });
    const cancel = callableFor(viewer.client.functions, "cancelFollowRequest")({
      profileId: target.uid,
    });
    await Promise.allSettled([accept, cancel]);
    await assertCleanRelationshipState(db, viewer.uid, target.uid);
    const edge = await db.doc(
      `users/${viewer.uid}/following/${target.uid}`,
    ).get();
    if (edge.exists) {
      await assertRelationshipGraph(db, viewer.uid, target.uid, {
        connected: true,
        followerFollowingCount: 1,
        targetFollowersCount: 1,
      });
    } else {
      await assertRelationshipGraph(db, viewer.uid, target.uid, {
        connected: false,
        followerFollowingCount: 0,
        targetFollowersCount: 0,
      });
    }
  });

  it("concurrent accept and decline yields one valid final state", async () => {
    const target = await provisionUser("pp-race-decline-target", {
      username: "pp.racedeclinetarget",
      usernameNormalized: "pp.racedeclinetarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const viewer = await provisionUser("pp-race-decline-viewer", {
      username: "pp.racedeclineviewer",
      usernameNormalized: "pp.racedeclineviewer",
    });
    await callableFor(viewer.client.functions, "followProfile")({
      profileId: target.uid,
    });
    const accept = callableFor(target.client.functions, "respondToFollowRequest")({
      profileId: viewer.uid,
      response: "accept",
    });
    const decline = callableFor(target.client.functions, "respondToFollowRequest")({
      profileId: viewer.uid,
      response: "decline",
    });
    await Promise.allSettled([accept, decline]);
    await assertCleanRelationshipState(db, viewer.uid, target.uid);
    const edge = await db.doc(
      `users/${viewer.uid}/following/${target.uid}`,
    ).get();
    if (edge.exists) {
      await assertRelationshipGraph(db, viewer.uid, target.uid, {
        connected: true,
        followerFollowingCount: 1,
        targetFollowersCount: 1,
      });
    } else {
      await assertRelationshipGraph(db, viewer.uid, target.uid, {
        connected: false,
        followerFollowingCount: 0,
        targetFollowersCount: 0,
      });
    }
  });

  it("repeated accept calls are idempotent for edges counters and requester notification", async () => {
    const target = await provisionUser("pp-repeat-accept-target", {
      username: "pp.repeataccepttarget",
      usernameNormalized: "pp.repeataccepttarget",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const requester = await provisionUser("pp-repeat-accept-requester", {
      username: "pp.repeatacceptrequester",
      usernameNormalized: "pp.repeatacceptrequester",
    });
    await callableFor(requester.client.functions, "followProfile")({
      profileId: target.uid,
    });
    await callableFor(target.client.functions, "respondToFollowRequest")({
      profileId: requester.uid,
      response: "accept",
    });
    await expectCallableError(
      callableFor(target.client.functions, "respondToFollowRequest")({
        profileId: requester.uid,
        response: "accept",
      }),
      "not-found",
    );
    await new Promise((resolve) => setTimeout(resolve, 1000));
    await assertRelationshipGraph(db, requester.uid, target.uid, {
      connected: true,
      followerFollowingCount: 1,
      targetFollowersCount: 1,
    });
    const acceptedNotifs = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .where("kind", "==", "follow_request_accepted")
      .get();
    assert.equal(acceptedNotifs.size, 1);
  });

  it("updateProfile toggles public and private visibility", async () => {
    const owner = await provisionUser("pp-toggle-owner", {
      username: "pp.toggleowner",
      usernameNormalized: "pp.toggleowner",
    });
    const updateProfile = callableFor(owner.client.functions, "updateProfile");
    await updateProfile(updateProfilePayload(owner.profile, "followers"));
    let snapshot = await db.collection("users").doc(owner.uid).get();
    assert.equal(snapshot.get("visibility"), "followers");
    assert.equal(snapshot.get("accountPrivacy"), "private");
    await updateProfile(updateProfilePayload(owner.profile, "public"));
    snapshot = await db.collection("users").doc(owner.uid).get();
    assert.equal(snapshot.get("visibility"), "public");
    assert.equal(snapshot.get("accountPrivacy"), "public");
  });

  it("loadStoryRail respects story visibility", async () => {
    const publicAuthor = await provisionUser("pp-story-public", {
      username: "pp.storypublic",
      usernameNormalized: "pp.storypublic",
    });
    const privateAuthor = await provisionUser("pp-story-private", {
      username: "pp.storyprivate",
      usernameNormalized: "pp.storyprivate",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const stranger = await provisionUser("pp-story-stranger", {
      username: "pp.storystranger",
      usernameNormalized: "pp.storystranger",
    });
    const follower = await provisionUser("pp-story-follower", {
      username: "pp.storyfollower",
      usernameNormalized: "pp.storyfollower",
    });
    await establishFollowing(follower, privateAuthor);
    await seedStory(db, {
      id: "pp-story-public-1",
      authorId: publicAuthor.uid,
      visibility: "public",
      username: publicAuthor.profile.username,
    });
    await seedStory(db, {
      id: "pp-story-private-1",
      authorId: privateAuthor.uid,
      visibility: "followers",
      username: privateAuthor.profile.username,
    });

    const loadStoryRail = callableFor(stranger.client.functions, "loadStoryRail");
    const strangerRail = await loadStoryRail({});
    const strangerStories = strangerRail.data.groups.flatMap(
      (group) => group.stories.map((story) => ({
        authorId: group.authorId,
        id: story.id,
        visibility: story.visibility,
      })),
    );
    assert.ok(
      strangerStories.some((story) => story.id === "pp-story-public-1"),
    );
    assert.equal(
      strangerStories.some(
        (story) =>
            story.id === "pp-story-private-1" &&
            story.visibility === "followers",
      ),
      false,
    );

    const followerRail = await callableFor(
      follower.client.functions,
      "loadStoryRail",
    )({});
    const followerAuthorIds = followerRail.data.groups.map((group) => group.authorId);
    assert.ok(followerAuthorIds.includes(privateAuthor.uid));
  });

  it("private account public-visibility content respects account privacy", async () => {
    const author = await provisionUser("pp-sec-private", {
      username: "pp.secprivate",
      usernameNormalized: "pp.secprivate",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    const stranger = await provisionUser("pp-sec-stranger", {
      username: "pp.secstranger",
      usernameNormalized: "pp.secstranger",
    });
    const follower = await provisionUser("pp-sec-follower", {
      username: "pp.secfollower",
      usernameNormalized: "pp.secfollower",
    });
    await establishFollowing(follower, author);
    await seedPost(db, {
      id: "pp-sec-post-public",
      authorId: author.uid,
      visibility: "public",
      kind: "post",
      username: author.profile.username,
    });
    await seedPost(db, {
      id: "pp-sec-reel-public",
      authorId: author.uid,
      visibility: "public",
      kind: "reel",
      username: author.profile.username,
    });
    await seedStory(db, {
      id: "pp-sec-story-public",
      authorId: author.uid,
      visibility: "public",
      username: author.profile.username,
    });

    const getPublicProfile = callableFor(
      stranger.client.functions,
      "getPublicProfile",
    );
    const strangerProfile = await getPublicProfile({profileId: author.uid});
    assert.equal(strangerProfile.data.access, "preview");
    assert.equal(strangerProfile.data.relationship.canViewProfile, false);

    const loadProfileContent = callableFor(
      stranger.client.functions,
      "loadProfileContent",
    );
    await expectCallableError(
      loadProfileContent({
        profileId: author.uid,
        filter: "posts",
        limit: 10,
      }),
      "permission-denied",
    );
    await expectCallableError(
      loadProfileContent({
        profileId: author.uid,
        filter: "reels",
        limit: 10,
      }),
      "permission-denied",
    );

    const strangerRail = await callableFor(
      stranger.client.functions,
      "loadStoryRail",
    )({});
    const strangerStoryIds = strangerRail.data.groups.flatMap(
      (group) => group.stories.map((story) => story.id),
    );
    assert.equal(strangerStoryIds.includes("pp-sec-story-public"), false);

    const followerProfile = await callableFor(
      follower.client.functions,
      "getPublicProfile",
    )({profileId: author.uid});
    assert.equal(followerProfile.data.access, "full");
    assert.equal(followerProfile.data.relationship.canViewProfile, true);

    const followerPosts = await callableFor(
      follower.client.functions,
      "loadProfileContent",
    )({
      profileId: author.uid,
      filter: "posts",
      limit: 10,
    });
    assert.ok(
      followerPosts.data.items.some(
        (item) => item.post?.id === "pp-sec-post-public",
      ),
    );
    const followerReels = await callableFor(
      follower.client.functions,
      "loadProfileContent",
    )({
      profileId: author.uid,
      filter: "reels",
      limit: 10,
    });
    assert.ok(
      followerReels.data.items.some(
        (item) => item.post?.id === "pp-sec-reel-public",
      ),
    );

    const followerRail = await callableFor(
      follower.client.functions,
      "loadStoryRail",
    )({});
    const followerStoryIds = followerRail.data.groups.flatMap(
      (group) => group.stories.map((story) => story.id),
    );
    assert.ok(followerStoryIds.includes("pp-sec-story-public"));
  });

  it("listProfileConnections enforces authorization", async () => {
    const publicTarget = await provisionUser("pp-conn-public", {
      username: "pp.connpublic",
      usernameNormalized: "pp.connpublic",
    });
    const privateEveryone = await provisionUser("pp-conn-everyone", {
      username: "pp.conneveryone",
      usernameNormalized: "pp.conneveryone",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    await db.doc(`users/${privateEveryone.uid}/private/profile_settings`).set({
      followerListAudience: "everyone",
    }, {merge: true});
    const privateOwnerOnlyLists = await provisionUser("pp-conn-ownerlists", {
      username: "pp.connownerlists",
      usernameNormalized: "pp.connownerlists",
      visibility: "followers",
      accountPrivacy: "private",
      followApprovalPolicy: "approvalRequired",
    });
    await db.doc(
      `users/${privateOwnerOnlyLists.uid}/private/profile_settings`,
    ).set({
      followerListAudience: "owner",
    }, {merge: true});
    const stranger = await provisionUser("pp-conn-stranger", {
      username: "pp.connstranger",
      usernameNormalized: "pp.connstranger",
    });
    await establishFollowing(stranger, publicTarget);
    const listProfileConnections = callableFor(
      stranger.client.functions,
      "listProfileConnections",
    );
    const allowed = await listProfileConnections({
      profileId: publicTarget.uid,
      type: "followers",
      limit: 10,
    });
    assert.ok(Array.isArray(allowed.data.items));

    const previewEveryone = await listProfileConnections({
      profileId: privateEveryone.uid,
      type: "followers",
      limit: 10,
    });
    assert.ok(Array.isArray(previewEveryone.data.items));

    await expectCallableError(
      listProfileConnections({
        profileId: privateOwnerOnlyLists.uid,
        type: "followers",
        limit: 10,
      }),
      "permission-denied",
    );
    await expectCallableError(
      listProfileConnections({
        profileId: privateEveryone.uid,
        type: "requests",
        limit: 10,
      }),
      "permission-denied",
    );
  });

  it("rejects unauthorized and suspended-user calls", async () => {
    const active = await provisionUser("pp-active", {
      username: "pp.active",
      usernameNormalized: "pp.active",
    });
    const unauthViewer = await provisionUser("pp-unauth-viewer", {
      username: "pp.unauthviewer",
      usernameNormalized: "pp.unauthviewer",
    });
    await expectCallableError(
      signedOutCallable(unauthViewer.client, "getPublicProfile", {
        profileId: active.uid,
      }),
      "unauthenticated",
    );

    const suspended = await provisionUser("pp-suspended", {
      username: "pp.suspended",
      usernameNormalized: "pp.suspended",
      moderationState: "restricted",
    });
    const suspendedViewer = await provisionUser("pp-suspended-viewer", {
      username: "pp.suspviewer",
      usernameNormalized: "pp.suspviewer",
    });
    const followProfile = callableFor(
      suspendedViewer.client.functions,
      "followProfile",
    );
    await expectCallableError(
      followProfile({profileId: suspended.uid}),
      "not-found",
    );
  });

  it("followerListAudience followers allows only approved followers", async () => {
    const target = await provisionUser("pp-list-target", {
      username: "pp.listtarget",
      usernameNormalized: "pp.listtarget",
    });
    const follower = await provisionUser("pp-list-follower", {
      username: "pp.listfollower",
      usernameNormalized: "pp.listfollower",
    });
    const stranger = await provisionUser("pp-list-stranger", {
      username: "pp.liststranger",
      usernameNormalized: "pp.liststranger",
    });
    await db.doc(`users/${target.uid}/private/profile_settings`).set({
      followerListAudience: "followers",
      showFollowerLists: true,
    }, {merge: true});
    await establishFollowing(follower, target);
    const listProfileConnections = callableFor(
      stranger.client.functions,
      "listProfileConnections",
    );
    await expectCallableError(
      listProfileConnections({
        profileId: target.uid,
        type: "followers",
        limit: 10,
      }),
      "permission-denied",
    );
    const allowed = await callableFor(
      follower.client.functions,
      "listProfileConnections",
    )({
      profileId: target.uid,
      type: "followers",
      limit: 10,
    });
    assert.ok(Array.isArray(allowed.data.items));
  });

  it("unfollowProfile purges feed entries for the viewer", async () => {
    const target = await provisionUser("pp-feed-target", {
      username: "pp.feedtarget",
      usernameNormalized: "pp.feedtarget",
    });
    const follower = await provisionUser("pp-feed-follower", {
      username: "pp.feedfollower",
      usernameNormalized: "pp.feedfollower",
    });
    await establishFollowing(follower, target);
    const feedRef = db.collection("feed_entries").doc("pp-feed-entry");
    await feedRef.set({
      recipientId: follower.uid,
      authorId: target.uid,
      postId: "pp-feed-post",
      createdAt: Timestamp.now(),
      schemaVersion: 1,
    });
    const unfollowProfile = callableFor(
      follower.client.functions,
      "unfollowProfile",
    );
    await unfollowProfile({profileId: target.uid});
    const feedDoc = await feedRef.get();
    assert.equal(feedDoc.exists, false);
  });
});
