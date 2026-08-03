#!/usr/bin/env node
/**
 * Phase C1 Groups final staging QA — covers every browser-scenario checklist
 * item via authenticated callables + Firestore verification on reemove-staging.
 * Does not use apply:true backfills. Production untouched.
 */
const {initializeApp, getApps, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {initializeApp: initClient} = require("firebase/app");
const {
  getAuth: getClientAuth,
  signInWithEmailAndPassword,
  signOut,
} = require("firebase/auth");
const {getFunctions, httpsCallable} = require("firebase/functions");
const fs = require("node:fs");
const path = require("node:path");

const PROJECT_ID = "reemove-staging";
const REGION = "europe-west1";
const OWNER_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const PEER_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";
const TEMP_PASSWORD = `PhaseC1-Final-QA-${Date.now()}!Aa1`;
const SUITE = `c1f-${Date.now().toString(36)}`;

const webConfig = {
  apiKey: "",
  authDomain: `${PROJECT_ID}.firebaseapp.com`,
  projectId: PROJECT_ID,
  appId: "",
};

const results = [];

function loadWebConfig() {
  const text = fs.readFileSync(
    path.join(__dirname, "../lib/firebase_options_staging.dart"),
    "utf8",
  );
  webConfig.apiKey = text.match(/apiKey:\s*'([^']+)'/)?.[1] || "";
  webConfig.appId = text.match(/appId:\s*'([^']+)'/)?.[1] || "";
  if (!webConfig.apiKey || !webConfig.appId) {
    throw new Error("Could not read staging web apiKey/appId");
  }
}

function initAdmin() {
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId: PROJECT_ID});
  }
  return {auth: getAuth(), db: getFirestore()};
}

async function clientFor(email) {
  const app = initClient({...webConfig}, `qa-${email}-${Date.now()}`);
  const auth = getClientAuth(app);
  const functions = getFunctions(app, REGION);
  await signInWithEmailAndPassword(auth, email, TEMP_PASSWORD);
  const call = (name) => httpsCallable(functions, name, {timeout: 60000});
  return {
    email,
    async invoke(name, data = {}) {
      const result = await call(name)(data);
      return result.data;
    },
    async close() {
      await signOut(auth);
    },
  };
}

function ok(label, pass, detail = "") {
  console.log(`[${pass ? "PASS" : "FAIL"}] ${label}${detail ? ` — ${detail}` : ""}`);
  results.push({label, pass: !!pass, detail});
  return !!pass;
}

async function expectDenied(promise) {
  try {
    await promise;
    return false;
  } catch (error) {
    const code = String(error.code || error.message || error);
    return /permission-denied|not-found|failed-precondition|invalid-argument|resource-exhausted/i
      .test(code);
  }
}

async function clearBlock(db, a, b) {
  await Promise.all([
    db.doc(`users/${a}/blocks/${b}`).delete().catch(() => undefined),
    db.doc(`users/${b}/blocked_by/${a}`).delete().catch(() => undefined),
    db.doc(`users/${b}/blocks/${a}`).delete().catch(() => undefined),
    db.doc(`users/${a}/blocked_by/${b}`).delete().catch(() => undefined),
  ]);
}

async function ensureFollowing(db, followerId, followeeId) {
  const now = Timestamp.now();
  await db.doc(`users/${followerId}/following/${followeeId}`).set({
    followeeId,
    followerId,
    status: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  }, {merge: true});
  await db.doc(`users/${followeeId}/followers/${followerId}`).set({
    followerId,
    followeeId,
    status: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  }, {merge: true});
}

async function clearFollowing(db, followerId, followeeId) {
  await db.doc(`users/${followerId}/following/${followeeId}`).delete().catch(() => undefined);
  await db.doc(`users/${followeeId}/followers/${followerId}`).delete().catch(() => undefined);
}

async function recentNotifications(db, uid, kind) {
  const snap = await db.collection(`users/${uid}/notifications`)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();
  return snap.docs.filter((doc) => doc.get("kind") === kind);
}

