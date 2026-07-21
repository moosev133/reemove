const assert = require("node:assert/strict");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeApp: initializeClientApp} = require("firebase/app");
const {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth: getClientAuth,
  signInWithEmailAndPassword,
} = require("firebase/auth");
const {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} = require("firebase/functions");

const PROJECT_ID = process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "demo-reemove";
const HOST = process.env.FIREBASE_EMULATOR_HOST || "127.0.0.1";
const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || "europe-west1";
const PASSWORD = "PrivacyTest123!";

function assertEmulatorEnv() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "FIRESTORE_EMULATOR_HOST is required. Run via firebase emulators:exec.",
    );
  }
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error(
      "FIREBASE_AUTH_EMULATOR_HOST is required. Run via firebase emulators:exec.",
    );
  }
  if (/prod|production/i.test(PROJECT_ID)) {
    throw new Error(`Refusing to run integration tests on ${PROJECT_ID}.`);
  }
}

function initAdmin() {
  assertEmulatorEnv();
  if (getApps().length === 0) {
    initializeApp({projectId: PROJECT_ID});
  }
  return {
    auth: getAuth(),
    db: getFirestore(),
  };
}

function baseProfile(uid, overrides = {}) {
  const username = overrides.username || uid.replaceAll("_", ".");
  const usernameNormalized = overrides.usernameNormalized ||
    username.toLowerCase();
  return {
    uid,
    username,
    usernameNormalized,
    displayName: overrides.displayName || uid,
    bio: overrides.bio || "Privacy integration profile.",
    role: "athlete",
    isVerified: false,
    verificationType: "none",
    visibility: "public",
    accountPrivacy: "public",
    followApprovalPolicy: "automatic",
    followersCount: 0,
    followingCount: 0,
    postsCount: 0,
    reelsCount: 0,
    onboardingCompleted: true,
    moderationState: "active",
    favoriteSportIds: ["football"],
    goals: [],
    schemaVersion: 1,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    ...overrides,
  };
}

async function ensureAuthUser(auth, {uid, email, claims}) {
  try {
    await auth.getUser(uid);
    await auth.updateUser(uid, {email, password: PASSWORD, disabled: false});
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({uid, email, password: PASSWORD, emailVerified: true});
  }
  if (claims) {
    await auth.setCustomUserClaims(uid, claims);
  }
}

async function seedProfile(db, profile) {
  await db.collection("users").doc(profile.uid).set(profile, {merge: true});
  await db.collection("usernames").doc(profile.usernameNormalized).set({
    uid: profile.uid,
    username: profile.username,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    schemaVersion: 1,
  }, {merge: true});
  await db.doc(`users/${profile.uid}/private/profile`).set({
    uid: profile.uid,
    updatedAt: Timestamp.now(),
    schemaVersion: 1,
  }, {merge: true});
  await db.doc(`users/${profile.uid}/private/profile_settings`).set({
    uid: profile.uid,
    followApprovalPolicy: profile.followApprovalPolicy ?? "automatic",
    messageAudience: "everyone",
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
    updatedAt: Timestamp.now(),
    schemaVersion: 1,
  }, {merge: true});
}

async function createFollowEdge(db, followerId, targetId) {
  throw new Error(
    "createFollowEdge bypasses production counters. Use establishFollowing instead.",
  );
}

async function readRelationshipCounters(db, uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  return {
    followersCount: Number(snapshot.get("followersCount") ?? 0),
    followingCount: Number(snapshot.get("followingCount") ?? 0),
  };
}

async function assertRelationshipGraph(
  db,
  followerId,
  targetId,
  {
    connected,
    followerFollowingCount,
    targetFollowersCount,
  },
) {
  const followingEdge = await db.doc(
    `users/${followerId}/following/${targetId}`,
  ).get();
  const followerEdge = await db.doc(
    `users/${targetId}/followers/${followerId}`,
  ).get();
  assert.equal(followingEdge.exists, connected);
  assert.equal(followerEdge.exists, connected);
  if (followerFollowingCount !== undefined) {
    const followerCounters = await readRelationshipCounters(db, followerId);
    assert.equal(followerCounters.followingCount, followerFollowingCount);
  }
  if (targetFollowersCount !== undefined) {
    const targetCounters = await readRelationshipCounters(db, targetId);
    assert.equal(targetCounters.followersCount, targetFollowersCount);
  }
}

async function assertNonNegativeCounters(db, ...uids) {
  for (const uid of uids) {
    const counters = await readRelationshipCounters(db, uid);
    assert.ok(counters.followersCount >= 0);
    assert.ok(counters.followingCount >= 0);
  }
}

async function assertCleanRelationshipState(db, viewerId, targetId) {
  const requestDoc = await db.collection("follow_requests")
    .doc(`${viewerId}--${targetId}`)
    .get();
  const edge = await db.doc(`users/${viewerId}/following/${targetId}`).get();
  const reverseEdge = await db.doc(`users/${targetId}/followers/${viewerId}`).get();
  assert.equal(edge.exists, reverseEdge.exists);
  assert.notEqual(edge.exists && requestDoc.exists, true);
  if (edge.exists) {
    assert.equal(requestDoc.exists, false);
  }
  await assertNonNegativeCounters(db, viewerId, targetId);
}

async function establishFollowing(follower, target) {
  const followProfile = callableFor(follower.client.functions, "followProfile");
  const response = await followProfile({profileId: target.uid});
  if (response.data.state === "requestSent") {
    await callableFor(target.client.functions, "respondToFollowRequest")({
      profileId: follower.uid,
      response: "accept",
    });
  }
  return response;
}

