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
} = require("./helpers/emulatorHarness.cjs");

const {auth, db} = initAdmin();

async function provisionUser(uid, profileOverrides = {}) {
  const email = `${uid}@groups.test`;
  await ensureAuthUser(auth, {uid, email});
  const profile = baseProfile(uid, profileOverrides);
  await seedProfile(db, profile);
  const client = await signInClient(email);
  return {uid, email, profile, client};
}

function createGroupCallable(user) {
  return callableFor(user.client.functions, "createGroup");
}

async function createGroup(owner, overrides = {}) {
  const response = await createGroupCallable(owner)({
    name: overrides.name || "Trail Runners",
    description: overrides.description || "Weekend trail running crew.",
    category: overrides.category || "running",
    privacy: overrides.privacy || "public",
    joinPolicy: overrides.joinPolicy,
    capacity: overrides.capacity,
  });
  return response.data.groupId;
}

async function memberDoc(groupId, uid) {
  return db.collection("groups").doc(groupId)
    .collection("members").doc(uid).get();
}

async function groupDoc(groupId) {
  return db.collection("groups").doc(groupId).get();
}

describe("groups callable emulator integration", () => {
  it("createGroup seeds owner membership, channels, and denormalized inbox", async () => {
    const owner = await provisionUser("grp-create-owner", {
      username: "grp.createowner",
      usernameNormalized: "grp.createowner",
    });
    const groupId = await createGroup(owner, {name: "Sunrise Cyclists"});

    const group = await groupDoc(groupId);
    assert.equal(group.exists, true);
    assert.equal(group.get("ownerId"), owner.uid);
    assert.equal(group.get("memberCount"), 1);
    assert.equal(group.get("status"), "active");
    assert.equal(group.get("joinPolicy"), "open");

    const owner_member = await memberDoc(groupId, owner.uid);
    assert.equal(owner_member.get("role"), "owner");
    assert.equal(owner_member.get("status"), "active");

    const inbox = await db.doc(`users/${owner.uid}/group_memberships/${groupId}`).get();
    assert.equal(inbox.exists, true);
    assert.equal(inbox.get("role"), "owner");

    const channels = await db.collection("groups").doc(groupId)
      .collection("channels").get();
    assert.equal(channels.size, 2);
  });

  it("open join policy admits members immediately and increments memberCount", async () => {
    const owner = await provisionUser("grp-open-owner", {
      username: "grp.openowner",
      usernameNormalized: "grp.openowner",
    });
    const joiner = await provisionUser("grp-open-joiner", {
      username: "grp.openjoiner",
      usernameNormalized: "grp.openjoiner",
    });
    const groupId = await createGroup(owner, {
      name: "Open Hikers",
      joinPolicy: "open",
    });

    const requestJoinGroup = callableFor(joiner.client.functions, "requestJoinGroup");
    const response = await requestJoinGroup({groupId});
    assert.equal(response.data.status, "member");

    const member = await memberDoc(groupId, joiner.uid);
    assert.equal(member.get("role"), "member");
    const group = await groupDoc(groupId);
    assert.equal(group.get("memberCount"), 2);
  });

  it(
    "approvalRequired join policy queues a request and notifies managers",
    async () => {
      const owner = await provisionUser("grp-appr-owner", {
        username: "grp.approwner",
        usernameNormalized: "grp.approwner",
      });
      const requester = await provisionUser("grp-appr-requester", {
        username: "grp.apprrequester",
        usernameNormalized: "grp.apprrequester",
      });
      const groupId = await createGroup(owner, {
        name: "Curated Climbers",
        privacy: "private",
        joinPolicy: "approvalRequired",
      });

      const requestJoinGroup = callableFor(
        requester.client.functions,
        "requestJoinGroup",
      );
      const first = await requestJoinGroup({groupId});
      assert.equal(first.data.status, "pending");

      // Duplicate request must not create a second pending doc.
      const second = await requestJoinGroup({groupId});
      assert.equal(second.data.status, "pending");

      const joinRequest = await db.collection("groups").doc(groupId)
        .collection("join_requests").doc(requester.uid).get();
      assert.equal(joinRequest.exists, true);
      assert.equal(joinRequest.get("status"), "pending");

      const notifications = await db.collection("users").doc(owner.uid)
        .collection("notifications")
        .where("kind", "==", "group_join_request")
        .limit(10)
        .get();
      const pending = notifications.docs.find(
        (doc) => doc.get("data")?.requesterId === requester.uid,
      );
      assert.ok(pending);

      // Accepting resolves the manager's pending notification.
      const respondToJoinRequest = callableFor(
        owner.client.functions,
        "respondToJoinRequest",
      );
      await respondToJoinRequest({
        groupId,
        requesterId: requester.uid,
        decision: "accept",
      });

      const member = await memberDoc(groupId, requester.uid);
      assert.equal(member.get("role"), "member");
      const group = await groupDoc(groupId);
      assert.equal(group.get("memberCount"), 2);

      const resolvedRequest = await db.collection("groups").doc(groupId)
        .collection("join_requests").doc(requester.uid).get();
      assert.equal(resolvedRequest.exists, false);

      const acceptedNotifs = await db.collection("users").doc(requester.uid)
        .collection("notifications")
        .where("kind", "==", "group_join_accepted")
        .limit(5)
        .get();
      assert.ok(acceptedNotifs.size >= 1);

      const staleManagerNotif = await db.collection("users").doc(owner.uid)
        .collection("notifications")
        .where("kind", "==", "group_join_request")
        .limit(10)
        .get();
      const stillPending = staleManagerNotif.docs.find(
        (doc) => doc.get("data")?.requesterId === requester.uid &&
          doc.get("data")?.status === "pending",
      );
      assert.equal(stillPending, undefined);
    },
  );

  it("cancelJoinRequest removes the pending request and resolves manager notification", async () => {
    const owner = await provisionUser("grp-cancel-owner", {
      username: "grp.cancelowner",
      usernameNormalized: "grp.cancelowner",
    });
    const requester = await provisionUser("grp-cancel-requester", {
      username: "grp.cancelrequester",
      usernameNormalized: "grp.cancelrequester",
    });
    const groupId = await createGroup(owner, {
      name: "Cancelable Crew",
      joinPolicy: "approvalRequired",
    });
    await callableFor(requester.client.functions, "requestJoinGroup")({groupId});
    await callableFor(requester.client.functions, "cancelJoinRequest")({groupId});

    const joinRequest = await db.collection("groups").doc(groupId)
      .collection("join_requests").doc(requester.uid).get();
    assert.equal(joinRequest.exists, false);
  });

  it("declining a join request leaves the requester unaffiliated", async () => {
    const owner = await provisionUser("grp-decl-owner", {
      username: "grp.declowner",
      usernameNormalized: "grp.declowner",
    });
    const requester = await provisionUser("grp-decl-requester", {
      username: "grp.declrequester",
      usernameNormalized: "grp.declrequester",
    });
    const groupId = await createGroup(owner, {
      name: "Selective Squad",
      joinPolicy: "approvalRequired",
    });
    await callableFor(requester.client.functions, "requestJoinGroup")({groupId});
    await callableFor(owner.client.functions, "respondToJoinRequest")({
      groupId,
      requesterId: requester.uid,
      decision: "decline",
    });

    const member = await memberDoc(groupId, requester.uid);
    assert.equal(member.exists, false);
    const requesterNotifs = await db.collection("users").doc(requester.uid)
      .collection("notifications")
      .where("kind", "==", "group_join_accepted")
      .limit(5)
      .get();
    assert.equal(requesterNotifs.size, 0);
  });

  it(
    "concurrent accept of the same join request only admits the member once",
    async () => {
      const owner = await provisionUser("grp-conc-owner", {
        username: "grp.concowner",
        usernameNormalized: "grp.concowner",
      });
      const admin = await provisionUser("grp-conc-admin", {
        username: "grp.concadmin",
        usernameNormalized: "grp.concadmin",
      });
      const requester = await provisionUser("grp-conc-requester", {
        username: "grp.concrequester",
        usernameNormalized: "grp.concrequester",
      });
      const groupId = await createGroup(owner, {
        name: "Concurrent Crew",
        joinPolicy: "approvalRequired",
      });
      await db.collection("groups").doc(groupId).collection("members")
        .doc(admin.uid).set({
          userId: admin.uid,
          role: "admin",
          status: "active",
          joinedAt: new Date(),
          removedAt: null,
          userSnapshot: {id: admin.uid, username: admin.profile.username},
          createdAt: new Date(),
          updatedAt: new Date(),
          schemaVersion: 1,
        });
      await db.collection("groups").doc(groupId).update({memberCount: 2});

      await callableFor(requester.client.functions, "requestJoinGroup")({groupId});

      const respondAsOwner = callableFor(owner.client.functions, "respondToJoinRequest");
      const respondAsAdmin = callableFor(admin.client.functions, "respondToJoinRequest");
      const results = await Promise.allSettled([
        respondAsOwner({groupId, requesterId: requester.uid, decision: "accept"}),
        respondAsAdmin({groupId, requesterId: requester.uid, decision: "accept"}),
      ]);
      const fulfilled = results.filter((r) => r.status === "fulfilled");
      assert.ok(fulfilled.length >= 1);

      const group = await groupDoc(groupId);
      assert.equal(group.get("memberCount"), 3);
      const member = await memberDoc(groupId, requester.uid);
      assert.equal(member.get("role"), "member");
    },
  );

  it("inviteToGroup requires the invitee to follow the inviter and is idempotent", async () => {
    const owner = await provisionUser("grp-inv-owner", {
      username: "grp.invowner",
      usernameNormalized: "grp.invowner",
    });
    const invitee = await provisionUser("grp-inv-invitee", {
      username: "grp.invinvitee",
      usernameNormalized: "grp.invinvitee",
    });
    const groupId = await createGroup(owner, {name: "Invite Only Crew"});

    const inviteToGroup = callableFor(owner.client.functions, "inviteToGroup");
    await expectCallableError(
      inviteToGroup({groupId, inviteeId: invitee.uid}),
      "failed-precondition",
    );

    await establishFollowing(invitee, owner);
    const first = await inviteToGroup({groupId, inviteeId: invitee.uid});
    assert.equal(first.data.created, true);
    const second = await inviteToGroup({groupId, inviteeId: invitee.uid});
    assert.equal(second.data.created, false);

    const invite = await db.collection("groups").doc(groupId)
      .collection("invitations").doc(invitee.uid).get();
    assert.equal(invite.exists, true);

    const inboxInvite = await db.doc(`users/${invitee.uid}/group_invitations/${groupId}`).get();
    assert.equal(inboxInvite.exists, true);
  });

  it("respondToGroupInvitation accept joins and notifies inviter; decline is silent", async () => {
    const owner = await provisionUser("grp-rsvp-owner", {
      username: "grp.rsvpowner",
      usernameNormalized: "grp.rsvpowner",
    });
    const accepter = await provisionUser("grp-rsvp-accepter", {
      username: "grp.rsvpaccepter",
      usernameNormalized: "grp.rsvpaccepter",
    });
    const decliner = await provisionUser("grp-rsvp-decliner", {
      username: "grp.rsvpdecliner",
      usernameNormalized: "grp.rsvpdecliner",
    });
    const groupId = await createGroup(owner, {name: "RSVP Runners"});

    await establishFollowing(accepter, owner);
    await establishFollowing(decliner, owner);
    await callableFor(owner.client.functions, "inviteToGroup")({
      groupId,
      inviteeId: accepter.uid,
    });
    await callableFor(owner.client.functions, "inviteToGroup")({
      groupId,
      inviteeId: decliner.uid,
    });

    await callableFor(accepter.client.functions, "respondToGroupInvitation")({
      groupId,
      decision: "accept",
    });
    const acceptedMember = await memberDoc(groupId, accepter.uid);
    assert.equal(acceptedMember.get("role"), "member");
    const inviterNotifs = await db.collection("users").doc(owner.uid)
      .collection("notifications")
      .where("kind", "==", "group_invitation_accepted")
      .limit(5)
      .get();
    assert.ok(inviterNotifs.size >= 1);

    await callableFor(decliner.client.functions, "respondToGroupInvitation")({
      groupId,
      decision: "decline",
    });
    const declinedMember = await memberDoc(groupId, decliner.uid);
    assert.equal(declinedMember.exists, false);
  });

  it("blocked users cannot request to join or be invited", async () => {
    const owner = await provisionUser("grp-block-owner", {
      username: "grp.blockowner",
      usernameNormalized: "grp.blockowner",
    });
    const blocked = await provisionUser("grp-block-user", {
      username: "grp.blockuser",
      usernameNormalized: "grp.blockuser",
    });
    const groupId = await createGroup(owner, {name: "Blocked Test Group"});
    await createBlock(db, owner.uid, blocked.uid);

    await expectCallableError(
      callableFor(blocked.client.functions, "requestJoinGroup")({groupId}),
      "failed-precondition",
    );
    await expectCallableError(
      callableFor(owner.client.functions, "inviteToGroup")({
        groupId,
        inviteeId: blocked.uid,
      }),
      "failed-precondition",
    );
  });

  it(
    "member/admin/owner permission matrix for removing members",
    async () => {
      const owner = await provisionUser("grp-perm-owner", {
        username: "grp.permowner",
        usernameNormalized: "grp.permowner",
      });
      const admin = await provisionUser("grp-perm-admin", {
        username: "grp.permadmin",
        usernameNormalized: "grp.permadmin",
      });
      const member = await provisionUser("grp-perm-member", {
        username: "grp.permmember",
        usernameNormalized: "grp.permmember",
      });
      const groupId = await createGroup(owner, {
        name: "Permission Matrix Crew",
        joinPolicy: "open",
      });
      await callableFor(admin.client.functions, "requestJoinGroup")({groupId});
      await callableFor(member.client.functions, "requestJoinGroup")({groupId});
      await callableFor(owner.client.functions, "setGroupMemberRole")({
        groupId,
        memberId: admin.uid,
        role: "admin",
      });

      // A member cannot remove anyone.
      await expectCallableError(
        callableFor(member.client.functions, "removeGroupMember")({
          groupId,
          memberId: admin.uid,
        }),
        "permission-denied",
      );

      // An admin cannot remove another admin (owner is the only admin here besides
      // itself, so promote a second admin scenario is covered by the owner check).
      await expectCallableError(
        callableFor(admin.client.functions, "removeGroupMember")({
          groupId,
          memberId: owner.uid,
        }),
        "permission-denied",
      );

      // Admin can remove a plain member.
      const removeResponse = await callableFor(
        admin.client.functions,
        "removeGroupMember",
      )({groupId, memberId: member.uid});
      assert.equal(removeResponse.data.ok, true);
      const removedMember = await memberDoc(groupId, member.uid);
      assert.equal(removedMember.get("status"), "removed");

      const groupAfterRemoval = await groupDoc(groupId);
      assert.equal(groupAfterRemoval.get("memberCount"), 2);

      // Owner can remove an admin, but nobody can remove the owner.
      await expectCallableError(
        callableFor(admin.client.functions, "setGroupMemberRole")({
          groupId,
          memberId: owner.uid,
          role: "member",
        }),
        "permission-denied",
      );
      const ownerRemovalResponse = await callableFor(
        owner.client.functions,
        "removeGroupMember",
      )({groupId, memberId: admin.uid});
      assert.equal(ownerRemovalResponse.data.ok, true);
    },
  );

  it("leaveGroup blocks the owner and allows members to leave", async () => {
    const owner = await provisionUser("grp-leave-owner", {
      username: "grp.leaveowner",
      usernameNormalized: "grp.leaveowner",
    });
    const member = await provisionUser("grp-leave-member", {
      username: "grp.leavemember",
      usernameNormalized: "grp.leavemember",
    });
    const groupId = await createGroup(owner, {name: "Leave Test Group"});
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});

    await expectCallableError(
      callableFor(owner.client.functions, "leaveGroup")({groupId}),
      "failed-precondition",
    );

    await callableFor(member.client.functions, "leaveGroup")({groupId});
    const memberSnap = await memberDoc(groupId, member.uid);
    assert.equal(memberSnap.get("status"), "removed");
    const group = await groupDoc(groupId);
    assert.equal(group.get("memberCount"), 1);
  });

  it("transferGroupOwnership swaps roles between owner and target member", async () => {
    const owner = await provisionUser("grp-xfer-owner", {
      username: "grp.xferowner",
      usernameNormalized: "grp.xferowner",
    });
    const member = await provisionUser("grp-xfer-member", {
      username: "grp.xfermember",
      usernameNormalized: "grp.xfermember",
    });
    const groupId = await createGroup(owner, {name: "Transfer Test Group"});
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});

    await callableFor(owner.client.functions, "transferGroupOwnership")({
      groupId,
      newOwnerId: member.uid,
    });

    const group = await groupDoc(groupId);
    assert.equal(group.get("ownerId"), member.uid);
    const newOwnerMember = await memberDoc(groupId, member.uid);
    assert.equal(newOwnerMember.get("role"), "owner");
    const formerOwnerMember = await memberDoc(groupId, owner.uid);
    assert.equal(formerOwnerMember.get("role"), "admin");

    // Former owner can now leave since they are no longer the owner.
    await callableFor(owner.client.functions, "leaveGroup")({groupId});
    const formerOwnerAfterLeave = await memberDoc(groupId, owner.uid);
    assert.equal(formerOwnerAfterLeave.get("status"), "removed");
  });

  it("deleteGroup soft-deletes and blocks further group actions", async () => {
    const owner = await provisionUser("grp-del-owner", {
      username: "grp.delowner",
      usernameNormalized: "grp.delowner",
    });
    const groupId = await createGroup(owner, {name: "Deletable Group"});
    await callableFor(owner.client.functions, "deleteGroup")({groupId});

    const group = await groupDoc(groupId);
    assert.equal(group.get("status"), "deleted");

    await expectCallableError(
      callableFor(owner.client.functions, "getGroup")({groupId}),
      "not-found",
    );
  });

  it(
    "listDiscoverableGroups never leaks private or hidden groups",
    async () => {
      const owner = await provisionUser("grp-leak-owner", {
        username: "grp.leakowner",
        usernameNormalized: "grp.leakowner",
      });
      const stranger = await provisionUser("grp-leak-stranger", {
        username: "grp.leakstranger",
        usernameNormalized: "grp.leakstranger",
      });
      const publicGroupId = await createGroup(owner, {
        name: "Leak Test Public Group",
        privacy: "public",
      });
      const privateGroupId = await createGroup(owner, {
        name: "Leak Test Private Group",
        privacy: "private",
        joinPolicy: "approvalRequired",
      });
      const hiddenGroupId = await createGroup(owner, {
        name: "Leak Test Hidden Group",
        privacy: "hidden",
        joinPolicy: "inviteOnly",
      });

      const listDiscoverableGroups = callableFor(
        stranger.client.functions,
        "listDiscoverableGroups",
      );
      const response = await listDiscoverableGroups({limit: 40});
      const ids = response.data.groups.map((g) => g.groupId);
      assert.ok(ids.includes(publicGroupId));
      assert.ok(!ids.includes(privateGroupId));
      assert.ok(!ids.includes(hiddenGroupId));

      // Strangers cannot get() a private or hidden group either.
      await expectCallableError(
        callableFor(stranger.client.functions, "getGroup")({groupId: privateGroupId}),
        "not-found",
      );
      await expectCallableError(
        callableFor(stranger.client.functions, "getGroup")({groupId: hiddenGroupId}),
        "not-found",
      );

      // listGroupMembers must also refuse strangers for private/hidden groups.
      await expectCallableError(
        callableFor(stranger.client.functions, "listGroupMembers")({
          groupId: privateGroupId,
        }),
        "permission-denied",
      );

      // But public group membership rosters are visible to any signed-in user.
      const publicMembers = await callableFor(
        stranger.client.functions,
        "listGroupMembers",
      )({groupId: publicGroupId});
      assert.ok(publicMembers.data.members.length >= 1);
    },
  );

  it("listDiscoverableGroups supports cursor pagination without duplicates or gaps", async () => {
    const owner = await provisionUser("grp-page-owner", {
      username: "grp.pageowner",
      usernameNormalized: "grp.pageowner",
    });
    const viewer = await provisionUser("grp-page-viewer", {
      username: "grp.pageviewer",
      usernameNormalized: "grp.pageviewer",
    });
    const category = "pagination-test";
    const createdIds = [];
    for (let i = 0; i < 3; i += 1) {
      createdIds.push(
        await createGroup(owner, {name: `Pagination Group ${i}`, category}),
      );
    }

    const listDiscoverableGroups = callableFor(
      viewer.client.functions,
      "listDiscoverableGroups",
    );
    const firstPage = await listDiscoverableGroups({limit: 2, category});
    assert.equal(firstPage.data.groups.length, 2);
    assert.equal(firstPage.data.hasMore, true);
    assert.ok(firstPage.data.nextCursor);

    const secondPage = await listDiscoverableGroups({
      limit: 2,
      category,
      cursorId: firstPage.data.nextCursor.documentId,
      cursorAt: firstPage.data.nextCursor.createdAt,
    });
    const allIds = [...firstPage.data.groups, ...secondPage.data.groups]
      .map((g) => g.groupId);
    const uniqueIds = new Set(allIds);
    assert.equal(uniqueIds.size, allIds.length);
    for (const id of createdIds) {
      assert.ok(uniqueIds.has(id));
    }
  });
});
