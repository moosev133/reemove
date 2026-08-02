#!/usr/bin/env node
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";

function init() {
  if (getApps().length === 0) initializeApp({projectId: PROJECT_ID});
  return getFirestore();
}

async function edge(db, a, b, sub) {
  const snap = await db.doc(`users/${a}/${sub}/${b}`).get();
  return snap.exists ? snap.data() : null;
}

async function main() {
  const db = init();
  const [main, second] = await Promise.all([
    db.collection("users").doc(MAIN_UID).get(),
    db.collection("users").doc(SECOND_UID).get(),
  ]);

  const relationships = {
    secondFollowingMain: await edge(db, SECOND_UID, MAIN_UID, "following"),
    mainFollowersSecond: await edge(db, MAIN_UID, SECOND_UID, "followers"),
    mainBlocksSecond: await edge(db, MAIN_UID, SECOND_UID, "blocks"),
    secondBlocksMain: await edge(db, SECOND_UID, MAIN_UID, "blocks"),
  };

  const requestIds = [
    `${SECOND_UID}--${MAIN_UID}`,
    `${MAIN_UID}--${SECOND_UID}`,
  ];
  const requests = {};
  for (const id of requestIds) {
    const snap = await db.collection("follow_requests").doc(id).get();
    requests[id] = snap.exists ? snap.data() : null;
  }

  const allRequests = await db.collection("follow_requests")
    .where("targetId", "==", MAIN_UID)
    .limit(20)
    .get();
  const allFromSecond = await db.collection("follow_requests")
    .where("requesterId", "==", SECOND_UID)
    .limit(20)
    .get();

  const convos = await db.collection("conversations")
    .where("memberIds", "array-contains", MAIN_UID)
    .limit(20)
    .get();
  const convoDetails = [];
  for (const doc of convos.docs) {
    const members = await db.collection(`conversations/${doc.id}/members`).get();
    const messages = await db.collection(`conversations/${doc.id}/messages`)
      .orderBy("sentAt", "desc")
      .limit(5)
      .get()
      .catch(() => null);
    convoDetails.push({
      id: doc.id,
      data: doc.data(),
      members: members.docs.map((m) => m.id),
      messages: messages ? messages.docs.map((m) => ({
        id: m.id,
        senderId: m.get("senderId"),
        text: m.get("text"),
        sentAt: m.get("sentAt")?.toDate?.()?.toISOString?.() ?? null,
      })) : "messages unreadable",
    });
  }

  const feedSecondFromMain = await db.collection("feed_entries")
    .where("recipientId", "==", SECOND_UID)
    .where("authorId", "==", MAIN_UID)
    .get();

  const audit = await db.collection("audit_logs")
    .orderBy("createdAt", "desc")
    .limit(100)
    .get();

  const qaAudit = audit.docs
    .map((d) => ({
      action: d.get("action"),
      actorId: d.get("actorId"),
      targetId: d.get("targetId"),
      at: d.get("createdAt")?.toDate?.()?.toISOString?.() ?? null,
    }))
    .filter((e) =>
      [MAIN_UID, SECOND_UID].includes(e.actorId) ||
      [MAIN_UID, SECOND_UID].includes(e.targetId),
    );

  console.log(JSON.stringify({
    main: {
      uid: MAIN_UID,
      username: main.get("username"),
      visibility: main.get("visibility"),
      accountPrivacy: main.get("accountPrivacy"),
      followersCount: main.get("followersCount"),
      followingCount: main.get("followingCount"),
    },
    second: {
      uid: SECOND_UID,
      username: second.get("username"),
      visibility: second.get("visibility"),
      followersCount: second.get("followersCount"),
      followingCount: second.get("followingCount"),
    },
    relationships,
    requests,
    allRequestsForMain: allRequests.docs.map((d) => ({id: d.id, ...d.data()})),
    allRequestsFromSecond: allFromSecond.docs.map((d) => ({id: d.id, ...d.data()})),
    feedEntriesSecondFromMain: feedSecondFromMain.docs.map((d) => d.id),
    conversations: convoDetails,
    qaAudit,
  }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