async function createBlock(db, blockerId, blockedId) {
  const now = Timestamp.now();
  const record = {
    blockerId,
    blockedId,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  };
  await db.doc(`users/${blockerId}/blocks/${blockedId}`).set(record);
  await db.doc(`users/${blockedId}/blocked_by/${blockerId}`).set(record);
}

let clientAppCounter = 0;

function createClientApp() {
  const appName = `privacy-integration-${++clientAppCounter}`;
  return initializeClientApp({
    apiKey: "test",
    appId: appName,
    projectId: PROJECT_ID,
  }, appName);
}

async function signInClient(email) {
  const app = createClientApp();
  const auth = getClientAuth(app);
  connectAuthEmulator(auth, `http://${HOST}:9099`, {disableWarnings: true});
  try {
    await signInWithEmailAndPassword(auth, email, PASSWORD);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await createUserWithEmailAndPassword(auth, email, PASSWORD);
  }
  const functions = getFunctions(app, FUNCTIONS_REGION);
  connectFunctionsEmulator(functions, HOST, 5001);
  return {app, auth, functions};
}

async function signedOutCallable(client, name, data = {}) {
  const {signOut} = require("firebase/auth");
  await signOut(client.auth);
  return httpsCallable(client.functions, name, {timeout: 30000})(data);
}

function callableFor(functions, name) {
  return httpsCallable(functions, name, {timeout: 30000});
}

async function clearPrivacyTestData(db) {
  const prefixes = ["pp-", "privacy-"];
  const users = await db.collection("users").listDocuments();
  for (const ref of users) {
    if (prefixes.some((prefix) => ref.id.startsWith(prefix))) {
      await ref.delete();
    }
  }
  const usernames = await db.collection("usernames").listDocuments();
  for (const ref of usernames) {
    if (prefixes.some((prefix) => ref.id.startsWith(prefix))) {
      await ref.delete();
    }
  }
  const requests = await db.collection("follow_requests").listDocuments();
  for (const ref of requests) {
    if (ref.id.includes("pp-")) {
      await ref.delete();
    }
  }
}

function defaultPrivacy(overrides = {}) {
  return {
    followApprovalPolicy: "automatic",
    messageAudience: "everyone",
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
    ...overrides,
  };
}

function updateProfilePayload(profile, visibility, privacyOverrides = {}) {
  return {
    displayName: profile.displayName,
    username: profile.username,
    bio: profile.bio,
    favoriteSportIds: profile.favoriteSportIds,
    goals: profile.goals,
    visibility,
    privacy: defaultPrivacy({
      followApprovalPolicy: visibility === "public" ?
        "automatic" : "approvalRequired",
      ...privacyOverrides,
    }),
    professionalDetails: {
      acceptingClients: false,
      specialties: [],
    },
  };
}

async function seedStory(db, story) {
  const now = Timestamp.now();
  await db.collection("stories").doc(story.id).set({
    authorId: story.authorId,
    authorSnapshot: story.authorSnapshot ?? {
      id: story.authorId,
      username: story.username ?? story.authorId,
      displayName: story.displayName ?? story.authorId,
      isVerified: false,
      verificationType: "none",
    },
    visibility: story.visibility ?? "public",
    moderationState: "active",
    caption: story.caption ?? "Integration test story",
    sportId: null,
    createdAt: now,
    expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000),
    viewCount: 0,
    schemaVersion: 1,
    media: {},
  }, {merge: false});
}

async function seedPost(db, post) {
  const now = Timestamp.now();
  await db.collection("posts").doc(post.id).set({
    authorId: post.authorId,
    authorSnapshot: post.authorSnapshot ?? {
      id: post.authorId,
      username: post.username ?? post.authorId,
      displayName: post.displayName ?? post.authorId,
      isVerified: false,
      verificationType: "none",
    },
    kind: post.kind ?? "post",
    caption: post.caption ?? "Integration test post",
    visibility: post.visibility ?? "public",
    moderationState: "active",
    status: "published",
    allowComments: true,
    likeCount: 0,
    commentCount: 0,
    saveCount: 0,
    repostCount: 0,
    viewCount: 0,
    rankingScore: 0,
    publishedAt: now,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
    media: [],
    hashtags: [],
    mentions: [],
  }, {merge: false});
}

async function callUnauthenticated(name, data = {}) {
  const app = createClientApp();
  const functions = getFunctions(app, FUNCTIONS_REGION);
  connectFunctionsEmulator(functions, HOST, 5001);
  return httpsCallable(functions, name, {timeout: 30000})(data);
}

async function expectCallableError(promise, codeFragment) {
  try {
    await promise;
    throw new Error("Expected callable to fail");
  } catch (error) {
    const code = String(error.code ?? "");
    if (!code.includes(codeFragment)) {
      throw new Error(
        `Expected error containing ${codeFragment}, got ${code}: ${error.message}`,
      );
    }
  }
}

module.exports = {
  PASSWORD,
  PROJECT_ID,
  assertEmulatorEnv,
  initAdmin,
  baseProfile,
  ensureAuthUser,
  seedProfile,
  createFollowEdge,
  establishFollowing,
  readRelationshipCounters,
  assertRelationshipGraph,
  assertNonNegativeCounters,
  assertCleanRelationshipState,
  createBlock,
  seedStory,
  seedPost,
  signedOutCallable,
  signInClient,
  callableFor,
  callUnauthenticated,
  expectCallableError,
  defaultPrivacy,
  updateProfilePayload,
  clearPrivacyTestData,
};