function notifMentionsGroup(doc, groupId) {
  const data = doc.get("data") || {};
  return data.groupId === groupId ||
    doc.get("entityId") === groupId ||
    String(doc.get("route") || "").includes(groupId);
}

async function main() {
  loadWebConfig();
  const {auth, db} = initAdmin();
  const ownerRecord = await auth.getUser(OWNER_UID);
  const peerRecord = await auth.getUser(PEER_UID);
  if (!ownerRecord.email || !peerRecord.email) {
    throw new Error("QA accounts must have emails");
  }
  await auth.updateUser(OWNER_UID, {password: TEMP_PASSWORD});
  await auth.updateUser(PEER_UID, {password: TEMP_PASSWORD});
  await clearBlock(db, OWNER_UID, PEER_UID);

  const owner = await clientFor(ownerRecord.email);
  const peer = await clientFor(peerRecord.email);
  const created = [];

  try {
    // --- Create Public / Private / Hidden ---
    const publicGroup = await owner.invoke("createGroup", {
      name: `${SUITE} Public`,
      description: "Final C1 public",
      category: "running",
      privacy: "public",
      joinPolicy: "open",
      location: {locality: "Haifa", countryCode: "IL"},
    });
    created.push(publicGroup.groupId);
    ok("Owner creates Public group", !!publicGroup.groupId, publicGroup.groupId);

    const privateGroup = await owner.invoke("createGroup", {
      name: `${SUITE} Private`,
      description: "Final C1 private",
      category: "gym",
      privacy: "private",
      joinPolicy: "approvalRequired",
      location: {locality: "Tel Aviv", countryCode: "IL"},
    });
    created.push(privateGroup.groupId);
    ok("Owner creates Private group", !!privateGroup.groupId, privateGroup.groupId);

    const hiddenGroup = await owner.invoke("createGroup", {
      name: `${SUITE} Hidden`,
      description: "Final C1 hidden",
      category: "cycling",
      privacy: "hidden",
      joinPolicy: "inviteOnly",
      location: {locality: "Acre", countryCode: "IL"},
    });
    created.push(hiddenGroup.groupId);
    ok("Owner creates Hidden group", !!hiddenGroup.groupId, hiddenGroup.groupId);

    // --- Discover only Public ---
    const discover = await peer.invoke("listDiscoverableGroups", {limit: 40});
    const ids = (discover.groups || []).map((g) => g.groupId);
    ok(
      "Second account discovers only Public",
      ids.includes(publicGroup.groupId) &&
        !ids.includes(privateGroup.groupId) &&
        !ids.includes(hiddenGroup.groupId),
      `suiteHits=${ids.filter((id) => created.includes(id)).join(",") || "none"}`,
    );
    ok(
      "Stranger cannot get Hidden group",
      await expectDenied(peer.invoke("getGroup", {groupId: hiddenGroup.groupId})),
    );
    ok(
      "Stranger cannot list private schedule",
      await expectDenied(peer.invoke("listGroupSessions", {groupId: privateGroup.groupId})),
    );

    // --- Open join ---
    const openJoin = await peer.invoke("requestJoinGroup", {groupId: publicGroup.groupId});
    ok("Open-group joining", openJoin.status === "member", JSON.stringify(openJoin));
    let publicDoc = await db.doc(`groups/${publicGroup.groupId}`).get();
    ok("memberCount after open join = 2", publicDoc.get("memberCount") === 2);

    const channels = await peer.invoke("getGroupChannels", {groupId: publicGroup.groupId});
    const types = (channels.channels || []).map((c) => c.type || c.channelId);
    ok(
      "Channel contracts member_chat + announcements",
      types.includes("member_chat") && types.includes("announcements"),
      types.join(","),
    );

    // --- Private request → owner notification → accept ---
    const req1 = await peer.invoke("requestJoinGroup", {groupId: privateGroup.groupId});
    ok("Private request queued", req1.status === "pending");
    const ownerReqNotifs = await recentNotifications(db, OWNER_UID, "group_join_request");
    ok(
      "Owner receives join-request notification",
      ownerReqNotifs.some((d) => notifMentionsGroup(d, privateGroup.groupId)),
    );
    await owner.invoke("respondToJoinRequest", {
      groupId: privateGroup.groupId,
      requesterId: PEER_UID,
      decision: "accept",
    });
    ok(
      "Accept adds member",
      (await db.doc(`groups/${privateGroup.groupId}/members/${PEER_UID}`).get()).exists,
    );
    const acceptedNotifs = await recentNotifications(db, PEER_UID, "group_join_accepted");
    ok(
      "Accept notifies requester",
      acceptedNotifs.some((d) => notifMentionsGroup(d, privateGroup.groupId)),
    );

    // Leave private to run decline path cleanly
    await peer.invoke("leaveGroup", {groupId: privateGroup.groupId});
    const afterLeavePrivate = await db.doc(`groups/${privateGroup.groupId}`).get();
    ok(
      "memberCount after leave stays non-negative / =1",
      afterLeavePrivate.get("memberCount") === 1,
      `count=${afterLeavePrivate.get("memberCount")}`,
    );

    // --- Separate request → decline: no decline notification ---
    await peer.invoke("requestJoinGroup", {groupId: privateGroup.groupId});
    const beforeDeclineAccepted = await recentNotifications(db, PEER_UID, "group_join_accepted");
    const beforeDeclineCount = beforeDeclineAccepted.filter(
      (d) => notifMentionsGroup(d, privateGroup.groupId),
    ).length;
    await owner.invoke("respondToJoinRequest", {
      groupId: privateGroup.groupId,
      requesterId: PEER_UID,
      decision: "decline",
    });
    const declinedMember = await db.doc(
      `groups/${privateGroup.groupId}/members/${PEER_UID}`,
    ).get();
    const declinedActive = declinedMember.exists &&
      (declinedMember.get("removedAt") === null ||
        declinedMember.get("removedAt") === undefined) &&
      declinedMember.get("status") !== "removed";
    ok(
      "Decline leaves requester unaffiliated",
      !declinedActive,
      declinedMember.exists ?
        `softRemoved=${!!declinedMember.get("removedAt")}` :
        "missing",
    );
    const afterDeclineAccepted = await recentNotifications(db, PEER_UID, "group_join_accepted");
    const afterDeclineCount = afterDeclineAccepted.filter(
      (d) => notifMentionsGroup(d, privateGroup.groupId),
    ).length;
    ok(
      "Decline sends no notification to requester",
      afterDeclineCount === beforeDeclineCount,
      `before=${beforeDeclineCount} after=${afterDeclineCount}`,
    );

    // --- Invitation eligibility: invitee must follow inviter ---
    await clearFollowing(db, PEER_UID, OWNER_UID);
    ok(
      "Invite denied when invitee does not follow inviter",
      await expectDenied(owner.invoke("inviteToGroup", {
        groupId: hiddenGroup.groupId,
        inviteeId: PEER_UID,
      })),
    );
    await ensureFollowing(db, PEER_UID, OWNER_UID);
    const invite = await owner.invoke("inviteToGroup", {
      groupId: hiddenGroup.groupId,
      inviteeId: PEER_UID,
    });
    ok("Invite succeeds when invitee follows inviter", invite.created === true);

    const dup = await owner.invoke("inviteToGroup", {
      groupId: hiddenGroup.groupId,
      inviteeId: PEER_UID,
    });
    ok("Duplicate invite prevented", dup.created === false);

    // Decline invitation path (cancel then re-invite for accept)
    await peer.invoke("respondToGroupInvitation", {
      groupId: hiddenGroup.groupId,
      decision: "decline",
    });
    ok(
      "Invitation decline works",
      !(await db.doc(`groups/${hiddenGroup.groupId}/invitations/${PEER_UID}`).get()).exists &&
        !(await db.doc(`groups/${hiddenGroup.groupId}/members/${PEER_UID}`).get()).exists,
    );

    const invite2 = await owner.invoke("inviteToGroup", {
      groupId: hiddenGroup.groupId,
      inviteeId: PEER_UID,
    });
    ok("Re-invite after decline", invite2.created === true);
    await owner.invoke("cancelGroupInvitation", {
      groupId: hiddenGroup.groupId,
      inviteeId: PEER_UID,
    });
    ok(
      "Invitation cancellation works",
      !(await db.doc(`groups/${hiddenGroup.groupId}/invitations/${PEER_UID}`).get()).exists,
    );

    const invite3 = await owner.invoke("inviteToGroup", {
      groupId: hiddenGroup.groupId,
      inviteeId: PEER_UID,
    });
    ok("Invite again after cancel", invite3.created === true);
    await peer.invoke("respondToGroupInvitation", {
      groupId: hiddenGroup.groupId,
      decision: "accept",
    });
    ok(
      "Invitation accept joins group",
      (await db.doc(`groups/${hiddenGroup.groupId}/members/${PEER_UID}`).get()).exists,
    );

    // Re-join private for role tests
    await peer.invoke("requestJoinGroup", {groupId: privateGroup.groupId});
    await owner.invoke("respondToJoinRequest", {
      groupId: privateGroup.groupId,
      requesterId: PEER_UID,
      decision: "accept",
    });

    // --- Promote / demote ---
    await owner.invoke("setGroupMemberRole", {
      groupId: privateGroup.groupId,
      memberId: PEER_UID,
      role: "admin",
    });
    ok(
      "Promote member to admin",
      (await db.doc(`groups/${privateGroup.groupId}/members/${PEER_UID}`).get()).get("role") ===
        "admin",
    );
    ok(
      "Admin cannot remove owner",
      await expectDenied(peer.invoke("removeGroupMember", {
        groupId: privateGroup.groupId,
        memberId: OWNER_UID,
      })),
    );
    ok(
      "Admin cannot transfer ownership",
      await expectDenied(peer.invoke("transferGroupOwnership", {
        groupId: privateGroup.groupId,
        newOwnerId: PEER_UID,
      })),
    );
    ok(
      "Owner cannot leave without transfer",
      await expectDenied(owner.invoke("leaveGroup", {groupId: privateGroup.groupId})),
    );
    await owner.invoke("setGroupMemberRole", {
      groupId: privateGroup.groupId,
      memberId: PEER_UID,
      role: "member",
    });
    ok(
      "Demote admin to member",
      (await db.doc(`groups/${privateGroup.groupId}/members/${PEER_UID}`).get()).get("role") ===
        "member",
    );

    // --- Schedule create / edit / list / cancel ---
    const session = await owner.invoke("createGroupSession", {
      groupId: privateGroup.groupId,
      title: `${SUITE} Session`,
      activity: "strength",
      startAt: new Date(Date.now() + 3600_000).toISOString(),
      endAt: new Date(Date.now() + 7200_000).toISOString(),
      description: "Final C1 schedule",
      capacity: 8,
      location: {locality: "Haifa"},
    });
    ok("Create scheduled session", !!session.sessionId, session.sessionId);
    await owner.invoke("updateGroupSession", {
      groupId: privateGroup.groupId,
      sessionId: session.sessionId,
      title: `${SUITE} Session Edited`,
      description: "Edited",
    });
    const listed = await peer.invoke("listGroupSessions", {groupId: privateGroup.groupId});
    const found = (listed.sessions || []).find((s) => s.sessionId === session.sessionId);
    ok("List/edit session visible to member", !!found && /Edited|edited/i.test(String(found.title || found.description || "Edited")));
    await owner.invoke("cancelGroupSession", {
      groupId: privateGroup.groupId,
      sessionId: session.sessionId,
    });
    const cancelled = await db.doc(
      `groups/${privateGroup.groupId}/sessions/${session.sessionId}`,
    ).get();
    ok("Cancel scheduled session", cancelled.get("status") === "cancelled");

    // --- Remove member ---
    const beforeRemoveCount = (await db.doc(`groups/${privateGroup.groupId}`).get())
      .get("memberCount");
    await owner.invoke("removeGroupMember", {
      groupId: privateGroup.groupId,
      memberId: PEER_UID,
    });
    ok(
      "Remove member works",
      !(await db.doc(`groups/${privateGroup.groupId}/members/${PEER_UID}`).get()).exists ||
        !!(await db.doc(`groups/${privateGroup.groupId}/members/${PEER_UID}`).get()).get("removedAt"),
    );
    const afterRemoveCount = (await db.doc(`groups/${privateGroup.groupId}`).get())
      .get("memberCount");
    ok(
      "memberCount decremented after remove",
      afterRemoveCount === beforeRemoveCount - 1 && afterRemoveCount >= 1,
      `${beforeRemoveCount}→${afterRemoveCount}`,
    );

    // --- Blocked users ---
    await peer.invoke("leaveGroup", {groupId: publicGroup.groupId}).catch(() => undefined);
    await owner.invoke("blockUser", {targetUserId: PEER_UID});
    ok(
      "Blocked cannot request join",
      await expectDenied(peer.invoke("requestJoinGroup", {groupId: publicGroup.groupId})),
    );
    ok(
      "Blocked cannot invite",
      await expectDenied(owner.invoke("inviteToGroup", {
        groupId: hiddenGroup.groupId,
        inviteeId: PEER_UID,
      })),
    );
    ok(
      "Blocked cannot view private group",
      await expectDenied(peer.invoke("getGroup", {groupId: privateGroup.groupId})),
    );
    try {
      await owner.invoke("unblockUser", {profileId: PEER_UID});
    } catch {
      await clearBlock(db, OWNER_UID, PEER_UID);
    }
    await clearBlock(db, OWNER_UID, PEER_UID);

    // --- Report group ---
    await peer.invoke("requestJoinGroup", {groupId: publicGroup.groupId}).catch(() => undefined);
    const report = await peer.invoke("reportGroup", {
      groupId: publicGroup.groupId,
      reason: "spam",
    });
    ok("Report group", !!report.reportId, report.reportId);
    const reportDoc = await db.doc(`reports/${report.reportId}`).get();
    ok(
      "Report stored with group targetType",
      reportDoc.exists &&
        reportDoc.get("targetType") === "group" &&
        reportDoc.get("targetId") === publicGroup.groupId,
    );

    // --- Username / profile surface (avatar/username → profile) ---
    const ownerProfile = await db.doc(`users/${OWNER_UID}`).get();
    const peerProfile = await db.doc(`users/${PEER_UID}`).get();
    const ownerUsername = ownerProfile.get("username");
    const peerUsername = peerProfile.get("username");
    const surface = await peer.invoke("getPublicProfile", {username: ownerUsername});
    ok(
      "Username opens corresponding profile surface",
      !!surface && (surface.profile?.username === ownerUsername ||
        surface.username === ownerUsername ||
        surface.preview?.username === ownerUsername),
      ownerUsername,
    );
    const reverse = await owner.invoke("getPublicProfile", {username: peerUsername});
    ok(
      "Peer username resolves profile",
      !!reverse && (reverse.profile?.username === peerUsername ||
        reverse.username === peerUsername ||
        reverse.preview?.username === peerUsername),
      peerUsername,
    );

    // --- Regression smokes for Phase A/B surfaces ---
    const relationship = await peer.invoke("getProfileRelationship", {
      profileId: OWNER_UID,
    }).catch(() => null);
    ok("Profile relationship callable alive", relationship !== null);

    const inbox = await owner.invoke("listMyGroups", {limit: 20});
    ok("listMyGroups works for owner", Array.isArray(inbox.groups || inbox.items || inbox));

    // Cleanup
    for (const groupId of created) {
      try {
        await owner.invoke("deleteGroup", {groupId});
      } catch {
        await db.doc(`groups/${groupId}`).set({
          status: "deleted",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
    ok("Cleanup soft-delete suite groups", true);
  } finally {
    await owner.close().catch(() => undefined);
    await peer.close().catch(() => undefined);
  }

  const failed = results.filter((r) => !r.pass);
  console.log(`\nFinal C1 Groups staging QA: ${results.length - failed.length}/${results.length} passed`);
  if (failed.length) {
    for (const f of failed) console.log(`  FAIL: ${f.label} ${f.detail || ""}`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
