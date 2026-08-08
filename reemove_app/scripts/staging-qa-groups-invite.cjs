#!/usr/bin/env node
/**
 * Groups invite-sending staging QA (two accounts).
 * Staging only. Reuses inviteToGroup / listGroupPendingInvitations.
 *
 * Usage (from reemove_app/):
 *   NODE_PATH=functions/node_modules node scripts/staging-qa-groups-invite.cjs
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
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeApp: initClient} = require("firebase/app");
const {
  getAuth: getClientAuth,
  signInWithEmailAndPassword,
  signOut,
} = require("firebase/auth");
const {getFunctions, httpsCallable} = require("firebase/functions");

const PROJECT_ID = "reemove-staging";
const REGION = "europe-west1";
const SUITE = `inv-${Date.now().toString(36)}`;

const OWNER_EMAIL =
  process.env.STAGING_OWNER_EMAIL || "meliodasin14@gmail.com";
const PEER_EMAIL =
  process.env.STAGING_PEER_EMAIL || "abualamostaf@gmail.com";
const OWNER_PASSWORD_ENV = process.env.STAGING_OWNER_PASSWORD || "";
const PEER_PASSWORD_ENV = process.env.STAGING_PEER_PASSWORD || "";
const TEMP_PASSWORD = `PhaseInvite-QA-${Date.now()}!Aa1`;

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
  const app = initClient({...webConfig}, `inv-${email}-${Date.now()}`);
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

async function ensurePeerFollowsOwner(db, peerUid, ownerUid) {
  const now = Timestamp.now();
  await db.doc(`users/${peerUid}/following/${ownerUid}`).set({
    followeeId: ownerUid,
    followerId: peerUid,
    status: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  }, {merge: true});
  await db.doc(`users/${ownerUid}/followers/${peerUid}`).set({
    followerId: peerUid,
    followeeId: ownerUid,
    status: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  }, {merge: true});
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

  await ensurePeerFollowsOwner(db, peerRecord.uid, ownerRecord.uid);

  const owner = await clientFor(OWNER_EMAIL, ownerPassword);
  const peer = await clientFor(PEER_EMAIL, peerPassword);
  console.log(`Invite QA suite=${SUITE}`);

  try {
    const created = await owner.invoke("createGroup", {
      name: `${SUITE} Invite`,
      description: "Invite UI staging QA",
      category: "running",
      privacy: "hidden",
      joinPolicy: "inviteOnly",
      capacity: 20,
      location: {locality: "Haifa", countryCode: "IL"},
    });
    const groupId = created.groupId;
    ok("create invite-only group", !!groupId, groupId);

    const memberDenied = await expectDenied(
      peer.invoke("listGroupPendingInvitations", {groupId}),
    );
    ok("non-manager cannot list pending invitations", memberDenied.denied, memberDenied.code);

    const invite = await owner.invoke("inviteToGroup", {
      groupId,
      inviteeId: peer.uid,
    });
    ok("owner invites peer", invite.created === true, JSON.stringify(invite));

    const pending = await owner.invoke("listGroupPendingInvitations", {groupId});
    ok(
      "pending list includes peer",
      (pending.invitations || []).some((i) => i.inviteeId === peer.uid),
      JSON.stringify(pending),
    );

    const dup = await owner.invoke("inviteToGroup", {
      groupId,
      inviteeId: peer.uid,
    });
    ok("duplicate invite is idempotent", dup.created === false);

    const inbox = await peer.invoke("listMyGroupInvitations", {});
    ok(
      "peer inbox shows invitation",
      (inbox.invitations || []).some((i) => i.groupId === groupId),
    );

    await owner.invoke("cancelGroupInvitation", {
      groupId,
      inviteeId: peer.uid,
    });
    const afterCancel = await owner.invoke("listGroupPendingInvitations", {groupId});
    ok(
      "cancel removes pending invite",
      !(afterCancel.invitations || []).some((i) => i.inviteeId === peer.uid),
    );

    await owner.invoke("deleteGroup", {groupId}).catch(() => undefined);
  } finally {
    await owner.close().catch(() => undefined);
    await peer.close().catch(() => undefined);
  }

  const failed = results.filter((r) => !r.pass).length;
  console.log(`\nInvite QA: ${results.length - failed}/${results.length} passed`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

