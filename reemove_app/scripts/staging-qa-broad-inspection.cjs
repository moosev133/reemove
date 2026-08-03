#!/usr/bin/env node
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";

function init() {
  if (getApps().length === 0) initializeApp({projectId: PROJECT_ID});
  return getFirestore();
}

async function main() {
  const db = init();
  const users = await db.collection("users").limit(30).get();
  const profiles = [];
  for (const doc of users.docs) {
    const uid = doc.id;
    const [followers, following, blocksOut] = await Promise.all([
      db.collection(`users/${uid}/followers`).limit(5).get(),
      db.collection(`users/${uid}/following`).limit(5).get(),
      db.collection(`users/${uid}/blocks`).limit(5).get(),
    ]);
    profiles.push({
      uid,
      username: doc.get("username"),
      visibility: doc.get("visibility"),
      accountPrivacy: doc.get("accountPrivacy"),
      followersCount: doc.get("followersCount"),
      followingCount: doc.get("followingCount"),
      followerIds: followers.docs.map((d) => d.id),
      followingIds: following.docs.map((d) => d.id),
      blockedIds: blocksOut.docs.map((d) => d.id),
      isMain: uid === MAIN_UID,
    });
  }

  const requests = await db.collection("follow_requests").limit(20).get();
  const conversations = await db.collection("conversations").limit(20).get();
  const feedEntries = await db.collection("feed_entries")
    .where("authorId", "==", MAIN_UID)
    .limit(20)
    .get();
  const audit = await db.collection("audit_logs")
    .orderBy("createdAt", "desc")
    .limit(30)
    .get()
    .catch(() => null);

  console.log(JSON.stringify({
    users: profiles,
    followRequests: requests.docs.map((d) => ({id: d.id, ...d.data()})),
    conversations: conversations.docs.map((d) => ({
      id: d.id,
      memberIds: d.get("memberIds"),
      type: d.get("type"),
    })),
    feedEntriesForMainAuthor: feedEntries.docs.map((d) => ({
      id: d.id,
      recipientId: d.get("recipientId"),
    })),
    recentAudit: audit ? audit.docs.map((d) => ({
      action: d.get("action"),
      actorId: d.get("actorId"),
      targetId: d.get("targetId"),
      metadata: d.get("metadata"),
    })) : "audit_logs not readable",
  }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
