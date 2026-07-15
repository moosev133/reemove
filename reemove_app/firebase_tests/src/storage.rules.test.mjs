import fs from "node:fs";
import path from "node:path";
import {after, before, beforeEach, describe, it} from "node:test";
import {fileURLToPath} from "node:url";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteObject, getBytes, ref, uploadBytes} from "firebase/storage";

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(dirname, "../..");
const projectId = "demo-reemove";
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync(path.join(projectRoot, "storage.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

const bytes = new Uint8Array([137, 80, 78, 71]);
const validMetadata = {
  contentType: "image/png",
  customMetadata: {ownerId: "alice", schemaVersion: "1"},
};

describe("avatar storage rules", () => {
  it("allows an owner to upload and delete a valid image", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const avatar = ref(storage, "users/alice/avatar/avatar.png");

    await assertSucceeds(uploadBytes(avatar, bytes, validMetadata));
    await assertSucceeds(deleteObject(avatar));
  });

  it("rejects uploads to another user's path and invalid content types", async () => {
    const storage = testEnv.authenticatedContext("bob").storage();
    const aliceAvatar = ref(storage, "users/alice/avatar/avatar.png");
    const bobAvatar = ref(storage, "users/bob/avatar/avatar.txt");

    await assertFails(uploadBytes(aliceAvatar, bytes, validMetadata));
    await assertFails(uploadBytes(bobAvatar, bytes, {
      contentType: "text/plain",
      customMetadata: {ownerId: "bob", schemaVersion: "1"},
    }));
  });

  it("requires owner metadata", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const avatar = ref(storage, "users/alice/avatar/avatar.png");

    await assertFails(uploadBytes(avatar, bytes, {contentType: "image/png"}));
  });
});

describe("processed media rules", () => {
  it("blocks clients from writing processed post variants", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const processed = ref(storage, "posts/alice/post-1/processed/asset.png");

    await assertFails(uploadBytes(processed, bytes, validMetadata));
  });

  it("allows authenticated reads but blocks signed-out reads", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), "users/alice/avatar/avatar.png"),
        bytes,
        validMetadata,
      );
    });

    const authenticated = testEnv.authenticatedContext("reader").storage();
    const unauthenticated = testEnv.unauthenticatedContext().storage();

    await assertSucceeds(getBytes(ref(authenticated, "users/alice/avatar/avatar.png")));
    await assertFails(getBytes(ref(unauthenticated, "users/alice/avatar/avatar.png")));
  });
});

describe("social content upload rules", () => {
  const contentMetadata = {
    contentType: "image/png",
    customMetadata: {
      ownerId: "alice",
      draftId: "draft-1",
      assetId: "asset-1",
      kind: "image",
      schemaVersion: "1",
    },
  };

  it("allows only the owner to read, upload, and delete a draft asset", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const asset = ref(storage, "content/alice/draft-1/asset-1/photo.png");
    await assertSucceeds(uploadBytes(asset, bytes, contentMetadata));
    await assertSucceeds(getBytes(asset));
    const other = testEnv.authenticatedContext("bob").storage();
    await assertFails(
      getBytes(ref(other, "content/alice/draft-1/asset-1/photo.png")),
    );
    await assertSucceeds(deleteObject(asset));
  });

  it("rejects ownership, path metadata, and media-kind mismatches", async () => {
    const bob = testEnv.authenticatedContext("bob").storage();
    await assertFails(uploadBytes(
      ref(bob, "content/alice/draft-1/asset-1/photo.png"),
      bytes,
      contentMetadata,
    ));

    const alice = testEnv.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(
      ref(alice, "content/alice/draft-2/asset-1/photo.png"),
      bytes,
      contentMetadata,
    ));
    await assertFails(uploadBytes(
      ref(alice, "content/alice/draft-1/asset-1/photo.png"),
      bytes,
      {
        ...contentMetadata,
        customMetadata: {...contentMetadata.customMetadata, kind: "video"},
      },
    ));
  });

  it("keeps processed variants server-owned", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const metadata = {
      contentType: "video/mp4",
      customMetadata: {ownerId: "alice", schemaVersion: "1"},
    };
    await assertFails(uploadBytes(
      ref(storage, "processed_content/alice/asset-1/output.mp4"),
      bytes,
      metadata,
    ));
    await assertFails(uploadBytes(
      ref(storage, "processed/alice/asset-1/output.mp4"),
      bytes,
      metadata,
    ));
  });
});
