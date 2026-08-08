#!/usr/bin/env node
/**
 * Groups channel message moderation staging QA (two accounts).
 * Staging only. Exercises deleteMessage manager moderation on member chat
 * and announcements.
 *
 * Usage (from reemove_app/):
 *   NODE_PATH=functions/node_modules node scripts/staging-qa-groups-moderation.cjs
 *
 * Manual UI QA (after hard-refresh http://127.0.0.1:7357):
 * 1. Account A (owner) opens group → Member chat.
 * 2. Account B sends a text message.
 * 3. Account A long-presses B's message → Delete message (manager) → confirm.
 * 4. Confirm tombstone “Message deleted”; reply still works with placeholder.
 * 5. Account B long-presses A's message → must NOT see manager delete (Report only).
 * 6. Repeat in Announcements: A posts, B cannot delete A's post; A can remove B's if B could post (members cannot publish announcements).
 */
"use strict";

const path = require("node:path");
const fs = require("node:fs");

const functionsNm = path.join(__dirname, "../functions/node_modules");
if (!module.paths.includes(functionsNm)) {
  module.paths.unshift(functionsNm);
}

const {initializeApp, getApps, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {initializeApp: initClient} = require("firebase/app");
const {
  getAuth: getClientAuth,
  signInWithEmailAndPassword,
  signOut,
} = require("firebase/auth");
const {getFunctions, httpsCallable} = require("firebase/functions");

const PROJECT_ID = "reemove-staging";
const REGION = "europe-west1";
const SUITE = `mod-${Date.now().toString(36)}`;

const OWNER_EMAIL =
  process.env.STAGING_OWNER_EMAIL || "meliodasin14@gmail.com";
const PEER_EMAIL =
  process.env.STAGING_PEER_EMAIL || "abualamostaf@gmail.com";
const OWNER_PASSWORD_ENV = process.env.STAGING_OWNER_PASSWORD || "";
const PEER_PASSWORD_ENV = process.env.STAGING_PEER_PASSWORD || "";
const TEMP_PASSWORD = `PhaseMod-QA-${Date.now()}!Aa1`;

const webConfig = {
  apiKey: process.env.STAGING_WEB_API_KEY || "",
  authDomain: `${PROJECT_ID}.firebaseapp.com`,
  projectId: PROJECT_ID,
  appId: "",
};

const results = [];

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
  webConfig.appId = webBlock.match(/appId:\s*'([^']+)'/)?.[1] || "";
}

function initAdmin() {
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId: PROJECT_ID});
  }
  return {auth: getAuth(), db: getFirestore()};
}

function ok(label, pass, detail = "") {
  console.log(`[${pass ? "PASS" : "FAIL"}] ${label}${detail ? ` — ${detail}` : ""}`);
  results.push({label, pass: !!pass, detail});
  return !!pass;
}

async function expectDenied(promise) {
  try {
    await promise;
    return {denied: false, code: ""};
  } catch (error) {
    const code = String(error.code || error.message || error);
    return {
      denied: /permission-denied|failed-precondition|invalid-argument/i.test(code),
      code,
    };
  }
}

async function clientFor(email, password) {
  const app = initClient({...webConfig}, `mod-${email}-${Date.now()}`);
  const auth = getClientAuth(app);
  const functions = getFunctions(app, REGION);
  await signInWithEmailAndPassword(auth, email, password);
  const call = (name) => httpsCallable(functions, name, {timeout: 60000});
  return {
    uid: auth.currentUser.uid,
    async invoke(name, data = {}) {
      return (await call(name)(data)).data;
    },
    async close() {
      await signOut(auth);
    },
  };
}

