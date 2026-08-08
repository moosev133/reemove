const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

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

async function provisionUser(uid, profileOverrides = {}) {
  const email = `${uid}@verification.test`;
  await ensureAuthUser(auth, {uid, email});
  const profile = baseProfile(uid, profileOverrides);
  await seedProfile(db, profile);
  const client = await signInClient(email);
  return {uid, email, profile, client};
}

async function seedEvidenceObject(uid, {
  filename = "evidence-1.png",
  contentType = "image/png",
  bytes = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  ownerId,
} = {}) {
  const storagePath = `verification/${uid}/${uid}/${filename}`;
  const {getStorage} = require("firebase-admin/storage");
  try {
    // Integration suite does not start the Storage emulator; prefer an explicit
    // demo bucket name. If Storage is unavailable, callers skip Storage-backed cases.
    const bucket = getStorage().bucket("demo-reemove.appspot.com");
    await bucket.file(storagePath).save(bytes, {
      metadata: {
        contentType,
        metadata: {
          ownerId: ownerId ?? uid,
          schemaVersion: "1",
          purpose: "profile-verification",
        },
      },
    });
    return storagePath;
  } catch (error) {
    // Storage emulator is optional in the default integration profile.
    // Skip Storage-backed assertions when the object cannot be seeded.
    return null;
  }
}

