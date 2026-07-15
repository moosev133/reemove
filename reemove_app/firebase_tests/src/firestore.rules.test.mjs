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
      port: 8080,
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

  it("allows profile creation only after the matching username reservation", async () => {
    await seedFirestore();
    const alice = testEnv.authenticatedContext("alice").firestore();
    const bob = testEnv.authenticatedContext("bob").firestore();

    await assertSucceeds(setDoc(doc(alice, "users/alice"), newClientUser("alice")));
    await assertFails(setDoc(doc(bob, "users/bob"), newClientUser("bob")));
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
    await assertFails(setDoc(doc(athlete, "unknown/document"), {value: true}));
  });
});
