#!/usr/bin/env node
/**
 * Phase B staging QA via Admin password reset + client callable SDK.
 * Staging project only. Does not use apply:true backfills.
 */
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
const fs = require("node:fs");
const path = require("node:path");

const PROJECT_ID = "reemove-staging";
const REGION = "europe-west1";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";
const TEMP_PASSWORD = `PhaseB-QA-${Date.now()}!Aa1`;

const webConfig = {
  apiKey: "",
  authDomain: `${PROJECT_ID}.firebaseapp.com`,
  projectId: PROJECT_ID,
  appId: "",
};

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
    auth,
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
  return !!pass;
}

async function main() {
  loadWebConfig();
  const {auth, db} = initAdmin();
  const results = [];

  const mainUserRecord = await auth.getUser(MAIN_UID);
  const secondUserRecord = await auth.getUser(SECOND_UID);
  if (!mainUserRecord.email || !secondUserRecord.email) {
    throw new Error("QA accounts must have emails");
  }
  await auth.updateUser(MAIN_UID, {password: TEMP_PASSWORD});
  await auth.updateUser(SECOND_UID, {password: TEMP_PASSWORD});

  const main = await clientFor(mainUserRecord.email);
  const second = await clientFor(secondUserRecord.email);

  try {
    const mainUser = await db.doc(`users/${MAIN_UID}`).get();
    const secondUser = await db.doc(`users/${SECOND_UID}`).get();
    results.push(ok("main profile exists", mainUser.exists));
    results.push(ok("second profile exists", secondUser.exists));
    const mainUsername = String(mainUser.get("username") || "mustafaabualhija");
    const secondUsername = String(secondUser.get("username") || "mmmmmm");

    const report = await second.invoke("reportContent", {
      targetType: "user",
      targetId: MAIN_UID,
      reason: "harassment",
      details: "Phase B staging QA report",
    });
    results.push(ok("reportContent returns success", !!report));
    const reports = await db.collection("reports")
      .where("reporterId", "==", SECOND_UID)
      .where("targetId", "==", MAIN_UID)
      .limit(5)
      .get();
    results.push(ok("report stored for target user", reports.size >= 1, `count=${reports.size}`));

    const privatePreview = await second.invoke("getPublicProfile", {
      username: mainUsername,
    });
    results.push(ok(
      "visit private/public profile returns access",
      typeof privatePreview.access === "string",
      `access=${privatePreview.access}`,
    ));
    const publicVisit = await main.invoke("getPublicProfile", {
      username: secondUsername,
    });
    results.push(ok("visit other profile succeeds", !!publicVisit.profile?.uid));

    const basePrivacy = {
      followApprovalPolicy: String(mainUser.get("followApprovalPolicy") || "approvalRequired"),
      mentionAudience: "everyone",
      tagAudience: "followers",
      showActivityStatus: true,
      showSportLevels: true,
      showGoals: true,
      showLocation: true,
      showFollowerLists: true,
      followerListAudience: "everyone",
      hideLikeCounts: false,
      discoverableByUsername: true,
      personalizedSuggestions: true,
    };

    await main.invoke("updateProfilePrivacy", {
      privacy: {...basePrivacy, messageAudience: "noOne", messageRequestAudience: "everyone"},
    });

    // Existing direct conversations short-circuit request creation — clear both ways.
    const sorted = [MAIN_UID, SECOND_UID].slice().sort();
    const conversationQuery = await db.collection("conversations")
      .where("type", "==", "direct")
      .limit(50)
      .get();
    for (const doc of conversationQuery.docs) {
      const members = await doc.ref.collection("members").get();
      const ids = new Set(members.docs.map((m) => m.id));
      if (ids.has(MAIN_UID) && ids.has(SECOND_UID)) {
        const batch = db.batch();
        for (const member of members.docs) batch.delete(member.ref);
        batch.delete(doc.ref);
        await batch.commit();
        console.log(`cleared direct conversation ${doc.id}`);
      }
    }
    // Also clear hashed direct id variant if present via callable helper path.
    await db.doc(`message_requests/${SECOND_UID}--${MAIN_UID}`).delete().catch(() => {});
    await db.doc(`message_requests/${MAIN_UID}--${SECOND_UID}`).delete().catch(() => {});

    let deniedDirect = false;
    try {
      await second.invoke("createDirectConversation", {targetUserId: MAIN_UID});
    } catch (error) {
      deniedDirect = String(error.code || error.message || error).includes("permission-denied") ||
        String(error.message || "").toLowerCase().includes("not accepting");
    }
    results.push(ok("messageAudience=noOne blocks direct conversation", deniedDirect));

    const requestCreate = await second.invoke("createMessageRequest", {
      targetUserId: MAIN_UID,
    });
    results.push(ok(
      "createMessageRequest creates pending",
      requestCreate.status === "pending" || requestCreate.existingRequest === true,
      JSON.stringify(requestCreate),
    ));
    const dup = await second.invoke("createMessageRequest", {targetUserId: MAIN_UID});
    results.push(ok(
      "duplicate message request prevented",
      dup.existingRequest === true || dup.created === false,
      JSON.stringify(dup),
    ));

    const inbox = await db.collection(`users/${MAIN_UID}/notifications`)
      .where("kind", "==", "message_request")
      .limit(20)
      .get();
    const pendingNotif = inbox.docs.find((d) =>
      d.get("entityId") === SECOND_UID &&
      !(d.get("deletedAt")) &&
      String(d.get("data")?.status || "pending") === "pending",
    );
    results.push(ok("message request Activity notification present", !!pendingNotif));
    results.push(ok(
      "message request category is activity",
      pendingNotif ? pendingNotif.get("category") === "activity" : false,
    ));

    const decline = await main.invoke("respondToMessageRequest", {
      requesterId: SECOND_UID,
      decision: "decline",
    });
    results.push(ok("decline message request", decline.decision === "decline"));

    await second.invoke("createMessageRequest", {targetUserId: MAIN_UID});
    const accept = await main.invoke("respondToMessageRequest", {
      requesterId: SECOND_UID,
      decision: "accept",
    });
    results.push(ok(
      "accept opens conversation",
      typeof accept.conversationId === "string" && accept.conversationId.length > 0,
      `conversationId=${accept.conversationId}`,
    ));
    const acceptedNotif = await db.collection(`users/${SECOND_UID}/notifications`)
      .where("kind", "==", "message_request_accepted")
      .limit(5)
      .get();
    results.push(ok("accept notifies requester", acceptedNotif.size >= 1));

    await main.invoke("blockUser", {targetUserId: SECOND_UID});
    const blockedRel = await main.invoke("getProfileRelationship", {
      profileId: SECOND_UID,
    });
    const blockedState = blockedRel.state || blockedRel.relationship?.state;
    results.push(ok("block updates relationship", blockedState === "blocked", `state=${blockedState}`));
    results.push(ok(
      "block purges message requests",
      !(await db.doc(`message_requests/${SECOND_UID}--${MAIN_UID}`).get()).exists,
    ));
    let blockedCannotRequest = false;
    try {
      await second.invoke("createMessageRequest", {targetUserId: MAIN_UID});
    } catch {
      blockedCannotRequest = true;
    }
    results.push(ok("blocked user cannot send message request", blockedCannotRequest));
    await main.invoke("unblockUser", {profileId: SECOND_UID});
    const unblockedRel = await main.invoke("getProfileRelationship", {
      profileId: SECOND_UID,
    });
    const unblockedState = unblockedRel.state || unblockedRel.relationship?.state;
    results.push(ok(
      "unblock refreshes relationship",
      unblockedState !== "blocked",
      `state=${unblockedState}`,
    ));

    // Everyone / Followers only / Only me (owner)
    for (const audience of ["everyone", "followers", "owner"]) {
      await main.invoke("updateProfilePrivacy", {
        privacy: {
          ...basePrivacy,
          messageAudience: "noOne",
          messageRequestAudience: "everyone",
          showFollowerLists: audience !== "owner",
          followerListAudience: audience,
        },
      });
      const settings = await db.doc(`users/${MAIN_UID}/private/profile_settings`).get();
      results.push(ok(
        `followerListAudience=${audience}`,
        String(settings.get("followerListAudience")) === audience,
        `stored=${settings.get("followerListAudience")}`,
      ));
    }

    await main.invoke("updateProfilePrivacy", {
      privacy: {
        ...basePrivacy,
        messageAudience: "everyone",
        messageRequestAudience: "noOne",
      },
    });
    const direct = await second.invoke("createDirectConversation", {
      targetUserId: MAIN_UID,
    });
    results.push(ok(
      "messageAudience=everyone allows direct message",
      typeof direct.conversationId === "string",
      JSON.stringify(direct).slice(0, 120),
    ));

    try {
      await second.invoke("unfollowProfile", {profileId: MAIN_UID});
      results.push(ok("unfollowProfile callable succeeds", true));
    } catch (error) {
      results.push(ok(
        "unfollowProfile callable succeeds or already not following",
        String(error.code || "").includes("failed-precondition") ||
          String(error.message || "").toLowerCase().includes("not following"),
        String(error.message || error),
      ));
    }

    const mainAfter = await db.doc(`users/${MAIN_UID}`).get();
    results.push(ok(
      "counters non-negative",
      Number(mainAfter.get("followersCount") || 0) >= 0 &&
        Number(mainAfter.get("followingCount") || 0) >= 0,
    ));
  } catch (error) {
    console.error("QA aborted:", error);
    results.push(false);
  } finally {
    await main.close().catch(() => {});
    await second.close().catch(() => {});
  }

  const passed = results.filter(Boolean).length;
  const total = results.length;
  console.log(`\nPhase B staging callable QA: ${passed}/${total} passed`);
  if (passed !== total) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
