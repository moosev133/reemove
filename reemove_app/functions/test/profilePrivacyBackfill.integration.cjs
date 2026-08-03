const assert = require("node:assert/strict");
const {describe, it} = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");

const {
  baseProfile,
  callableFor,
  ensureAuthUser,
  expectCallableError,
  initAdmin,
  seedProfile,
  signInClient,
} = require("./helpers/emulatorHarness.cjs");

const {auth, db} = initAdmin();

async function provisionAdmin(uid = "pp-admin") {
  const email = `${uid}@privacy.test`;
  await ensureAuthUser(auth, {uid, email, claims: {admin: true}});
  const profile = baseProfile(uid, {
    username: "pp.admin",
    usernameNormalized: "pp.admin",
    role: "admin",
  });
  await seedProfile(db, profile);
  const client = await signInClient(email);
  return {uid, client};
}

async function provisionUser(uid) {
  const email = `${uid}@privacy.test`;
  await ensureAuthUser(auth, {uid, email});
  return email;
}

async function snapshotUser(uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  return snapshot.exists ? {...snapshot.data()} : null;
}

async function seedIncompleteUser(uid, data) {
  const profile = baseProfile(uid, {
    username: uid.replaceAll("-", "."),
    usernameNormalized: uid.replaceAll("-", "."),
    ...data,
  });
  delete profile.accountPrivacy;
  delete profile.followApprovalPolicy;
  delete profile.visibilityRevision;
  if (data.visibility === undefined) {
    delete profile.visibility;
  }
  await db.collection("users").doc(uid).set(profile, {merge: false});
  await db.collection("usernames").doc(profile.usernameNormalized).set({
    uid: profile.uid,
    username: profile.username,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    schemaVersion: 1,
  }, {merge: true});
}

describe("backfillProfilePrivacyDefaults emulator integration", () => {
  it("default and reportOnly calls perform zero writes", async () => {
    const uid = "pp-backfill-dry";
    await seedIncompleteUser(uid, {});
    const before = await snapshotUser(uid);
    const admin = await provisionAdmin("pp-admin-dry");
    const backfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    const dryRun = await backfill({});
    assert.equal(dryRun.data.mode, "reportOnly");
    assert.ok(dryRun.data.changed >= 1);
    assert.deepEqual(await snapshotUser(uid), before);

    const reportOnly = await backfill({reportOnly: true, limit: 500});
    assert.equal(reportOnly.data.mode, "reportOnly");
    assert.deepEqual(await snapshotUser(uid), before);
  });

  it("apply:true updates only missing fields and preserves explicit values", async () => {
    const missingUid = "pp-backfill-apply-missing";
    await seedIncompleteUser(missingUid, {visibility: "followers"});
    const preservedUid = "pp-backfill-apply-preserved";
    await seedProfile(db, baseProfile(preservedUid, {
      username: "pp.preserved",
      usernameNormalized: "pp.preserved",
      visibility: "private",
      accountPrivacy: "ownerOnly",
      followApprovalPolicy: "approvalRequired",
      visibilityRevision: 4,
    }));

    const admin = await provisionAdmin("pp-admin-apply");
    const backfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    const result = await backfill({apply: true, limit: 500});
    assert.equal(result.data.mode, "apply");
    assert.ok(result.data.changed >= 1);

    const missing = await snapshotUser(missingUid);
    assert.equal(missing.accountPrivacy, "private");
    assert.equal(missing.visibility, "followers");
    assert.equal(missing.followApprovalPolicy, "approvalRequired");
    assert.equal(missing.visibilityRevision, 0);

    const preserved = await snapshotUser(preservedUid);
    assert.equal(preserved.visibility, "private");
    assert.equal(preserved.accountPrivacy, "ownerOnly");
    assert.equal(preserved.visibilityRevision, 4);
  });

  it("honors batch limit and cursor pagination", async () => {
    for (let index = 0; index < 3; index += 1) {
      await seedIncompleteUser(`pp-backfill-page-${index}`, {});
    }
    const admin = await provisionAdmin("pp-admin-page");
    const backfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    const first = await backfill({limit: 2});
    assert.equal(first.data.scanned, 2);
    assert.ok(first.data.nextCursor);
    assert.equal(first.data.completed, false);

    const second = await backfill({
      limit: 2,
      cursor: first.data.nextCursor,
    });
    assert.ok(second.data.scanned >= 1);
    assert.equal(
      second.data.completed || second.data.nextCursor !== first.data.nextCursor,
      true,
    );
  });

  it("re-running apply is idempotent", async () => {
    const uid = "pp-backfill-idempotent";
    await seedIncompleteUser(uid, {});
    const admin = await provisionAdmin("pp-admin-idempotent");
    const backfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    const first = await backfill({apply: true, limit: 500});
    assert.ok(first.data.changed >= 1);
    const afterFirst = await snapshotUser(uid);

    const second = await backfill({apply: true, limit: 500});
    assert.ok(second.data.skipped >= 1);
    assert.deepEqual(await snapshotUser(uid), afterFirst);
  });

  it("reports scanned, changed, skipped, errors, errorIds, and samples", async () => {
    const uid = "pp-backfill-metrics";
    await seedIncompleteUser(uid, {});
    const admin = await provisionAdmin("pp-admin-metrics");
    const backfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    const result = await backfill({limit: 500});
    assert.ok(typeof result.data.scanned === "number");
    assert.ok(typeof result.data.changed === "number");
    assert.ok(typeof result.data.skipped === "number");
    assert.ok(typeof result.data.errors === "number");
    assert.ok(Array.isArray(result.data.errorIds));
    assert.ok(Array.isArray(result.data.samples));
    assert.equal(result.data.errors, 0);
    assert.equal(result.data.errorIds.length, 0);
  });

  it("creates audit records for dry-run and apply batches", async () => {
    const uid = "pp-backfill-audit";
    await seedIncompleteUser(uid, {});
    const admin = await provisionAdmin("pp-admin-audit");
    const backfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    await backfill({limit: 500});
    const dryAudit = await db.collection("audit_logs")
      .where("action", "in", [
        "profile.privacy_backfill_report",
        "profile.privacy_backfill_dry_run",
      ])
      .get();
    assert.ok(dryAudit.size >= 1);

    await backfill({apply: true, limit: 500});
    const applyAudit = await db.collection("audit_logs")
      .where("action", "==", "profile.privacy_backfill_batch_applied")
      .get();
    assert.ok(applyAudit.size >= 1);
  });

  it("rejects unauthorized callers and enforces rate limit", async () => {
    const nonAdminEmail = await provisionUser("pp-backfill-nonadmin");
    const nonAdmin = await signInClient(nonAdminEmail);
    const backfill = callableFor(
      nonAdmin.functions,
      "backfillProfilePrivacyDefaults",
    );
    await expectCallableError(backfill({}), "permission-denied");

    const admin = await provisionAdmin("pp-admin-rate");
    const adminBackfill = callableFor(
      admin.client.functions,
      "backfillProfilePrivacyDefaults",
    );
    let limited = false;
    for (let attempt = 0; attempt < 32; attempt += 1) {
      try {
        await adminBackfill({limit: 1});
      } catch (error) {
        if (String(error.code).includes("resource-exhausted")) {
          limited = true;
          break;
        }
        throw error;
      }
    }
    assert.equal(limited, true);
  });
});
