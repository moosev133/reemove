import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {after, before, beforeEach, describe, it} from "node:test";
import {fileURLToPath} from "node:url";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

import {activeListing, activePlace, newClientUser, publicUser} from "./fixtures.mjs";

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(dirname, "../..");
const projectId = "demo-reemove";
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8180,
      rules: fs.readFileSync(path.join(projectRoot, "firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

async function seedFirestore() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, "users/public-user"), publicUser("public-user")),
      setDoc(doc(db, "users/private-user"), publicUser("private-user", "private")),
      setDoc(doc(db, "users/incomplete-user"), {
        ...publicUser("incomplete-user"),
        onboardingCompleted: false,
      }),
      setDoc(doc(db, "users/public-user/private/onboarding"), {
        uid: "public-user",
        version: 1,
        currentStep: "sports",
        favoriteSportIds: ["football"],
        status: "in_progress",
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"),
        schemaVersion: 1,
      }),
      setDoc(doc(db, "usernames/alice"), {uid: "alice"}),
      setDoc(doc(db, "sports/football"), {
        slug: "football",
        localizedNames: {en: "Football"},
        iconKey: "football",
        isEnabled: true,
        sortOrder: 10,
        supportedFeatures: ["events"],
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"),
        schemaVersion: 1,
      }),
      setDoc(doc(db, "feature_flags/ai_coach"), {
        enabled: false,
        rolloutPercentage: 0,
        allowedPlatforms: ["android", "ios"],
        minimumBuild: 1,
        description: "AI coach rollout",
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"),
        schemaVersion: 1,
      }),
      setDoc(doc(db, "places/active-gym"), activePlace("active-gym")),
      setDoc(doc(db, "places/private-gym"), activePlace("private-gym", "private")),
      setDoc(doc(db, "marketplace_listings/bench"), activeListing("bench")),
      setDoc(doc(db, "posts/public-post"), {
        authorId: "public-user",
        authorSnapshot: {id: "public-user", username: "public_user", displayName: "Public User", isVerified: false, verificationType: "none"},
        kind: "post",
        caption: "Morning run",
        media: [],
        hashtags: ["running"],
        mentions: [],
        visibility: "public",
        moderationState: "active",
        status: "published",
        allowComments: true,
        likeCount: 2,
        commentCount: 1,
        saveCount: 0,
        repostCount: 0,
        viewCount: 5,
        rankingScore: 10,
        publishedAt: new Date("2026-07-13T12:00:00Z"),
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"),
        schemaVersion: 1,
      }),
      setDoc(doc(db, "posts/private-post"), {
        authorId: "private-user",
        authorSnapshot: {id: "private-user", username: "private_user", displayName: "Private User", isVerified: false, verificationType: "none"},
        kind: "post", caption: "Private", media: [], hashtags: [], mentions: [],
        visibility: "private", moderationState: "active", status: "published", allowComments: true,
        likeCount: 0, commentCount: 0, saveCount: 0, repostCount: 0, viewCount: 0, rankingScore: 0,
        publishedAt: new Date("2026-07-13T11:00:00Z"), createdAt: new Date("2026-07-13T11:00:00Z"), updatedAt: new Date("2026-07-13T11:00:00Z"), schemaVersion: 1,
      }),
      setDoc(doc(db, "posts/processing-post"), {
        authorId: "public-user",
        authorSnapshot: {id: "public-user", username: "public_user", displayName: "Public User", isVerified: false, verificationType: "none"},
        kind: "reel", caption: "Processing", media: [], hashtags: [], mentions: [],
        visibility: "public", moderationState: "active", status: "processing", allowComments: true,
        likeCount: 0, commentCount: 0, saveCount: 0, repostCount: 0, viewCount: 0, rankingScore: 0,
        publishedAt: new Date("2026-07-13T12:00:00Z"), createdAt: new Date("2026-07-13T12:00:00Z"), updatedAt: new Date("2026-07-13T12:00:00Z"), schemaVersion: 1,
      }),
      setDoc(doc(db, "posts/public-post/comments/comment-1"), {
        postId: "public-post", authorId: "public-user",
        authorSnapshot: {id: "public-user", username: "public_user", displayName: "Public User", isVerified: false, verificationType: "none"},
        text: "Nice run", parentCommentId: null, likeCount: 0, replyCount: 0,
        moderationState: "active", createdAt: new Date("2026-07-13T12:01:00Z"), updatedAt: new Date("2026-07-13T12:01:00Z"), schemaVersion: 1,
      }),
      setDoc(doc(db, "stories/story-1"), {
        authorId: "public-user",
        authorSnapshot: {id: "public-user", username: "public_user", displayName: "Public User", isVerified: false, verificationType: "none"},
        media: {id: "asset-1", storagePath: "content/public-user/draft/asset-1/photo.jpg", kind: "image", processingState: "ready", downloadUrl: "https://example.com/photo.jpg"},
        caption: "Training", visibility: "public", moderationState: "active", viewCount: 0,
        createdAt: new Date("2026-07-13T12:00:00Z"), updatedAt: new Date("2026-07-13T12:00:00Z"),
        expiresAt: new Date("2099-07-14T12:00:00Z"), schemaVersion: 1,
      }),
      setDoc(doc(db, "content_reactions/reader--public-post"), {
        uid: "reader", postId: "public-post", liked: true, saved: false, reposted: false,
        updatedAt: new Date("2026-07-13T12:00:00Z"), schemaVersion: 1,
      }),
      setDoc(doc(db, "story_views/reader--story-1"), {
        uid: "reader", storyId: "story-1", viewedAt: new Date("2026-07-13T12:00:00Z"), schemaVersion: 1,
      }),
    ]);
  });
}

