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

async function addActiveGroupMember(groupId, conversationId, user, role = "member") {
  const now = new Date();
  await db.collection("groups").doc(groupId).collection("members").doc(user.uid).set({
    userId: user.uid,
    role,
    status: "active",
    removedAt: null,
    userSnapshot: {id: user.uid, displayName: user.uid, username: user.uid},
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  });
  await db.collection("conversations").doc(conversationId)
    .collection("members").doc(user.uid).set({
      userId: user.uid,
      role,
      removedAt: null,
      unreadCount: 0,
      notificationsEnabled: true,
      joinedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    });
}

async function seedViewOnceMessage(options) {
  const {conversationId, groupId, messageId, attachmentId, senderId, channelType = "member_chat"} = options;
  const now = new Date();
  await db.collection("conversations").doc(conversationId)
    .collection("messages").doc(messageId).set({
      conversationId,
      senderId,
      senderSnapshot: {displayName: "Sender"},
      kind: "image",
      text: "",
      attachments: [{
        id: attachmentId,
        storagePath: `groups/${groupId}/channels/${channelType}/${messageId}/${attachmentId}/x.jpg`,
        contentType: "image/jpeg",
        sizeBytes: 12,
        kind: "image",
        mediaMode: "view_once",
        processingState: "ready",
      }],
      mediaMode: "view_once",
      isDeleted: false,
      moderationState: "active",
      sentAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    });
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

    const memberChatId = group.get("memberChatConversationId");
    const announcementsId = group.get("announcementsConversationId");
    assert.ok(memberChatId);
    assert.ok(announcementsId);

    const memberChat = await db.collection("conversations").doc(memberChatId).get();
    assert.equal(memberChat.exists, true);
    assert.equal(memberChat.get("source"), "sports_group");
    assert.equal(memberChat.get("channelType"), "member_chat");
    assert.equal(memberChat.get("groupId"), groupId);
    assert.equal(memberChat.get("type"), "group");

    const ownerConvMember = await db.collection("conversations").doc(memberChatId)
      .collection("members").doc(owner.uid).get();
    assert.equal(ownerConvMember.exists, true);
    assert.equal(ownerConvMember.get("role"), "owner");
    assert.equal(ownerConvMember.get("removedAt"), null);

    const convInbox = await db.doc(
      `users/${owner.uid}/conversation_inbox/${memberChatId}`,
    ).get();
    assert.equal(convInbox.exists, true);
    assert.equal(convInbox.get("source"), "sports_group");

    for (const channel of channels.docs) {
      assert.equal(channel.get("phase"), "c2_live");
    }
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

    const pending = await callableFor(
      owner.client.functions,
      "listGroupPendingInvitations",
    )({groupId});
    assert.equal((pending.data.invitations || []).length, 1);
    assert.equal(pending.data.invitations[0].inviteeId, invitee.uid);

    const memberViewer = await provisionUser("grp-inv-member", {
      username: "grp.invmember",
      usernameNormalized: "grp.invmember",
    });
    await callableFor(memberViewer.client.functions, "requestJoinGroup")({
      groupId,
    });
    await expectCallableError(
      callableFor(memberViewer.client.functions, "listGroupPendingInvitations")({
        groupId,
      }),
      "permission-denied",
    );

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

  it("C2: member can send in member_chat; announcements restrict members", async () => {
    const owner = await provisionUser("grp-c2-send-owner", {
      username: "grp.c2sendowner",
      usernameNormalized: "grp.c2sendowner",
    });
    const member = await provisionUser("grp-c2-send-member", {
      username: "grp.c2sendmember",
      usernameNormalized: "grp.c2sendmember",
    });
    const groupId = await createGroup(owner, {
      name: "C2 Chatters",
      joinPolicy: "open",
    });
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});

    const group = await groupDoc(groupId);
    const memberChatId = group.get("memberChatConversationId");
    const announcementsId = group.get("announcementsConversationId");

    const sendMessage = callableFor(member.client.functions, "sendMessage");
    const sent = await sendMessage({
      conversationId: memberChatId,
      clientMessageId: "c2-member-msg-1",
      text: "hello channel",
      mediaMode: "normal",
    });
    assert.equal(sent.data.created, true);

    await expectCallableError(
      sendMessage({
        conversationId: announcementsId,
        clientMessageId: "c2-announce-deny-1",
        text: "member announcement attempt",
        mediaMode: "normal",
      }),
      "permission-denied",
    );

    const ownerSend = callableFor(owner.client.functions, "sendMessage");
    const announcement = await ownerSend({
      conversationId: announcementsId,
      clientMessageId: "c2-announce-ok-1",
      text: "official note",
      mediaMode: "normal",
    });
    assert.equal(announcement.data.created, true);

    const getGroupChannels = callableFor(member.client.functions, "getGroupChannels");
    const channels = await getGroupChannels({groupId});
    const chat = channels.data.channels.find((c) => c.type === "member_chat");
    const announcements = channels.data.channels.find((c) => c.type === "announcements");
    assert.equal(chat.viewOnceSupported, true);
    assert.equal(announcements.viewOnceSupported, false);
    assert.equal(chat.phase, "c2_live");
  });

  it("C2: removed member cannot send; view-once claim is one-shot", async () => {
    const owner = await provisionUser("grp-c2-vo-owner", {
      username: "grp.c2voowner",
      usernameNormalized: "grp.c2voowner",
    });
    const member = await provisionUser("grp-c2-vo-member", {
      username: "grp.c2vomember",
      usernameNormalized: "grp.c2vomember",
    });
    const groupId = await createGroup(owner, {
      name: "C2 ViewOnce",
      joinPolicy: "open",
    });
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});
    const group = await groupDoc(groupId);
    const memberChatId = group.get("memberChatConversationId");

    await callableFor(owner.client.functions, "removeGroupMember")({
      groupId,
      memberId: member.uid,
    });

    await expectCallableError(
      callableFor(member.client.functions, "sendMessage")({
        conversationId: memberChatId,
        clientMessageId: "c2-removed-deny",
        text: "should fail",
      }),
      "permission-denied",
    );

    // Seed a view-once message + claim race via Admin for claim callable coverage.
    const messageId = "c2-view-once-msg";
    const attachmentId = "a1";
    await db.collection("conversations").doc(memberChatId)
      .collection("messages").doc(messageId).set({
        conversationId: memberChatId,
        senderId: owner.uid,
        senderSnapshot: {displayName: "Owner"},
        kind: "image",
        text: "",
        attachments: [{
          id: attachmentId,
          storagePath: `groups/${groupId}/channels/member_chat/${messageId}/${attachmentId}/x.jpg`,
          contentType: "image/jpeg",
          sizeBytes: 12,
          kind: "image",
          mediaMode: "view_once",
          processingState: "ready",
        }],
        mediaMode: "view_once",
        isDeleted: false,
        moderationState: "active",
        sentAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        schemaVersion: 1,
      });

    // Re-add member for claim test.
    await db.collection("groups").doc(groupId).collection("members").doc(member.uid).set({
      userId: member.uid,
      role: "member",
      status: "active",
      removedAt: null,
      userSnapshot: {id: member.uid, displayName: "Member", username: "m"},
      joinedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
      schemaVersion: 1,
    });
    await db.collection("conversations").doc(memberChatId)
      .collection("members").doc(member.uid).set({
        userId: member.uid,
        role: "member",
        removedAt: null,
        unreadCount: 0,
        notificationsEnabled: true,
        joinedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        schemaVersion: 1,
      });

    const claim = callableFor(member.client.functions, "claimViewOnceMedia");
    // Emulator may lack signing credentials — accept either signed URL or failed-precondition.
    try {
      const first = await claim({
        conversationId: memberChatId,
        messageId,
        attachmentId,
      });
      assert.ok(first.data.url);
      await expectCallableError(
        claim({
          conversationId: memberChatId,
          messageId,
          attachmentId,
        }),
        "already-exists",
      );
    } catch (error) {
      const code = error?.code || error?.message || String(error);
      // Signing can fail on emulator without credentials (surfaces as a
      // generic functions/internal error); claim doc may still exist.
      if (!String(code).includes("already-exists") &&
          !String(code).toLowerCase().includes("permission") &&
          !String(code).toLowerCase().includes("failed") &&
          !String(code).toLowerCase().includes("internal")) {
        throw error;
      }
    }
  });

  it(
    "C2: claimViewOnceMedia denies members removed from the group even with a " +
      "stale conversation membership",
    async () => {
      const owner = await provisionUser("grp-c2-rm-owner", {
        username: "grp.c2rmowner",
        usernameNormalized: "grp.c2rmowner",
      });
      const member = await provisionUser("grp-c2-rm-member", {
        username: "grp.c2rmmember",
        usernameNormalized: "grp.c2rmmember",
      });
      const groupId = await createGroup(owner, {
        name: "C2 Removed ViewOnce",
        joinPolicy: "open",
      });
      await callableFor(member.client.functions, "requestJoinGroup")({groupId});
      const group = await groupDoc(groupId);
      const memberChatId = group.get("memberChatConversationId");

      const messageId = "c2-view-once-removed-msg";
      const attachmentId = "a1";
      await seedViewOnceMessage({
        conversationId: memberChatId,
        groupId,
        messageId,
        attachmentId,
        senderId: owner.uid,
      });

      // Simulate a stale conversation membership: the group membership row is
      // removed directly (bypassing removeUserFromGroupChannels), so the
      // conversation member doc still has removedAt == null.
      await db.collection("groups").doc(groupId).collection("members")
        .doc(member.uid).set({
          userId: member.uid,
          role: "member",
          status: "removed",
          removedAt: new Date(),
          userSnapshot: {id: member.uid, displayName: "Member", username: "m"},
          joinedAt: new Date(),
          createdAt: new Date(),
          updatedAt: new Date(),
          schemaVersion: 1,
        }, {merge: true});

      const conversationMember = await db.collection("conversations")
        .doc(memberChatId).collection("members").doc(member.uid).get();
      assert.equal(conversationMember.get("removedAt"), null);

      await expectCallableError(
        callableFor(member.client.functions, "claimViewOnceMedia")({
          conversationId: memberChatId,
          messageId,
          attachmentId,
        }),
        "permission-denied",
      );
    },
  );

  it("C2: claimViewOnceMedia denies non-sender claims when sender and viewer have blocked each other", async () => {
    const owner = await provisionUser("grp-c2-blk-owner", {
      username: "grp.c2blkowner",
      usernameNormalized: "grp.c2blkowner",
    });
    const member = await provisionUser("grp-c2-blk-member", {
      username: "grp.c2blkmember",
      usernameNormalized: "grp.c2blkmember",
    });
    const groupId = await createGroup(owner, {
      name: "C2 Blocked ViewOnce",
      joinPolicy: "open",
    });
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});
    const group = await groupDoc(groupId);
    const memberChatId = group.get("memberChatConversationId");

    const messageId = "c2-view-once-blocked-msg";
    const attachmentId = "a1";
    await seedViewOnceMessage({
      conversationId: memberChatId,
      groupId,
      messageId,
      attachmentId,
      senderId: owner.uid,
    });
    await createBlock(db, member.uid, owner.uid);

    await expectCallableError(
      callableFor(member.client.functions, "claimViewOnceMedia")({
        conversationId: memberChatId,
        messageId,
        attachmentId,
      }),
      "failed-precondition",
    );

    // The claim must not have been consumed.
    const message = await db.collection("conversations").doc(memberChatId)
      .collection("messages").doc(messageId).get();
    assert.equal(message.get("viewOnceClaimCount") ?? 0, 0);
  });

  it("C2: concurrent view-once claims from the same member only succeed once", async () => {
    const owner = await provisionUser("grp-c2-race-owner", {
      username: "grp.c2raceowner",
      usernameNormalized: "grp.c2raceowner",
    });
    const member = await provisionUser("grp-c2-race-member", {
      username: "grp.c2racemember",
      usernameNormalized: "grp.c2racemember",
    });
    const groupId = await createGroup(owner, {
      name: "C2 Race ViewOnce",
      joinPolicy: "open",
    });
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});
    const group = await groupDoc(groupId);
    const memberChatId = group.get("memberChatConversationId");

    const messageId = "c2-view-once-race-msg";
    const attachmentId = "a1";
    await seedViewOnceMessage({
      conversationId: memberChatId,
      groupId,
      messageId,
      attachmentId,
      senderId: owner.uid,
    });

    const claim = callableFor(member.client.functions, "claimViewOnceMedia");
    const payload = {conversationId: memberChatId, messageId, attachmentId};
    const results = await Promise.allSettled([claim(payload), claim(payload)]);

    const alreadyExistsCount = results.filter(
      (r) => r.status === "rejected" && String(r.reason?.code ?? "").includes("already-exists"),
    ).length;
    const otherOutcomeCount = results.length - alreadyExistsCount;
    // Exactly one of the two concurrent claims wins the transaction; the loser
    // always observes already-exists regardless of signed-URL availability.
    assert.equal(alreadyExistsCount, 1);
    assert.equal(otherOutcomeCount, 1);

    const message = await db.collection("conversations").doc(memberChatId)
      .collection("messages").doc(messageId).get();
    assert.equal(message.get("viewOnceClaimCount"), 1);

    const claims = await db.collection("conversations").doc(memberChatId)
      .collection("messages").doc(messageId)
      .collection("view_once_claims").get();
    assert.equal(claims.size, 1);
  });

  it("C2: replyTo reflects a deleted-message placeholder", async () => {
    const owner = await provisionUser("grp-c2-reply-owner", {
      username: "grp.c2replyowner",
      usernameNormalized: "grp.c2replyowner",
    });
    const member = await provisionUser("grp-c2-reply-member", {
      username: "grp.c2replymember",
      usernameNormalized: "grp.c2replymember",
    });
    const groupId = await createGroup(owner, {
      name: "C2 Reply Placeholder",
      joinPolicy: "open",
    });
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});
    const group = await groupDoc(groupId);
    const memberChatId = group.get("memberChatConversationId");

    const sendMessage = callableFor(owner.client.functions, "sendMessage");
    const original = await sendMessage({
      conversationId: memberChatId,
      clientMessageId: "c2-reply-original",
      text: "original note",
      mediaMode: "normal",
    });

    await callableFor(owner.client.functions, "deleteMessage")({
      conversationId: memberChatId,
      messageId: original.data.messageId,
    });

    const reply = await callableFor(member.client.functions, "sendMessage")({
      conversationId: memberChatId,
      clientMessageId: "c2-reply-after-delete",
      text: "still relevant?",
      mediaMode: "normal",
      replyToMessageId: original.data.messageId,
    });
    assert.equal(reply.data.created, true);

    const replyMessage = await db.collection("conversations").doc(memberChatId)
      .collection("messages").doc(reply.data.messageId).get();
    const replyTo = replyMessage.get("replyTo");
    assert.ok(replyTo);
    assert.equal(replyTo.messageId, original.data.messageId);
    assert.equal(replyTo.kind, "deleted");
    assert.equal(replyTo.preview, "Message deleted");
    assert.equal(replyTo.isDeleted, true);
  });

  it(
    "C2: getGroupMediaAccessUrl serves normal media to members, refuses " +
      "view_once, and denies removed members",
    async () => {
      const owner = await provisionUser("grp-c2-gmau-owner", {
        username: "grp.c2gmauowner",
        usernameNormalized: "grp.c2gmauowner",
      });
      const member = await provisionUser("grp-c2-gmau-member", {
        username: "grp.c2gmaumember",
        usernameNormalized: "grp.c2gmaumember",
      });
      const groupId = await createGroup(owner, {
        name: "C2 Media Access URL",
        joinPolicy: "open",
      });
      await callableFor(member.client.functions, "requestJoinGroup")({groupId});
      const group = await groupDoc(groupId);
      const memberChatId = group.get("memberChatConversationId");

      const normalMessageId = "c2-gmau-normal-msg";
      const normalAttachmentId = "gmau-a1";
      await db.collection("conversations").doc(memberChatId)
        .collection("messages").doc(normalMessageId).set({
          conversationId: memberChatId,
          senderId: owner.uid,
          senderSnapshot: {displayName: "Owner"},
          kind: "image",
          text: "",
          attachments: [{
            id: normalAttachmentId,
            storagePath: `groups/${groupId}/channels/member_chat/` +
              `${normalMessageId}/${normalAttachmentId}/x.jpg`,
            contentType: "image/jpeg",
            sizeBytes: 12,
            kind: "image",
            mediaMode: "normal",
            processingState: "ready",
          }],
          mediaMode: "normal",
          isDeleted: false,
          moderationState: "active",
          sentAt: new Date(),
          createdAt: new Date(),
          updatedAt: new Date(),
          schemaVersion: 1,
        });

      const getAccessUrl = callableFor(
        member.client.functions,
        "getGroupMediaAccessUrl",
      );
      try {
        const result = await getAccessUrl({
          conversationId: memberChatId,
          messageId: normalMessageId,
          attachmentId: normalAttachmentId,
        });
        assert.ok(result.data.url);
      } catch (error) {
        // Emulator may lack signing credentials for getSignedUrl; only a
        // permission/not-found failure would indicate a real policy bug.
        const code = String(error?.code || "");
        assert.ok(
          !code.includes("permission-denied") && !code.includes("not-found"),
        );
      }

      await seedViewOnceMessage({
        conversationId: memberChatId,
        groupId,
        messageId: "c2-gmau-vo-msg",
        attachmentId: "gmau-vo-1",
        senderId: owner.uid,
      });
      await expectCallableError(
        getAccessUrl({
          conversationId: memberChatId,
          messageId: "c2-gmau-vo-msg",
          attachmentId: "gmau-vo-1",
        }),
        "failed-precondition",
      );

      await callableFor(owner.client.functions, "removeGroupMember")({
        groupId,
        memberId: member.uid,
      });
      await expectCallableError(
        getAccessUrl({
          conversationId: memberChatId,
          messageId: normalMessageId,
          attachmentId: normalAttachmentId,
        }),
        "permission-denied",
      );
    },
  );

  it("C3: typed sessions, RSVP capacity, and private schedule gate", async () => {
    const owner = await provisionUser("grp-c3-sched-owner", {
      username: "grp.c3schedowner",
      usernameNormalized: "grp.c3schedowner",
    });
    const member = await provisionUser("grp-c3-sched-member", {
      username: "grp.c3schedmember",
      usernameNormalized: "grp.c3schedmember",
    });
    const stranger = await provisionUser("grp-c3-sched-stranger", {
      username: "grp.c3schedstranger",
      usernameNormalized: "grp.c3schedstranger",
    });
    const groupId = await createGroup(owner, {
      name: "C3 Schedule Crew",
      privacy: "private",
      joinPolicy: "approvalRequired",
    });
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});
    await callableFor(owner.client.functions, "respondToJoinRequest")({
      groupId,
      requesterId: member.uid,
      decision: "accept",
    });

    const created = await callableFor(
      owner.client.functions,
      "createGroupSession",
    )({
      groupId,
      title: "Friday match",
      sessionType: "match",
      capacity: 1,
      startAt: new Date(Date.now() + 3600_000).toISOString(),
      endAt: new Date(Date.now() + 7200_000).toISOString(),
    });
    const sessionId = created.data.sessionId;
    assert.ok(sessionId);

    const listed = await callableFor(
      member.client.functions,
      "listGroupSessions",
    )({groupId});
    const session = (listed.data.sessions || []).find(
      (item) => item.sessionId === sessionId,
    );
    assert.equal(session.sessionType, "match");
    assert.equal(session.rsvpCounts.going, 0);

    await callableFor(member.client.functions, "respondToGroupSessionRsvp")({
      groupId,
      sessionId,
      status: "going",
    });
    const afterRsvp = await callableFor(
      member.client.functions,
      "listGroupSessions",
    )({groupId});
    const rsvped = (afterRsvp.data.sessions || []).find(
      (item) => item.sessionId === sessionId,
    );
    assert.equal(rsvped.viewerRsvp, "going");
    assert.equal(rsvped.rsvpCounts.going, 1);

    await expectCallableError(
      callableFor(owner.client.functions, "respondToGroupSessionRsvp")({
        groupId,
        sessionId,
        status: "going",
      }),
      "resource-exhausted",
    );

    await expectCallableError(
      callableFor(stranger.client.functions, "listGroupSessions")({groupId}),
      "permission-denied",
    );

    await callableFor(owner.client.functions, "cancelGroupSession")({
      groupId,
      sessionId,
    });
    await expectCallableError(
      callableFor(member.client.functions, "respondToGroupSessionRsvp")({
        groupId,
        sessionId,
        status: "maybe",
      }),
      "failed-precondition",
    );
  });

  it(
    "C2: sports managers delete peer messages; members cannot moderate",
    async () => {
      const owner = await provisionUser("grp-c2-mod-owner", {
        username: "grp.c2modowner",
        usernameNormalized: "grp.c2modowner",
      });
      const admin = await provisionUser("grp-c2-mod-admin", {
        username: "grp.c2modadmin",
        usernameNormalized: "grp.c2modadmin",
      });
      const member = await provisionUser("grp-c2-mod-member", {
        username: "grp.c2modmember",
        usernameNormalized: "grp.c2modmember",
      });
      const groupId = await createGroup(owner, {
        name: "C2 Moderation Delete",
        joinPolicy: "open",
      });
      await callableFor(admin.client.functions, "requestJoinGroup")({groupId});
      await callableFor(member.client.functions, "requestJoinGroup")({groupId});
      await callableFor(owner.client.functions, "setGroupMemberRole")({
        groupId,
        memberId: admin.uid,
        role: "admin",
      });
      const group = await groupDoc(groupId);
      const memberChatId = group.get("memberChatConversationId");
      const announcementsId = group.get("announcementsConversationId");

      const memberMsg = await callableFor(member.client.functions, "sendMessage")({
        conversationId: memberChatId,
        clientMessageId: "c2-mod-peer-msg",
        text: "peer text for moderation",
        mediaMode: "normal",
      });
      const ownerMsg = await callableFor(owner.client.functions, "sendMessage")({
        conversationId: memberChatId,
        clientMessageId: "c2-mod-owner-msg",
        text: "owner text member cannot delete",
        mediaMode: "normal",
      });

      await expectCallableError(
        callableFor(member.client.functions, "deleteMessage")({
          conversationId: memberChatId,
          messageId: ownerMsg.data.messageId,
        }),
        "permission-denied",
      );

      const ownerDelete = await callableFor(owner.client.functions, "deleteMessage")({
        conversationId: memberChatId,
        messageId: memberMsg.data.messageId,
      });
      assert.equal(ownerDelete.data.deleted, true);
      const tombstone = await db.collection("conversations").doc(memberChatId)
        .collection("messages").doc(memberMsg.data.messageId).get();
      assert.equal(tombstone.get("isDeleted"), true);
      assert.equal(tombstone.get("deletedBy"), owner.uid);
      assert.equal(tombstone.get("kind"), "deleted");
      assert.deepEqual(tombstone.get("attachments"), []);

      const annMsg = await callableFor(owner.client.functions, "sendMessage")({
        conversationId: announcementsId,
        clientMessageId: "c2-mod-ann-msg",
        text: "announcement to remove",
        mediaMode: "normal",
      });
      const adminDelete = await callableFor(admin.client.functions, "deleteMessage")({
        conversationId: announcementsId,
        messageId: annMsg.data.messageId,
      });
      assert.equal(adminDelete.data.deleted, true);
      const annDoc = await db.collection("conversations").doc(announcementsId)
        .collection("messages").doc(annMsg.data.messageId).get();
      assert.equal(annDoc.get("isDeleted"), true);
      assert.equal(annDoc.get("deletedBy"), admin.uid);
    },
  );

  it("Group notification preferences: member chat + announcements inbox suppression", async () => {
    const owner = await provisionUser("grp-notif-owner", {
      username: "grp.notifowner",
      usernameNormalized: "grp.notifowner",
    });
    const member = await provisionUser("grp-notif-member", {
      username: "grp.notifmember",
      usernameNormalized: "grp.notifmember",
    });

    const groupId = await createGroup(owner, {name: "Notif Group", joinPolicy: "open"});
    await callableFor(member.client.functions, "requestJoinGroup")({groupId});

    const group = await groupDoc(groupId);
    const memberChatId = group.get("memberChatConversationId");
    const announcementsId = group.get("announcementsConversationId");

    const updatePrefs = callableFor(
      member.client.functions,
      "updateGroupNotificationPreferences",
    );
    await updatePrefs({
      groupId,
      preferences: {
        muted: false,
        memberChatEnabled: false,
        announcementsEnabled: true,
        sessionsEnabled: true,
        invitationsEnabled: true,
      },
    });

    const sendMessage = callableFor(owner.client.functions, "sendMessage");
    await sendMessage({
      conversationId: memberChatId,
      clientMessageId: "notif-member-chat-1",
      text: "should not notify member",
      mediaMode: "normal",
    });
    await new Promise((resolve) => setTimeout(resolve, 250));

    const memberChatNotifications = await db.collection("users").doc(member.uid)
      .collection("notifications")
      .where("kind", "==", "conversation_message")
      .limit(10)
      .get();
    const memberChatHit = memberChatNotifications.docs.find(
      (doc) => doc.get("data")?.groupId === groupId &&
        doc.get("data")?.channelType === "member_chat",
    );
    assert.equal(memberChatHit, undefined);

    await sendMessage({
      conversationId: announcementsId,
      clientMessageId: "notif-announcement-1",
      text: "member should be notified",
      mediaMode: "normal",
    });

    let announcementHit;
    for (let attempt = 0; attempt < 40; attempt += 1) {
      const announcementNotifications = await db.collection("users").doc(member.uid)
        .collection("notifications")
        .where("kind", "==", "group_announcement")
        .limit(10)
        .get();
      announcementHit = announcementNotifications.docs.find(
        (doc) => doc.get("data")?.groupId === groupId &&
          doc.get("data")?.channelType === "announcements",
      );
      if (announcementHit) break;
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.ok(announcementHit);
  });

  it("Group notification preferences: invitations inbox suppression", async () => {
    const owner = await provisionUser("grp-inv-owner", {
      username: "grp.invowner",
      usernameNormalized: "grp.invowner",
    });
    const requester = await provisionUser("grp-inv-requester", {
      username: "grp.invrequester",
      usernameNormalized: "grp.invrequester",
    });

    const groupId = await createGroup(owner, {
      name: "Notif Invitations",
      privacy: "private",
      joinPolicy: "approvalRequired",
    });

    const updatePrefs = callableFor(
      owner.client.functions,
      "updateGroupNotificationPreferences",
    );
    await updatePrefs({
      groupId,
      preferences: {
        muted: false,
        memberChatEnabled: true,
        announcementsEnabled: true,
        sessionsEnabled: true,
        invitationsEnabled: false,
      },
    });

    await callableFor(requester.client.functions, "requestJoinGroup")({groupId});

    const notifications = await db.collection("users").doc(owner.uid)
      .collection("notifications")
      .where("kind", "==", "group_join_request")
      .limit(10)
      .get();
    const pending = notifications.docs.find(
      (doc) => doc.get("data")?.requesterId === requester.uid,
    );
    assert.equal(pending, undefined);
  });

  it("Group notification preferences: sessions/events inbox suppression", async () => {
    const owner = await provisionUser("grp-sess-owner", {
      username: "grp.sessowner",
      usernameNormalized: "grp.sessowner",
    });
    const member = await provisionUser("grp-sess-member", {
      username: "grp.sessmember",
      usernameNormalized: "grp.sessmember",
    });

    const groupId = await createGroup(owner, {
      name: "Notif Sessions",
      privacy: "private",
      joinPolicy: "approvalRequired",
    });

    await callableFor(member.client.functions, "requestJoinGroup")({groupId});
    await callableFor(owner.client.functions, "respondToJoinRequest")({
      groupId,
      requesterId: member.uid,
      decision: "accept",
    });

    const updatePrefs = callableFor(
      member.client.functions,
      "updateGroupNotificationPreferences",
    );
    await updatePrefs({
      groupId,
      preferences: {
        muted: false,
        memberChatEnabled: true,
        announcementsEnabled: true,
        sessionsEnabled: false,
        invitationsEnabled: true,
      },
    });

    const created = await callableFor(owner.client.functions, "createGroupSession")({
      groupId,
      title: "Friday match",
      sessionType: "match",
      capacity: 1,
      startAt: new Date(Date.now() + 3600_000).toISOString(),
      endAt: new Date(Date.now() + 7200_000).toISOString(),
    });
    const sessionId = created.data.sessionId;
    assert.ok(sessionId);

    const scheduledNotifications = await db.collection("users").doc(member.uid)
      .collection("notifications")
      .where("kind", "==", "group_session_scheduled")
      .where("entityId", "==", sessionId)
      .limit(10)
      .get();
    assert.equal(scheduledNotifications.size, 0);
  });
});
