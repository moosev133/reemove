#!/usr/bin/env node
/**
 * Phase C3 Groups staging QA — typed schedules, RSVP, session notifications.
 * Staging project only. Does not use apply:true backfills.
 *
 * Usage (from reemove_app/):
 *   NODE_PATH=functions/node_modules node scripts/staging-qa-groups-c3.cjs
 *
 * Env (optional):
 *   STAGING_OWNER_EMAIL / STAGING_OWNER_PASSWORD
 *   STAGING_PEER_EMAIL / STAGING_PEER_PASSWORD
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
const SUITE = `c3-${Date.now().toString(36)}`;

const OWNER_EMAIL =
  process.env.STAGING_OWNER_EMAIL || "meliodasin14@gmail.com";
const PEER_EMAIL =
  process.env.STAGING_PEER_EMAIL || "abualamostaf@gmail.com";
const OWNER_PASSWORD_ENV = process.env.STAGING_OWNER_PASSWORD || "";
const PEER_PASSWORD_ENV = process.env.STAGING_PEER_PASSWORD || "";
const TEMP_PASSWORD = `PhaseC3-QA-${Date.now()}!Aa1`;

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
    initializeApp({
      credential: applicationDefault(),
      projectId: PROJECT_ID,
    });
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
      denied: /permission-denied|resource-exhausted|failed-precondition/i.test(code),
      code,
    };
  }
}

async function clientFor(email, password) {
  const app = initClient({...webConfig}, `c3-${email}-${Date.now()}`);
  const auth = getClientAuth(app);
  const functions = getFunctions(app, REGION);
  await signInWithEmailAndPassword(auth, email, password);
  const call = (name) => httpsCallable(functions, name, {timeout: 60000});
  return {
    uid: auth.currentUser.uid,
    async invoke(name, data = {}) {
      const result = await call(name)(data);
      return result.data;
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
  console.log(`C3 Schedule QA suite=${SUITE}`);

  try {
    const created = await owner.invoke("createGroup", {
      name: `${SUITE} Schedule`,
      description: "Phase C3 typed schedule + RSVP",
      category: "running",
      privacy: "public",
      joinPolicy: "open",
      capacity: 20,
      location: {locality: "Haifa", countryCode: "IL"},
    });
    const groupId = created.groupId;
    ok("create group", !!groupId, groupId);

    await peer.invoke("requestJoinGroup", {groupId});

    const session = await owner.invoke("createGroupSession", {
      groupId,
      title: "Saturday training",
      sessionType: "training",
      capacity: 1,
      startAt: new Date(Date.now() + 3600_000).toISOString(),
      endAt: new Date(Date.now() + 7200_000).toISOString(),
    });
    ok("create typed training session", !!session.sessionId, session.sessionId);

    const listed = await peer.invoke("listGroupSessions", {groupId});
    const row = (listed.sessions || []).find((s) => s.sessionId === session.sessionId);
    ok("peer lists sessionType=training", row?.sessionType === "training", JSON.stringify(row));

    await peer.invoke("respondToGroupSessionRsvp", {
      groupId,
      sessionId: session.sessionId,
      status: "going",
    });
    const after = await peer.invoke("listGroupSessions", {groupId});
    const rsvped = (after.sessions || []).find((s) => s.sessionId === session.sessionId);
    ok(
      "peer RSVP going reflected",
      rsvped?.viewerRsvp === "going" && rsvped?.rsvpCounts?.going === 1,
      JSON.stringify(rsvped),
    );

    const capacityDenied = await expectDenied(owner.invoke("respondToGroupSessionRsvp", {
      groupId,
      sessionId: session.sessionId,
      status: "going",
    }));
    ok("capacity enforced", capacityDenied.denied, capacityDenied.code);

    const notif = await db.collection(`users/${peerRecord.uid}/notifications`)
      .where("kind", "==", "group_session_scheduled")
      .where("entityId", "==", session.sessionId)
      .limit(5)
      .get();
    ok("peer received session scheduled notification", !notif.empty);

    await owner.invoke("cancelGroupSession", {
      groupId,
      sessionId: session.sessionId,
    });
    const cancelDenied = await expectDenied(peer.invoke("respondToGroupSessionRsvp", {
      groupId,
      sessionId: session.sessionId,
      status: "maybe",
    }));
    ok("cancelled session rejects RSVP", cancelDenied.denied, cancelDenied.code);

    await owner.invoke("deleteGroup", {groupId}).catch(() => undefined);
  } finally {
    await owner.close().catch(() => undefined);
    await peer.close().catch(() => undefined);
  }

  const failed = results.filter((r) => !r.pass).length;
  console.log(`\nC3 QA: ${results.length - failed}/${results.length} passed`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

