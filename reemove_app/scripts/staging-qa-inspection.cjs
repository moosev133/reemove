#!/usr/bin/env node
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const PROJECT_ID = "reemove-staging";
const MAIN_USERNAME = "mustafaabualhija";

function init() {
  if (getApps().length === 0) initializeApp({projectId: PROJECT_ID});
  return getFirestore();
}

async function findUserByUsername(db, usernameNormalized) {
  const snap = await db.collection("usernames").doc(usernameNormalized).get();
  if (!snap.exists) return null;
  const uid = String(snap.get("uid") ?? "");
  if (!uid) return null;
  const user = await db.collection("users").doc(uid).get();
  return user.exists ? user : null;
}

async function listFollowing(db, uid, limit = 20) {
  const snap = await db.collection(`users/${uid}/following`).limit(limit).get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
}

async function listFollowers(db, uid, limit = 20) {
  const snap = await db.collection(`users/${uid}/followers`).limit(limit).get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
}

async function feedEntriesFor(db, recipientId, authorId) {
  const snap = await db.collection("feed_entries")
    .where("recipientId", "==", recipientId)
    .where("authorId", "==", authorId)
    .limit(10)
    .get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
}

async function pendingRequestsFor(db, targetId) {
  const snap = await db.collection("follow_requests")
    .where("targetId", "==", targetId)
    .where("status", "==", "pending")
    .limit(20)
    .get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
}

async function blocksBetween(db, a, b) {
  const [ab, ba] = await Promise.all([
    db.doc(`users/${a}/blocks/${b}`).get(),
    db.doc(`users/${b}/blocks/${a}`).get(),
  ]);
  return {aBlocksB: ab.exists, bBlocksA: ba.exists};
}

async function conversationsFor(db, uid) {
  const snap = await db.collection("conversations")
    .where("memberIds", "array-contains", uid)
    .limit(10)
    .get();
  return snap.docs.map((d) => ({
    id: d.id,
    memberIds: d.get("memberIds"),
    type: d.get("type"),
    updatedAt: d.get("updatedAt")?.toDate?.()?.toISOString?.() ?? null,
  }));
}

async function privacySettings(db, uid) {
  const snap = await db.doc(`users/${uid}/private/profile_settings`).get();
  return snap.exists ? snap.data() : null;
}

async function postsByAuthor(db, authorId, limit = 5) {
  const snap = await db.collection("posts")
    .where("authorId", "==", authorId)
    .limit(limit)
    .get();
  return snap.docs.map((d) => ({
    id: d.id,
    visibility: d.get("visibility"),
    authorAccountVisibility: d.get("authorAccountVisibility") ?? null,
    status: d.get("status"),
  }));
}

async function main() {
  const db = init();
  const mainUser = await findUserByUsername(db, MAIN_USERNAME);
  if (!mainUser) {
    console.log(JSON.stringify({error: "main user not found"}, null, 2));
    return;
  }
  const mainId = mainUser.id;
  const followers = await listFollowers(db, mainId);
  const following = await listFollowing(db, mainId);
  const requests = await pendingRequestsFor(db, mainId);
  const privacy = await privacySettings(db, mainId);
  const posts = await postsByAuthor(db, mainId);
  const conversations = await conversationsFor(db, mainId);

  const followerProfiles = [];
  for (const f of followers.slice(0, 5)) {
    const u = await db.collection("users").doc(f.id).get();
    followerProfiles.push({
      uid: f.id,
      username: u.get("username"),
      feedEntriesToFollower: await feedEntriesFor(db, f.id, mainId),
    });
  }

  const blocks = {};
  for (const f of followers.slice(0, 3)) {
    blocks[f.id] = await blocksBetween(db, mainId, f.id);
  }

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    main: {
      uid: mainId,
      username: mainUser.get("username"),
      visibility: mainUser.get("visibility"),
      accountPrivacy: mainUser.get("accountPrivacy"),
      followersCount: mainUser.get("followersCount"),
      followingCount: mainUser.get("followingCount"),
      privacy,
      posts,
    },
    followers,
    following,
    pendingRequests: requests,
    followerProfiles,
    blocks,
    conversations,
  }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