async function main() {
  if (PROJECT_ID !== "reemove-staging") {
    throw new Error("Refusing to run outside reemove-staging");
  }
  loadWebConfig();
  const {auth, db} = initAdmin();
  const ownerRecord = await auth.getUserByEmail(OWNER_EMAIL);
  const peerRecord = await auth.getUserByEmail(PEER_EMAIL);
  const ownerPassword = OWNER_PASSWORD_ENV || TEMP_PASSWORD;
  const peerPassword = PEER_PASSWORD_ENV || TEMP_PASSWORD;
  if (!OWNER_PASSWORD_ENV) {
    await auth.updateUser(ownerRecord.uid, {password: ownerPassword});
  }
  if (!PEER_PASSWORD_ENV) {
    await auth.updateUser(peerRecord.uid, {password: peerPassword});
  }

  const owner = await clientFor(OWNER_EMAIL, ownerPassword);
  const peer = await clientFor(PEER_EMAIL, peerPassword);
  console.log(`Moderation QA suite=${SUITE}`);

  try {
    const created = await owner.invoke("createGroup", {
      name: `${SUITE} Moderation`,
      description: "Channel moderation QA",
      category: "running",
      privacy: "hidden",
      joinPolicy: "open",
      capacity: 20,
      location: {locality: "Haifa", countryCode: "IL"},
    });
    const groupId = created.groupId;
    ok("create open group", !!groupId, groupId);

    await peer.invoke("requestJoinGroup", {groupId});
    const group = await owner.invoke("getGroup", {groupId});
    const memberChatId = group.memberChatConversationId;
    const announcementsId = group.announcementsConversationId;
    ok(
      "group has member chat + announcements",
      !!memberChatId && !!announcementsId,
    );

    const peerMsg = await peer.invoke("sendMessage", {
      conversationId: memberChatId,
      clientMessageId: `${SUITE}-peer`,
      text: "Delete me via moderation",
      mediaMode: "normal",
    });
    ok("peer sends member chat message", !!peerMsg.messageId, peerMsg.messageId);

    const memberDenied = await expectDenied(
      peer.invoke("deleteMessage", {
        conversationId: memberChatId,
        messageId: peerMsg.messageId,
      }),
    );
    ok(
      "member cannot delete peer message",
      memberDenied.denied,
      memberDenied.code,
    );

    const modDel = await owner.invoke("deleteMessage", {
      conversationId: memberChatId,
      messageId: peerMsg.messageId,
    });
    const tombstone = await db
      .doc(`conversations/${memberChatId}/messages/${peerMsg.messageId}`)
      .get();
    ok(
      "owner moderates peer message",
      modDel.deleted === true &&
        tombstone.get("isDeleted") === true &&
        tombstone.get("deletedBy") === owner.uid,
      `deletedBy=${tombstone.get("deletedBy")}`,
    );

    const reply = await peer.invoke("sendMessage", {
      conversationId: memberChatId,
      clientMessageId: `${SUITE}-reply`,
      text: "reply after delete",
      mediaMode: "normal",
      replyToMessageId: peerMsg.messageId,
    });
    const replyDoc = await db
      .doc(`conversations/${memberChatId}/messages/${reply.messageId}`)
      .get();
    const replyTo = replyDoc.get("replyTo") || {};
    ok(
      "reply shows deleted placeholder",
      reply.created === true &&
        replyTo.messageId === peerMsg.messageId &&
        (replyTo.isDeleted === true || replyTo.kind === "deleted"),
      JSON.stringify(replyTo),
    );

    const annMsg = await owner.invoke("sendMessage", {
      conversationId: announcementsId,
      clientMessageId: `${SUITE}-ann`,
      text: "Announcement to remove",
      mediaMode: "normal",
    });
    const annDel = await owner.invoke("deleteMessage", {
      conversationId: announcementsId,
      messageId: annMsg.messageId,
    });
    ok("owner deletes announcement message", annDel.deleted === true);

    await owner.invoke("deleteGroup", {groupId}).catch(() => undefined);
  } finally {
    await owner.close().catch(() => undefined);
    await peer.close().catch(() => undefined);
  }

  const failed = results.filter((r) => !r.pass).length;
  console.log(`\nModeration QA: ${results.length - failed}/${results.length} passed`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