describe("user profile rules", () => {
  it("requires authentication to read public profiles", async () => {
    await seedFirestore();
    const unauthenticated = testEnv.unauthenticatedContext().firestore();
    const authenticated = testEnv.authenticatedContext("reader").firestore();

    await assertFails(getDoc(doc(unauthenticated, "users/public-user")));
    await assertSucceeds(getDoc(doc(authenticated, "users/public-user")));
  });

  it("allows only the owner to read a private profile", async () => {
    await seedFirestore();
    const other = testEnv.authenticatedContext("other-user").firestore();
    const owner = testEnv.authenticatedContext("private-user").firestore();

    await assertFails(getDoc(doc(other, "users/private-user")));
    await assertSucceeds(getDoc(doc(owner, "users/private-user")));
  });

  it("keeps profile creation server-owned even after username reservation", async () => {
    await seedFirestore();
    const alice = testEnv.authenticatedContext("alice").firestore();

    await assertFails(setDoc(doc(alice, "users/alice"), newClientUser("alice")));
  });

  it("keeps username reservations and private account metadata server-owned", async () => {
    await seedFirestore();
    const alice = testEnv.authenticatedContext("alice").firestore();

    await assertSucceeds(getDoc(doc(alice, "usernames/alice")));
    await assertFails(setDoc(doc(alice, "usernames/new_name"), {uid: "alice"}));
    await assertFails(setDoc(doc(alice, "users/alice/private/profile"), {
      uid: "alice",
      accountStatus: "active",
      updatedAt: serverTimestamp(),
    }));
  });

  it("prevents owners from changing server-owned counters", async () => {
    await seedFirestore();
    const owner = testEnv.authenticatedContext("public-user").firestore();
    const profile = doc(owner, "users/public-user");

    await assertSucceeds(updateDoc(profile, {
      displayName: "Updated Name",
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(profile, {
      followersCount: 999,
      updatedAt: serverTimestamp(),
    }));
  });

  it("allows owners to resume private onboarding without exposing it", async () => {
    await seedFirestore();
    const owner = testEnv.authenticatedContext("public-user").firestore();
    const other = testEnv.authenticatedContext("other-user").firestore();
    const draftPath = "users/public-user/private/onboarding";

    await assertSucceeds(getDoc(doc(owner, draftPath)));
    await assertFails(getDoc(doc(other, draftPath)));
    await assertFails(updateDoc(doc(owner, draftPath), {
      currentStep: "goals",
      updatedAt: serverTimestamp(),
    }));
  });

  it("prevents clients from bypassing trusted onboarding completion", async () => {
    await seedFirestore();
    const owner = testEnv.authenticatedContext("incomplete-user").firestore();
    const profile = doc(owner, "users/incomplete-user");

    await assertFails(updateDoc(profile, {
      onboardingCompleted: true,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(profile, {
      favoriteSportIds: ["running"],
      sportLevels: {running: "advanced"},
      goals: ["performance"],
      updatedAt: serverTimestamp(),
    }));
  });
});

describe("catalog rules", () => {
  it("keeps sports public but server-owned", async () => {
    await seedFirestore();
    const unauthenticated = testEnv.unauthenticatedContext().firestore();
    const athlete = testEnv.authenticatedContext("athlete").firestore();

    await assertSucceeds(getDoc(doc(unauthenticated, "sports/football")));
    await assertFails(setDoc(doc(athlete, "sports/tennis"), {slug: "tennis"}));
  });

  it("requires authentication for feature flags", async () => {
    await seedFirestore();
    const unauthenticated = testEnv.unauthenticatedContext().firestore();
    const athlete = testEnv.authenticatedContext("athlete").firestore();

    await assertFails(getDoc(doc(unauthenticated, "feature_flags/ai_coach")));
    await assertSucceeds(getDoc(doc(athlete, "feature_flags/ai_coach")));
  });

  it("allows bounded queries for active public places", async () => {
    await seedFirestore();
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    const validQuery = query(
      collection(athlete, "places"),
      where("visibility", "==", "public"),
      where("moderationState", "==", "active"),
      limit(20),
    );
    const unboundedQuery = query(
      collection(athlete, "places"),
      where("visibility", "==", "public"),
      where("moderationState", "==", "active"),
      limit(51),
    );

    const snapshot = await assertSucceeds(getDocs(validQuery));
    assert.equal(snapshot.size, 1);
    await assertFails(getDocs(unboundedQuery));
  });

  it("does not expose private places or catalogs to signed-out users", async () => {
    await seedFirestore();
    const unauthenticated = testEnv.unauthenticatedContext().firestore();
    const athlete = testEnv.authenticatedContext("athlete").firestore();

    await assertFails(getDoc(doc(unauthenticated, "places/active-gym")));
    await assertFails(getDoc(doc(athlete, "places/private-gym")));
    await assertSucceeds(getDoc(doc(athlete, "marketplace_listings/bench")));
  });
});

describe("social content rules", () => {
  it("allows public content and keeps private or processing posts scoped", async () => {
    await seedFirestore();
    const reader = testEnv.authenticatedContext("reader").firestore();
    const owner = testEnv.authenticatedContext("public-user").firestore();

    await assertSucceeds(getDoc(doc(reader, "posts/public-post")));
    await assertFails(getDoc(doc(reader, "posts/private-post")));
    await assertFails(getDoc(doc(reader, "posts/processing-post")));
    await assertSucceeds(getDoc(doc(owner, "posts/processing-post")));
  });

  it("allows readable comments and stories but keeps all client writes server-owned", async () => {
    await seedFirestore();
    const reader = testEnv.authenticatedContext("reader").firestore();

    await assertSucceeds(getDoc(doc(reader, "posts/public-post/comments/comment-1")));
    await assertSucceeds(getDoc(doc(reader, "stories/story-1")));
    await assertFails(updateDoc(doc(reader, "posts/public-post"), {likeCount: 999}));
    await assertFails(setDoc(doc(reader, "posts/public-post/comments/new"), {text: "direct"}));
    await assertFails(setDoc(doc(reader, "stories/new-story"), {authorId: "reader"}));
  });

  it("exposes only the signed-in viewer's reaction and view records", async () => {
    await seedFirestore();
    const reader = testEnv.authenticatedContext("reader").firestore();
    const other = testEnv.authenticatedContext("other").firestore();

    await assertSucceeds(getDoc(doc(reader, "content_reactions/reader--public-post")));
    await assertSucceeds(getDoc(doc(reader, "content_reactions/reader--missing")));
    await assertSucceeds(getDoc(doc(reader, "comment_reactions/reader--missing")));
    await assertFails(getDoc(doc(other, "content_reactions/reader--public-post")));
    await assertSucceeds(getDoc(doc(reader, "story_views/reader--story-1")));
    await assertSucceeds(getDoc(doc(reader, "story_views/reader--missing")));
    await assertFails(getDoc(doc(other, "story_views/reader--story-1")));
    await assertFails(setDoc(doc(reader, "content_reactions/reader--other"), {uid: "reader"}));
  });

  it("enforces direct block access and protects reciprocal block indexes", async () => {
    await seedFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      await setDoc(doc(admin, "users/reader/blocks/public-user"), {
        blockerId: "reader", blockedId: "public-user",
      });
      await setDoc(doc(admin, "users/public-user/blocked_by/reader"), {
        blockerId: "reader", blockedId: "public-user",
      });
    });
    const reader = testEnv.authenticatedContext("reader").firestore();
    const publicUserDb = testEnv.authenticatedContext("public-user").firestore();
    const other = testEnv.authenticatedContext("other").firestore();

    await assertFails(getDoc(doc(reader, "posts/public-post")));
    await assertFails(getDoc(doc(reader, "stories/story-1")));
    await assertSucceeds(
      getDoc(doc(publicUserDb, "users/public-user/blocked_by/reader")),
    );
    await assertFails(
      getDoc(doc(other, "users/public-user/blocked_by/reader")),
    );

    const boundedPublicFeed = query(
      collection(reader, "posts"),
      where("status", "==", "published"),
      where("visibility", "==", "public"),
      where("moderationState", "==", "active"),
      limit(25),
    );
    await assertSucceeds(getDocs(boundedPublicFeed));
  });
});

describe("reports and deny-by-default", () => {
  it("accepts a valid report from its authenticated reporter", async () => {
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    await assertSucceeds(setDoc(doc(athlete, "reports/report-1"), {
      reporterId: "athlete",
      targetType: "user",
      targetId: "bad-user",
      reason: "harassment",
      details: "Repeated unwanted messages.",
      status: "open",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      schemaVersion: 1,
    }));
  });

  it("rejects impersonated reporters and unknown collections", async () => {
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    await assertFails(setDoc(doc(athlete, "reports/report-2"), {
      reporterId: "another-user",
      targetType: "user",
      targetId: "bad-user",
      reason: "spam",
      status: "open",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      schemaVersion: 1,
    }));
    await assertFails(
      getDoc(doc(athlete, "rate_limits/athlete_revoke_sessions")),
    );
    await assertFails(
      setDoc(doc(athlete, "rate_limits/athlete_revoke_sessions"), {
        uid: "athlete",
        count: 1,
      }),
    );
    await assertFails(getDoc(doc(athlete, "audit_logs/audit-1")));
    await assertFails(
      getDoc(doc(athlete, "account_deletions/athlete")),
    );
    await assertFails(setDoc(doc(athlete, "unknown/document"), {value: true}));
  });
});
