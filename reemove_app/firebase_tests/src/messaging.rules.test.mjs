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
  setDoc,
} from "firebase/firestore";

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(dirname, "../..");
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-reemove-messaging",
    firestore: {
      host: "127.0.0.1",
      port: 8180,
      rules: fs.readFileSync(path.join(projectRoot, "firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = new Date("2026-07-14T12:00:00Z");
    await Promise.all([
      setDoc(doc(db, "conversations/conversation-1"), {
        type: "direct",
        title: "Alice and Bob",
        createdBy: "alice",
        memberCount: 2,
        moderationState: "active",
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
      }),
      setDoc(doc(db, "conversations/conversation-1/members/alice"), {
        userId: "alice",
        role: "owner",
        removedAt: null,
        joinedAt: now,
      }),
      setDoc(doc(db, "conversations/conversation-1/members/bob"), {
        userId: "bob",
        role: "member",
        removedAt: null,
        joinedAt: now,
      }),
      setDoc(doc(db, "conversations/conversation-1/members/removed"), {
        userId: "removed",
        role: "member",
        removedAt: now,
        joinedAt: now,
      }),
      setDoc(doc(db, "conversations/conversation-1/messages/message-1"), {
        conversationId: "conversation-1",
        senderId: "alice",
        text: "Training at six?",
        kind: "text",
        sentAt: now,
      }),
      setDoc(doc(db, "users/alice/conversation_inbox/conversation-1"), {
        conversationId: "conversation-1",
        isArchived: false,
        unreadCount: 1,
        updatedAt: now,
      }),
      setDoc(doc(db, "users/alice/message_reactions/conversation-1--message-1"), {
        conversationId: "conversation-1",
        messageId: "message-1",
        emojis: ["🔥"],
      }),
      setDoc(doc(db, "users/alice/device_tokens/token-1"), {
        platform: "ios",
        createdAt: now,
      }),
    ]);
  });
});

after(async () => testEnv.cleanup());

describe("conversation membership rules", () => {
  it("allows active members to read conversations, members, and messages", async () => {
    const db = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "conversations/conversation-1")));
    await assertSucceeds(
      getDocs(query(collection(db, "conversations/conversation-1/members"), limit(100))),
    );
    const messages = await assertSucceeds(
      getDocs(query(collection(db, "conversations/conversation-1/messages"), limit(100))),
    );
    assert.equal(messages.size, 1);
  });

  it("denies outsiders, removed members, and all direct client writes", async () => {
    const outsider = testEnv.authenticatedContext("outsider").firestore();
    const removed = testEnv.authenticatedContext("removed").firestore();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(outsider, "conversations/conversation-1")));
    await assertFails(getDoc(doc(removed, "conversations/conversation-1")));
    await assertFails(
      setDoc(doc(alice, "conversations/conversation-1/messages/forged"), {
        text: "forged",
      }),
    );
  });
});

describe("private messaging metadata rules", () => {
  it("allows owners to read inbox, reactions, and device records", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      getDocs(query(collection(alice, "users/alice/conversation_inbox"), limit(100))),
    );
    await assertSucceeds(
      getDocs(query(collection(alice, "users/alice/message_reactions"), limit(100))),
    );
    await assertSucceeds(
      getDocs(query(collection(alice, "users/alice/device_tokens"), limit(100))),
    );
  });

  it("prevents other users and clients from reading or writing private metadata", async () => {
    const bob = testEnv.authenticatedContext("bob").firestore();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(bob, "users/alice/conversation_inbox/conversation-1")));
    await assertFails(
      setDoc(doc(alice, "users/alice/conversation_inbox/forged"), {
        unreadCount: 0,
      }),
    );
  });
});
