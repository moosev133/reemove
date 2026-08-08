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
  documentId,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
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

  it("denies reaction whereIn without limit (inbox-ok / thread-fail regression)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    // Mirrors the Flutter bug: inbox preview is readable, then opening the
    // conversation hydrates reactions via documentId whereIn with no limit.
    await assertSucceeds(
      getDocs(
        query(
          collection(alice, "users/alice/conversation_inbox"),
          where("isArchived", "==", false),
          orderBy("updatedAt", "desc"),
          limit(50),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(alice, "conversations/conversation-1/messages"),
          orderBy("sentAt", "desc"),
          limit(40),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(alice, "users/alice/message_reactions"),
          where(documentId(), "in", ["conversation-1--message-1"]),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(alice, "users/alice/message_reactions"),
          where(documentId(), "in", ["conversation-1--message-1"]),
          limit(1),
        ),
      ),
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

describe("sports group channel message history", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = new Date("2026-08-04T12:00:00Z");
      await Promise.all([
        setDoc(doc(db, "conversations/c2-member-chat"), {
          type: "group",
          source: "sports_group",
          groupId: "c2-manual-test",
          channelType: "member_chat",
          title: "C2-MANUAL-TEST",
          createdBy: "owner-a",
          memberCount: 2,
          moderationState: "active",
          createdAt: now,
          updatedAt: now,
          schemaVersion: 1,
        }),
        setDoc(doc(db, "conversations/c2-member-chat/members/owner-a"), {
          userId: "owner-a",
          role: "owner",
          removedAt: null,
          joinedAt: now,
        }),
        setDoc(doc(db, "conversations/c2-member-chat/members/member-b"), {
          userId: "member-b",
          role: "member",
          removedAt: null,
          joinedAt: now,
        }),
        setDoc(doc(db, "conversations/c2-member-chat/messages/step2"), {
          conversationId: "c2-member-chat",
          senderId: "member-b",
          kind: "text",
          text: "C2 step2 member text",
          sentAt: now,
          isDeleted: false,
          moderationState: "active",
        }),
        setDoc(doc(db, "users/owner-a/conversation_inbox/c2-member-chat"), {
          conversationId: "c2-member-chat",
          type: "group",
          source: "sports_group",
          groupId: "c2-manual-test",
          channelType: "member_chat",
          title: "C2-MANUAL-TEST",
          isArchived: false,
          unreadCount: 1,
          lastMessage: {
            id: "step2",
            preview: "C2 step2 member text",
            sentAt: now,
          },
          updatedAt: now,
        }),
        setDoc(doc(db, "users/member-b/conversation_inbox/c2-member-chat"), {
          conversationId: "c2-member-chat",
          type: "group",
          source: "sports_group",
          channelType: "member_chat",
          title: "C2-MANUAL-TEST",
          isArchived: false,
          unreadCount: 0,
          updatedAt: now,
        }),
      ]);
    });
  });

  it("owner can read inbox preview and list the same conversation messages", async () => {
    const owner = testEnv.authenticatedContext("owner-a").firestore();
    const inbox = await assertSucceeds(
      getDocs(
        query(
          collection(owner, "users/owner-a/conversation_inbox"),
          where("isArchived", "==", false),
          orderBy("updatedAt", "desc"),
          limit(50),
        ),
      ),
    );
    assert.equal(inbox.size, 1);
    assert.equal(inbox.docs[0].id, "c2-member-chat");

    const messages = await assertSucceeds(
      getDocs(
        query(
          collection(owner, "conversations/c2-member-chat/messages"),
          orderBy("sentAt", "desc"),
          orderBy(documentId(), "desc"),
          limit(40),
        ),
      ),
    );
    assert.equal(messages.size, 1);
    assert.equal(messages.docs[0].id, "step2");
  });

  it("active member can list messages; stranger and removed cannot", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "conversations/c2-member-chat/members/removed-c"), {
        userId: "removed-c",
        role: "member",
        removedAt: new Date("2026-08-04T13:00:00Z"),
        joinedAt: new Date("2026-08-04T11:00:00Z"),
      });
    });

    const member = testEnv.authenticatedContext("member-b").firestore();
    const stranger = testEnv.authenticatedContext("stranger").firestore();
    const removed = testEnv.authenticatedContext("removed-c").firestore();
    const messagesQuery = (db) =>
      query(
        collection(db, "conversations/c2-member-chat/messages"),
        orderBy("sentAt", "desc"),
        limit(40),
      );

    await assertSucceeds(getDocs(messagesQuery(member)));
    await assertFails(getDocs(messagesQuery(stranger)));
    await assertFails(getDocs(messagesQuery(removed)));
  });

  it("clients cannot tombstone messages directly (moderation is server-only)", async () => {
    const owner = testEnv.authenticatedContext("owner-a").firestore();
    const member = testEnv.authenticatedContext("member-b").firestore();
    await assertFails(
      updateDoc(doc(owner, "conversations/c2-member-chat/messages/step2"), {
        isDeleted: true,
        kind: "deleted",
        text: "",
        deletedBy: "owner-a",
      }),
    );
    await assertFails(
      updateDoc(doc(member, "conversations/c2-member-chat/messages/step2"), {
        isDeleted: true,
        kind: "deleted",
      }),
    );
  });
});
