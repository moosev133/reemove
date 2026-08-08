import fs from "node:fs";
import path from "node:path";
import {after, before, beforeEach, describe, it} from "node:test";
import {fileURLToPath} from "node:url";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, setDoc} from "firebase/firestore";
import {deleteObject, getBytes, ref, uploadBytes} from "firebase/storage";

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
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync(path.join(projectRoot, "storage.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
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

describe("profile cover and verification evidence rules", () => {
  it("allows an owner to upload a valid cover image", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const cover = ref(storage, "users/alice/cover/cover.png");

    await assertSucceeds(uploadBytes(cover, bytes, validMetadata));
    await assertSucceeds(deleteObject(cover));
  });

  it("keeps verification evidence private and owner-scoped", async () => {
    const alice = testEnv.authenticatedContext("alice").storage();
    const bob = testEnv.authenticatedContext("bob").storage();
    const evidencePath = "verification/alice/alice/evidence.png";
    await assertSucceeds(uploadBytes(ref(alice, evidencePath), bytes, {
      contentType: "image/png",
      customMetadata: {
        ownerId: "alice", schemaVersion: "1", purpose: "profile-verification",
      },
    }));
    await assertSucceeds(getBytes(ref(alice, evidencePath)));
    await assertFails(getBytes(ref(bob, evidencePath)));
    await assertFails(uploadBytes(
      ref(bob, "verification/alice/alice/forged.png"),
      bytes,
      {contentType: "image/png", customMetadata: {ownerId: "bob", schemaVersion: "1"}},
    ));
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

describe("groups storage foundation", () => {
  it("denies client reads and writes under groups/{groupId}/{assetId}", async () => {
    const storage = testEnv.authenticatedContext("alice").storage();
    const avatar = ref(storage, "groups/g1/avatar");
    await assertFails(uploadBytes(avatar, bytes, {
      contentType: "image/png",
      customMetadata: {ownerId: "alice", schemaVersion: "1"},
    }));
    await assertFails(getBytes(avatar));
  });

  it("allows conversation members to upload normal group channel media", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "conversations/conv-sports/members/alice"), {
        removedAt: null,
        role: "member",
      });
    });
    const storage = testEnv.authenticatedContext("alice").storage();
    const path =
      "groups/g1/channels/member_chat/msg1/asset1/photo.jpg";
    await assertSucceeds(uploadBytes(ref(storage, path), bytes, {
      contentType: "image/jpeg",
      customMetadata: {
        ownerId: "alice",
        groupId: "g1",
        channelType: "member_chat",
        conversationId: "conv-sports",
        messageId: "msg1",
        assetId: "asset1",
        kind: "image",
        mediaMode: "normal",
        schemaVersion: "1",
      },
    }));
    await assertSucceeds(getBytes(ref(storage, path)));
  });

  it("denies client read of view_once group channel media", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const storage = context.storage();
      await setDoc(doc(db, "conversations/conv-sports/members/alice"), {
        removedAt: null,
        role: "member",
      });
      await uploadBytes(
        ref(storage, "groups/g1/channels/member_chat/msg2/asset2/secret.jpg"),
        bytes,
        {
          contentType: "image/jpeg",
          customMetadata: {
            ownerId: "alice",
            groupId: "g1",
            channelType: "member_chat",
            conversationId: "conv-sports",
            messageId: "msg2",
            assetId: "asset2",
            kind: "image",
            mediaMode: "view_once",
            schemaVersion: "1",
          },
        },
      );
    });
    const storage = testEnv.authenticatedContext("alice").storage();
    await assertFails(getBytes(
      ref(storage, "groups/g1/channels/member_chat/msg2/asset2/secret.jpg"),
    ));
  });

  it("denies a removed group member from reading normal group channel media", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const storage = context.storage();
      await setDoc(doc(db, "conversations/conv-sports/members/alice"), {
        removedAt: null,
        role: "member",
      });
      await uploadBytes(
        ref(storage, "groups/g1/channels/member_chat/msg5/asset5/photo.jpg"),
        bytes,
        {
          contentType: "image/jpeg",
          customMetadata: {
            ownerId: "alice",
            groupId: "g1",
            channelType: "member_chat",
            conversationId: "conv-sports",
            messageId: "msg5",
            assetId: "asset5",
            kind: "image",
            mediaMode: "normal",
            schemaVersion: "1",
          },
        },
      );
      // Simulate removeUserFromGroupChannels marking the conversation member removed.
      await setDoc(doc(db, "conversations/conv-sports/members/alice"), {
        removedAt: new Date(),
        role: "member",
      });
    });
    const storage = testEnv.authenticatedContext("alice").storage();
    await assertFails(getBytes(
      ref(storage, "groups/g1/channels/member_chat/msg5/asset5/photo.jpg"),
    ));
  });

  it("delete allows the uploader or a conversation admin, denies others", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const storage = context.storage();
      await setDoc(doc(db, "conversations/conv-del/members/alice"), {
        removedAt: null,
        role: "member",
      });
      await setDoc(doc(db, "conversations/conv-del/members/admin"), {
        removedAt: null,
        role: "admin",
      });
      await setDoc(doc(db, "conversations/conv-del/members/stranger"), {
        removedAt: null,
        role: "member",
      });
      await uploadBytes(
        ref(storage, "groups/g1/channels/member_chat/msg4/asset4/photo.jpg"),
        bytes,
        {
          contentType: "image/jpeg",
          customMetadata: {
            ownerId: "alice",
            groupId: "g1",
            channelType: "member_chat",
            conversationId: "conv-del",
            messageId: "msg4",
            assetId: "asset4",
            kind: "image",
            mediaMode: "normal",
            schemaVersion: "1",
          },
        },
      );
    });

    const strangerStorage = testEnv.authenticatedContext("stranger").storage();
    await assertFails(deleteObject(
      ref(strangerStorage, "groups/g1/channels/member_chat/msg4/asset4/photo.jpg"),
    ));

    const adminStorage = testEnv.authenticatedContext("admin").storage();
    await assertSucceeds(deleteObject(
      ref(adminStorage, "groups/g1/channels/member_chat/msg4/asset4/photo.jpg"),
    ));
  });

  it("denies view_once upload to announcements channel", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "conversations/conv-announce/members/alice"), {
        removedAt: null,
        role: "admin",
      });
    });
    const storage = testEnv.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(
      ref(storage, "groups/g1/channels/announcements/msg3/asset3/x.jpg"),
      bytes,
      {
        contentType: "image/jpeg",
        customMetadata: {
          ownerId: "alice",
          groupId: "g1",
          channelType: "announcements",
          conversationId: "conv-announce",
          messageId: "msg3",
          assetId: "asset3",
          kind: "image",
          mediaMode: "view_once",
          schemaVersion: "1",
        },
      },
    ));
  });
});
