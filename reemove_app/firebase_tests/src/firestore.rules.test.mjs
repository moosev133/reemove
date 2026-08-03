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
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
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
      setDoc(doc(db, "users/private-user"), publicUser("private-user", "followers")),
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
        authorAccountVisibility: "public",
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
        caption: "Training", visibility: "public", authorAccountVisibility: "public", moderationState: "active", viewCount: 0,
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
      setDoc(doc(db, "users/private-user/followers/approved-reader"), {
        userId: "approved-reader",
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"),
        schemaVersion: 1,
      }),
      setDoc(doc(db, "follow_requests/reader--private-user"), {
        requesterId: "reader", targetId: "private-user", status: "pending",
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"), schemaVersion: 1,
      }),
      setDoc(doc(db, "verification_requests/public-user"), {
        uid: "public-user", requestedType: "athlete", status: "pending",
        legalName: "Public User", summary: "Competitive athlete identity review.",
        evidence: [{storagePath: "verification/public-user/public-user/evidence.png", label: "Athlete ID"}],
        submittedAt: new Date("2026-07-13T12:00:00Z"),
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"), schemaVersion: 1,
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

  it("allows only the owner or an approved follower to read a followers-only profile", async () => {
    await seedFirestore();
    const other = testEnv.authenticatedContext("other-user").firestore();
    const follower = testEnv.authenticatedContext("approved-reader").firestore();
    const owner = testEnv.authenticatedContext("private-user").firestore();

    await assertFails(getDoc(doc(other, "users/private-user")));
    await assertSucceeds(getDoc(doc(follower, "users/private-user")));
    await assertSucceeds(getDoc(doc(owner, "users/private-user")));
  });

  it("denies approved followers when the account is owner-only", async () => {
    await seedFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users/owner-only-user"), {
        ...publicUser("owner-only-user", "private"),
        accountPrivacy: "ownerOnly",
      });
      await setDoc(doc(db, "users/owner-only-user/followers/approved-reader"), {
        userId: "approved-reader",
        createdAt: new Date("2026-07-13T12:00:00Z"),
        updatedAt: new Date("2026-07-13T12:00:00Z"),
        schemaVersion: 1,
      });
    });
    const follower = testEnv.authenticatedContext("approved-reader").firestore();
    const owner = testEnv.authenticatedContext("owner-only-user").firestore();

    await assertFails(getDoc(doc(follower, "users/owner-only-user")));
    await assertSucceeds(getDoc(doc(owner, "users/owner-only-user")));
  });

  it("lets a first-time user observe their own missing profile document", async () => {
    await seedFirestore();
    const newcomer = testEnv.authenticatedContext("brand-new-user").firestore();
    const other = testEnv.authenticatedContext("other-user").firestore();

    await assertSucceeds(getDoc(doc(newcomer, "users/brand-new-user")));
    await assertFails(getDoc(doc(other, "users/brand-new-user")));
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

  it("keeps profile edits and counters behind trusted server mutations", async () => {
    await seedFirestore();
    const owner = testEnv.authenticatedContext("public-user").firestore();
    const profile = doc(owner, "users/public-user");

    await assertFails(updateDoc(profile, {
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

describe("profile relationship and verification rules", () => {
  it("keeps follow edges and requests server-owned", async () => {
    await seedFirestore();
    const reader = testEnv.authenticatedContext("reader").firestore();

    await assertFails(setDoc(doc(reader, "users/reader/following/public-user"), {
      userId: "public-user", createdAt: serverTimestamp(), updatedAt: serverTimestamp(), schemaVersion: 1,
    }));
    await assertFails(setDoc(doc(reader, "follow_requests/reader--public-user"), {
      requesterId: "reader", targetId: "public-user", status: "pending",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(), schemaVersion: 1,
    }));
    await assertFails(getDoc(doc(reader, "follow_requests/reader--private-user")));
  });

  it("exposes verification requests only to their owner or an administrator", async () => {
    await seedFirestore();
    const owner = testEnv.authenticatedContext("public-user").firestore();
    const other = testEnv.authenticatedContext("reader").firestore();
    const admin = testEnv.authenticatedContext("admin", {admin: true}).firestore();

    await assertSucceeds(getDoc(doc(owner, "verification_requests/public-user")));
    await assertFails(getDoc(doc(other, "verification_requests/public-user")));
    await assertSucceeds(getDoc(doc(admin, "verification_requests/public-user")));
    await assertFails(updateDoc(doc(owner, "verification_requests/public-user"), {status: "approved"}));
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

  it("allows the authenticated story-rail list query and denies unauthenticated list", async () => {
    await seedFirestore();
    const reader = testEnv.authenticatedContext("reader").firestore();
    const unauthenticated = testEnv.unauthenticatedContext().firestore();
    const railQuery = query(
      collection(reader, "stories"),
      where("visibility", "==", "public"),
      where("authorAccountVisibility", "==", "public"),
      where("moderationState", "==", "active"),
      where("expiresAt", ">", new Date("2026-07-19T00:00:00Z")),
      orderBy("expiresAt"),
      orderBy("createdAt", "desc"),
      limit(50),
    );
    const deniedQuery = query(
      collection(unauthenticated, "stories"),
      where("visibility", "==", "public"),
      where("authorAccountVisibility", "==", "public"),
      where("moderationState", "==", "active"),
      where("expiresAt", ">", new Date("2026-07-19T00:00:00Z")),
      orderBy("expiresAt"),
      orderBy("createdAt", "desc"),
      limit(50),
    );

    const snapshot = await assertSucceeds(getDocs(railQuery));
    assert.equal(snapshot.size, 1);
    await assertFails(getDocs(deniedQuery));
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
      where("authorAccountVisibility", "==", "public"),
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

  it("denies all client access to message_requests", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "message_requests/a--b"), {
        requesterId: "a",
        targetId: "b",
        status: "pending",
        schemaVersion: 1,
      });
    });
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    const requester = testEnv.authenticatedContext("a").firestore();
    await assertFails(getDoc(doc(athlete, "message_requests/a--b")));
    await assertFails(getDoc(doc(requester, "message_requests/a--b")));
    await assertFails(setDoc(doc(requester, "message_requests/a--b"), {
      requesterId: "a",
      targetId: "b",
      status: "pending",
      schemaVersion: 1,
    }));
    await assertFails(deleteDoc(doc(requester, "message_requests/a--b")));
  });
});

describe("Phase 15 AI and server-only collections", () => {
  it("client cannot create AI usage or audit documents", async () => {
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    await assertFails(
      setDoc(doc(athlete, "ai_usage/athlete/days/2026-07-14"), {calls: 0}),
    );
    await assertFails(
      setDoc(doc(athlete, "ai_audit_logs/log-1"), {uid: "athlete"}),
    );
  });

  it("client cannot write trainer metrics directly", async () => {
    const trainer = testEnv.authenticatedContext("trainer-1").firestore();
    await assertFails(
      setDoc(doc(trainer, "trainer_metrics/trainer-1"), {revenueCents: 999999}),
    );
  });

  it("owner can read own trainer metrics when seeded by server", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "trainer_metrics/trainer-1"), {
        sessionsCompleted: 3,
        schemaVersion: 1,
      });
    });
    const trainer = testEnv.authenticatedContext("trainer-1").firestore();
    await assertSucceeds(getDoc(doc(trainer, "trainer_metrics/trainer-1")));
  });

  it("admin can read AI audit logs; regular user cannot", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "ai_audit_logs/log-1"), {
        uid: "athlete",
        module: "coach",
      });
    });
    const admin = testEnv.authenticatedContext("admin-1", {admin: true})
      .firestore();
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    await assertSucceeds(getDoc(doc(admin, "ai_audit_logs/log-1")));
    await assertFails(getDoc(doc(athlete, "ai_audit_logs/log-1")));
  });

  it("clients cannot write notification deliveries or moderation queue", async () => {
    const athlete = testEnv.authenticatedContext("athlete").firestore();
    await assertFails(
      setDoc(doc(athlete, "notification_deliveries/delivery-1"), {
        recipientId: "athlete",
      }),
    );
    await assertFails(
      setDoc(doc(athlete, "moderation_queue/item-1"), {status: "open"}),
    );
  });
});