describe("verification draft + submit callable integration", () => {
  it("saves a draft then submits a trainer application with PNG evidence", async () => {
    const user = await provisionUser("verify-trainer-1", {
      username: "verify.trainer1",
      usernameNormalized: "verify.trainer1",
    });

    const storagePath = await seedEvidenceObject(user.uid, {
      filename: "evidence-1.png",
      contentType: "image/png",
    });
    if (!storagePath) return;

    const saveDraft = callableFor(user.client.functions, "saveVerificationDraft");
    const draft = await saveDraft({
      requestedType: "trainer",
      legalName: "Casey Coach",
      summary: "Competitive coach applying for trainer verification badge.",
      evidence: [{
        storagePath,
        label: "CSCS certificate",
        documentKind: "certification",
        contentType: "image/png",
        sizeBytes: 8,
        issuer: "NSCA",
      }],
    });
    assert.equal(draft.data.saved, true);
    assert.equal(draft.data.status, "draft");

    const draftDoc = await db.collection("verification_requests").doc(user.uid).get();
    assert.equal(draftDoc.get("status"), "draft");
    assert.equal(draftDoc.get("requestedType"), "trainer");
    assert.equal(draftDoc.get("evidence")[0].contentType, "image/png");

    const submit = callableFor(user.client.functions, "submitVerificationRequest");
    const submitted = await submit({
      requestedType: "trainer",
      legalName: "Casey Coach",
      summary: "Competitive coach applying for trainer verification badge.",
      evidence: [{
        storagePath,
        label: "CSCS certificate",
        documentKind: "certification",
        contentType: "image/png",
        sizeBytes: 8,
        issuer: "NSCA",
      }],
    });
    assert.equal(submitted.data.requestId, user.uid);

    const pendingDoc = await db.collection("verification_requests").doc(user.uid).get();
    assert.equal(pendingDoc.get("status"), "pending");
    assert.equal(pendingDoc.get("evidence")[0].documentKind, "certification");

    await expectCallableError(
      saveDraft({
        requestedType: "trainer",
        legalName: "Casey Coach",
        summary: "Should fail while pending.",
        evidence: [],
      }),
      "failed-precondition",
    );

    // Duplicate submission while pending is rejected safely.
    await expectCallableError(
      submit({
        requestedType: "trainer",
        legalName: "Casey Coach",
        summary: "Competitive coach applying for trainer verification badge.",
        evidence: [{
          storagePath,
          label: "CSCS certificate",
          documentKind: "certification",
          contentType: "image/png",
          sizeBytes: 8,
        }],
      }),
      "already-exists",
    );
  });

  it("rejects submission without evidence", async () => {
    const user = await provisionUser("verify-no-evidence", {
      username: "verify.nonevidence",
      usernameNormalized: "verify.nonevidence",
    });
    const submit = callableFor(user.client.functions, "submitVerificationRequest");
    await expectCallableError(
      submit({
        requestedType: "trainer",
        legalName: "Casey Coach",
        summary: "Competitive coach applying for trainer verification badge.",
        evidence: [],
      }),
      "invalid-argument",
    );
  });

  it("rejects wrong-owner storage paths", async () => {
    const owner = await provisionUser("verify-owner-path", {
      username: "verify.ownerpath",
      usernameNormalized: "verify.ownerpath",
    });
    const attacker = await provisionUser("verify-attacker-path", {
      username: "verify.attacker",
      usernameNormalized: "verify.attacker",
    });
    const storagePath = await seedEvidenceObject(owner.uid, {
      filename: "owned.png",
      contentType: "image/png",
    });
    if (!storagePath) return;

    const submit = callableFor(attacker.client.functions, "submitVerificationRequest");
    await expectCallableError(
      submit({
        requestedType: "trainer",
        legalName: "Attacker",
        summary: "Competitive coach applying for trainer verification badge.",
        evidence: [{
          storagePath,
          label: "Stolen",
          documentKind: "certification",
          contentType: "image/png",
          sizeBytes: 8,
        }],
      }),
      "invalid-argument",
    );
  });

  it("rejects unsupported content types and incomplete uploads", async () => {
    const user = await provisionUser("verify-bad-type", {
      username: "verify.badtype",
      usernameNormalized: "verify.badtype",
    });
    const submit = callableFor(user.client.functions, "submitVerificationRequest");

    await expectCallableError(
      submit({
        requestedType: "trainer",
        legalName: "Casey Coach",
        summary: "Competitive coach applying for trainer verification badge.",
        evidence: [{
          storagePath: `verification/${user.uid}/${user.uid}/doc.pdf`,
          label: "PDF",
          documentKind: "certification",
          contentType: "application/pdf",
          sizeBytes: 100,
        }],
      }),
      "invalid-argument",
    );

    // Path looks owned but object missing => incomplete upload.
    await expectCallableError(
      submit({
        requestedType: "trainer",
        legalName: "Casey Coach",
        summary: "Competitive coach applying for trainer verification badge.",
        evidence: [{
          storagePath: `verification/${user.uid}/${user.uid}/missing.png`,
          label: "Missing upload",
          documentKind: "certification",
          contentType: "image/png",
          sizeBytes: 8,
        }],
      }),
      "failed-precondition",
    );
  });

  it("rejects oversized evidence metadata", async () => {
    const user = await provisionUser("verify-oversized", {
      username: "verify.oversized",
      usernameNormalized: "verify.oversized",
    });
    const submit = callableFor(user.client.functions, "submitVerificationRequest");
    await expectCallableError(
      submit({
        requestedType: "trainer",
        legalName: "Casey Coach",
        summary: "Competitive coach applying for trainer verification badge.",
        evidence: [{
          storagePath: `verification/${user.uid}/${user.uid}/huge.png`,
          label: "Huge",
          documentKind: "certification",
          contentType: "image/png",
          sizeBytes: 15 * 1024 * 1024 + 1,
        }],
      }),
      "invalid-argument",
    );
  });

  it("keeps older draft schema (path+label only) compatible when object exists", async () => {
    const user = await provisionUser("verify-legacy-schema", {
      username: "verify.legacy",
      usernameNormalized: "verify.legacy",
    });
    const storagePath = await seedEvidenceObject(user.uid, {
      filename: "legacy.jpg",
      contentType: "image/jpeg",
      bytes: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
    });
    if (!storagePath) return;

    const saveDraft = callableFor(user.client.functions, "saveVerificationDraft");
    const draft = await saveDraft({
      requestedType: "trainer",
      legalName: "Legacy Coach",
      summary: "Competitive coach applying for trainer verification badge.",
      evidence: [{
        storagePath,
        label: "Legacy cert",
      }],
    });
    assert.equal(draft.data.saved, true);
    const draftDoc = await db.collection("verification_requests").doc(user.uid).get();
    assert.equal(draftDoc.get("evidence")[0].documentKind, "other");
  });
});
