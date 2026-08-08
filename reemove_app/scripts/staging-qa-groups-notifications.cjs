#!/usr/bin/env node
/**
 * Phase Groups — Staging QA for group-specific notifications (Req #5).
 *
 * Automation scope:
 * - Verifies backend suppression for disabled categories (member chat,
 *   announcements, sessions/events, invitations).
 * - Verifies group-level "muted" suppresses at least member-chat notifications.
 *
 * Two-account model (staging only):
 * - Account A/Owner: STAGING_OWNER_EMAIL (default: meliodasin14@gmail.com)
 * - Account B/Peer:  STAGING_PEER_EMAIL  (default: abualamostaf@gmail.com)
 *
 * Optional env:
 * - STAGING_OWNER_PASSWORD / STAGING_PEER_PASSWORD
 *
 * Usage (from reemove_app/):
 *   node scripts/staging-qa-groups-notifications.cjs
 */
"use strict";

const path = require("node:path");
const fs = require("node:fs");

const {initializeApp, getApps, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const {initializeApp: initClientApp} = require("firebase/app");
const {
  getAuth: getClientAuth,
  signInWithEmailAndPassword,
} = require("firebase/auth");
const {getFunctions, httpsCallable} = require("firebase/functions");

const PROJECT_ID = "reemove-staging";
const REGION = "europe-west1";
const STORAGE_BUCKET = "reemove-staging.firebasestorage.app";

const OWNER_EMAIL =
  process.env.STAGING_OWNER_EMAIL || "meliodasin14@gmail.com";
const PEER_EMAIL = process.env.STAGING_PEER_EMAIL || "abualamostaf@gmail.com";
const OWNER_PASSWORD_ENV = process.env.STAGING_OWNER_PASSWORD || "";
const PEER_PASSWORD_ENV = process.env.STAGING_PEER_PASSWORD || "";
const TEMP_PASSWORD = `PhaseNotif-QA-${Date.now()}!Aa1`;

const SCHEMA_VERSION = "1";
const SUITE = `notif-${Date.now().toString(36)}`;

const webConfig = {
  apiKey: process.env.STAGING_WEB_API_KEY || "",
  authDomain: `${PROJECT_ID}.firebaseapp.com`,
  projectId: PROJECT_ID,
  appId: "",
  storageBucket: STORAGE_BUCKET,
};

const results = [];

function ok(label, pass, detail = "") {
  console.log(`[${pass ? "PASS" : "FAIL"}] ${label}${detail ? ` — ${detail}` : ""}`);
  results.push({label, pass: !!pass, detail});
  return !!pass;
}

function skip(label, reason) {
  console.log(`[SKIP] ${label} — ${reason}`);
  results.push({label, pass: false, detail: `SKIP: ${reason}`});
}

function loadWebConfig() {
  if (webConfig.apiKey && webConfig.appId) return;
  const text = fs.readFileSync(
    path.join(__dirname, "../lib/firebase_options_staging.dart"),
    "utf8",
  );
  const webBlock = text.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/,
  )?.[1] || text;
  webConfig.apiKey =
    webConfig.apiKey ||
    webBlock.match(/apiKey:\s*'([^']+)'/)?.[1] ||
    "";
  webConfig.appId =
    webConfig.appId || webBlock.match(/appId:\s*'([^']+)'/)?.[1] || "";
  if (!webConfig.apiKey || !webConfig.appId) {
    throw new Error("Could not read staging web apiKey/appId");
  }
}

function initAdmin() {
  if (getApps().length === 0) {
    initializeApp({
      credential: applicationDefault(),
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET,
    });
  }
  return {auth: getAuth(), db: getFirestore()};
}

async function clientFor(email, password) {
  const app = initClientApp({...webConfig}, `qa-${email}-${Date.now()}`);
  const auth = getClientAuth(app);
  const functions = getFunctions(app, REGION);
  await signInWithEmailAndPassword(auth, email, password);

  const call = (name, timeoutMs = 60000) =>
    httpsCallable(functions, name, {timeout: timeoutMs});

  return {
    uid: auth.currentUser.uid,
    invoke: async (name, data = {}) => (await call(name)(data)).data,
  };
}