describe("groups foundation rules", () => {
  it("allows public group get/list and denies client writes", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "groups/public-group"), {
        name: "Public",
        privacy: "public",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
      await setDoc(doc(db, "groups/private-group"), {
        name: "Private",
        privacy: "private",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
      await setDoc(doc(db, "groups/hidden-group"), {
        name: "Hidden",
        privacy: "hidden",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
    });

    const athlete = testEnv.authenticatedContext("athlete").firestore();
    await assertSucceeds(getDoc(doc(athlete, "groups/public-group")));
    await assertFails(getDoc(doc(athlete, "groups/private-group")));
    await assertFails(getDoc(doc(athlete, "groups/hidden-group")));
    await assertFails(setDoc(doc(athlete, "groups/public-group"), {name: "x"}));

    const publicList = query(
      collection(athlete, "groups"),
      where("privacy", "==", "public"),
      where("status", "==", "active"),
      where("moderationState", "==", "active"),
      limit(40),
    );
    await assertSucceeds(getDocs(publicList));
  });

  it("lets members read private groups; join requests stay manager-only", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "groups/member-group"), {
        name: "Members only",
        privacy: "private",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 2,
      });
      await setDoc(doc(db, "groups/member-group/members/member"), {
        userId: "member",
        role: "member",
        status: "active",
        removedAt: null,
      });
      await setDoc(doc(db, "groups/member-group/members/owner"), {
        userId: "owner",
        role: "owner",
        status: "active",
        removedAt: null,
      });
      await setDoc(doc(db, "groups/member-group/join_requests/requester"), {
        requesterId: "requester",
        status: "pending",
      });
    });

    const member = testEnv.authenticatedContext("member").firestore();
    const stranger = testEnv.authenticatedContext("stranger").firestore();
    const owner = testEnv.authenticatedContext("owner").firestore();

    await assertSucceeds(getDoc(doc(member, "groups/member-group")));
    await assertFails(getDoc(doc(stranger, "groups/member-group")));
    await assertSucceeds(
      getDoc(doc(owner, "groups/member-group/join_requests/requester")),
    );
    await assertFails(
      getDoc(doc(member, "groups/member-group/join_requests/requester")),
    );
    await assertFails(
      setDoc(doc(member, "groups/member-group/members/member"), {role: "admin"}),
    );
  });

  it("requester can read their own pending join request; strangers cannot", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "groups/req-group"), {
        name: "Requestable",
        privacy: "private",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
      await setDoc(doc(db, "groups/req-group/join_requests/requester"), {
        requesterId: "requester",
        status: "pending",
      });
    });

    const requester = testEnv.authenticatedContext("requester").firestore();
    const stranger = testEnv.authenticatedContext("stranger").firestore();
    await assertSucceeds(
      getDoc(doc(requester, "groups/req-group/join_requests/requester")),
    );
    await assertFails(
      getDoc(doc(stranger, "groups/req-group/join_requests/requester")),
    );
    await assertFails(
      setDoc(doc(requester, "groups/req-group/join_requests/requester"), {
        status: "cancelled",
      }),
    );
  });

  it("public group active members are listable by any signed-in user", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "groups/roster-group"), {
        name: "Roster",
        privacy: "public",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
      await setDoc(doc(db, "groups/roster-group/members/owner"), {
        userId: "owner",
        role: "owner",
        status: "active",
        removedAt: null,
      });
    });

    const stranger = testEnv.authenticatedContext("stranger").firestore();
    await assertSucceeds(
      getDoc(doc(stranger, "groups/roster-group/members/owner")),
    );
    const rosterQuery = query(
      collection(stranger, "groups/roster-group/members"),
      where("status", "==", "active"),
      limit(100),
    );
    await assertSucceeds(getDocs(rosterQuery));
  });

  it("group sessions follow group privacy: public previewable, private members-only", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "groups/public-sched"), {
        name: "Public Schedule",
        privacy: "public",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
      await setDoc(doc(db, "groups/public-sched/sessions/session-1"), {
        title: "Saturday run",
        status: "scheduled",
      });
      await setDoc(doc(db, "groups/private-sched"), {
        name: "Private Schedule",
        privacy: "private",
        status: "active",
        moderationState: "active",
        ownerId: "owner",
        memberCount: 1,
      });
      await setDoc(doc(db, "groups/private-sched/sessions/session-1"), {
        title: "Members only run",
        status: "scheduled",
      });
    });

    const stranger = testEnv.authenticatedContext("stranger").firestore();
    await assertSucceeds(
      getDoc(doc(stranger, "groups/public-sched/sessions/session-1")),
    );
    await assertFails(
      getDoc(doc(stranger, "groups/private-sched/sessions/session-1")),
    );
    await assertFails(
      setDoc(doc(stranger, "groups/public-sched/sessions/session-1"), {
        title: "Hijacked",
      }),
    );
  });

  it("lets owners read denormalized group inboxes but denies client writes", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users/member/group_memberships/g1"), {
        groupId: "g1",
        role: "member",
        status: "active",
      });
      await setDoc(doc(db, "users/member/group_invitations/g2"), {
        groupId: "g2",
        status: "pending",
      });
    });

    const member = testEnv.authenticatedContext("member").firestore();
    const stranger = testEnv.authenticatedContext("stranger").firestore();
    await assertSucceeds(
      getDoc(doc(member, "users/member/group_memberships/g1")),
    );
    await assertSucceeds(
      getDoc(doc(member, "users/member/group_invitations/g2")),
    );
    await assertFails(
      getDoc(doc(stranger, "users/member/group_memberships/g1")),
    );
    await assertFails(
      setDoc(doc(member, "users/member/group_memberships/g1"), {role: "owner"}),
    );
  });
});