async function recentNotifications(db, uid, kind) {
  // Keep this small + kind-scoped to reduce query cost on staging.
  const snap = await db
    .collection(`users/${uid}/notifications`)
    .where("kind", "==", kind)
    .limit(20)
    .get();

  return snap.docs.map((d) => d.data());
}

async function groupDoc(db, groupId) {
  const snap = await db.collection("groups").doc(groupId).get();
  if (!snap.exists) throw new Error(`Missing groups/${groupId}`);
  return snap;
}

async function main() {
  if (PROJECT_ID !== "reemove-staging") {
    throw new Error("Refusing to run outside reemove-staging");
  }

  loadWebConfig();
  const {auth, db} = initAdmin();

  const ownerRecord = await auth.getUserByEmail(OWNER_EMAIL);
  const peerRecord = await auth.getUserByEmail(PEER_EMAIL);

  const OWNER_UID = ownerRecord.uid;
  const PEER_UID = peerRecord.uid;

  let ownerPassword = OWNER_PASSWORD_ENV;
  let peerPassword = PEER_PASSWORD_ENV;
  if (!ownerPassword || !peerPassword) {
    console.log("Password env missing — resetting temporary passwords via Admin SDK");
    await auth.updateUser(OWNER_UID, {password: TEMP_PASSWORD});
    await auth.updateUser(PEER_UID, {password: TEMP_PASSWORD});
    ownerPassword = TEMP_PASSWORD;
    peerPassword = TEMP_PASSWORD;
  }

  const owner = await clientFor(OWNER_EMAIL, ownerPassword);
  const peer = await clientFor(PEER_EMAIL, peerPassword);

  ok("Owner signed in", owner.uid === OWNER_UID);
  ok("Peer signed in", peer.uid === PEER_UID);

  // 1) member chat + announcements + mute behavior
  {
    const groupId = await owner.invoke("createGroup", {
      name: `${SUITE} member-chat`,
      description: "Req #5 QA group",
      category: "running",
      privacy: "public",
      joinPolicy: "open",
      capacity: 50,
      location: {
        locality: "Haifa",
        administrativeArea: "Haifa District",
        countryCode: "IL",
        text: "Haifa, IL",
      },
    });

    const createdGroupId = groupId.groupId || groupId.data?.groupId || "";
    ok("createGroup (member chat test)", !!createdGroupId, createdGroupId);

    const gid = createdGroupId;
    await peer.invoke("requestJoinGroup", {groupId: gid});

    const group = await owner.invoke("getGroup", {groupId: gid});
    const memberChatConversationId = group.memberChatConversationId || "";
    const announcementsConversationId = group.announcementsConversationId || "";
    ok(
      "Conversation IDs reserved",
      !!memberChatConversationId && !!announcementsConversationId,
      `chat=${memberChatConversationId} ann=${announcementsConversationId}`,
    );

    // Disable member chat for peer.
    await peer.invoke("updateGroupNotificationPreferences", {
      groupId: gid,
      preferences: {
        muted: false,
        memberChatEnabled: false,
        announcementsEnabled: true,
        sessionsEnabled: true,
        invitationsEnabled: true,
        schemaVersion: Number(SCHEMA_VERSION),
      },
    });

    await owner.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: `${SUITE}-member-chat-disabled`,
      text: "staging: should NOT notify member for member chat",
      mediaMode: "normal",
      attachments: [],
    });
    await new Promise((r) => setTimeout(r, 2000));

    const memberChatNotifs = await recentNotifications(db, PEER_UID, "conversation_message");
    const memberChatHit = memberChatNotifs.some((n) => {
      const data = n.data || {};
      return data.groupId === gid && data.channelType === "member_chat";
    });
    ok("Member chat notifications suppressed", !memberChatHit);

    // Announcements should still notify (announcementsEnabled=true).
    await owner.invoke("sendMessage", {
      conversationId: announcementsConversationId,
      clientMessageId: `${SUITE}-announcements-enabled`,
      text: "staging: should notify member for announcements",
      mediaMode: "normal",
      attachments: [],
    });
    await new Promise((r) => setTimeout(r, 2000));

    const announcementNotifs = await recentNotifications(db, PEER_UID, "group_announcement");
    const annHit = announcementNotifs.some((n) => {
      const data = n.data || {};
      return data.groupId === gid && data.channelType === "announcements";
    });
    ok("Announcements notifications allowed", annHit);

    // Group-level mute should suppress member chat as well.
    await peer.invoke("updateGroupNotificationPreferences", {
      groupId: gid,
      preferences: {
        muted: true,
        memberChatEnabled: true,
        announcementsEnabled: true,
        sessionsEnabled: true,
        invitationsEnabled: true,
        schemaVersion: Number(SCHEMA_VERSION),
      },
    });
    await owner.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: `${SUITE}-member-chat-muted`,
      text: "staging: muted group should suppress member chat",
      mediaMode: "normal",
      attachments: [],
    });
    await new Promise((r) => setTimeout(r, 2000));

    const mutedNotifs = await recentNotifications(db, PEER_UID, "conversation_message");
    const mutedHit = mutedNotifs.some((n) => {
      const data = n.data || {};
      return data.groupId === gid && data.channelType === "member_chat";
    });
    ok("Muted group suppresses member chat", !mutedHit);
  }

  // 2) invitations inbox suppression
  {
    const groupIdResp = await owner.invoke("createGroup", {
      name: `${SUITE} invitations`,
      description: "Req #5 QA group",
      category: "running",
      privacy: "private",
      joinPolicy: "approvalRequired",
      capacity: 50,
      location: {
        locality: "Haifa",
        administrativeArea: "Haifa District",
        countryCode: "IL",
        text: "Haifa, IL",
      },
    });

    const gid = groupIdResp.groupId || groupIdResp.data?.groupId || "";
    ok("createGroup (invitations test)", !!gid, gid);

    await owner.invoke("updateGroupNotificationPreferences", {
      groupId: gid,
      preferences: {
        muted: false,
        memberChatEnabled: true,
        announcementsEnabled: true,
        sessionsEnabled: true,
        invitationsEnabled: false,
        schemaVersion: Number(SCHEMA_VERSION),
      },
    });

    await peer.invoke("requestJoinGroup", {groupId: gid});
    await new Promise((r) => setTimeout(r, 2000));

    const ownerJoinNotifs = await recentNotifications(
      db,
      OWNER_UID,
      "group_join_request",
    );
    const hit = ownerJoinNotifs.some((n) => {
      const data = n.data || {};
      return data.requesterId === PEER_UID && data.groupId === gid;
    });
    ok("Invitations notifications suppressed", !hit);
  }

  // 3) sessions/events inbox suppression
  {
    const groupIdResp = await owner.invoke("createGroup", {
      name: `${SUITE} sessions`,
      description: "Req #5 QA group",
      category: "running",
      privacy: "private",
      joinPolicy: "approvalRequired",
      capacity: 50,
      location: {
        locality: "Haifa",
        administrativeArea: "Haifa District",
        countryCode: "IL",
        text: "Haifa, IL",
      },
    });

    const gid = groupIdResp.groupId || groupIdResp.data?.groupId || "";
    ok("createGroup (sessions test)", !!gid, gid);

    await peer.invoke("requestJoinGroup", {groupId: gid});
    await owner.invoke("respondToJoinRequest", {
      groupId: gid,
      requesterId: PEER_UID,
      decision: "accept",
    });

    await peer.invoke("updateGroupNotificationPreferences", {
      groupId: gid,
      preferences: {
        muted: false,
        memberChatEnabled: true,
        announcementsEnabled: true,
        sessionsEnabled: false,
        invitationsEnabled: true,
        schemaVersion: Number(SCHEMA_VERSION),
      },
    });

    const startAt = new Date(Date.now() + 3600_000).toISOString();
    const endAt = new Date(Date.now() + 7200_000).toISOString();

    const created = await owner.invoke("createGroupSession", {
      groupId: gid,
      title: "Friday match",
      sessionType: "match",
      capacity: 1,
      startAt,
      endAt,
    });

    const sessionId = created.sessionId || created.data?.sessionId;
    ok("createGroupSession returned sessionId", !!sessionId, String(sessionId || ""));

    await new Promise((r) => setTimeout(r, 2500));

    const sessionNotifs = await recentNotifications(
      db,
      PEER_UID,
      "group_session_scheduled",
    );

    const hit = sessionNotifs.some((n) => n.entityId === sessionId);
    ok("Sessions/events notifications suppressed", !hit);
  }

  console.log("\nSummary:", results);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


