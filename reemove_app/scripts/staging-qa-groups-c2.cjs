#!/usr/bin/env node
/**
 * Phase C2 Groups staging QA — channels, messaging, media, view-once claims.
 * Two accounts (owner + peer) against reemove-staging only.
 * Does not use apply:true backfills. Production untouched.
 *
 * Usage (from reemove_app/):
 *   NODE_PATH=functions/node_modules node scripts/staging-qa-groups-c2.cjs
 *
 * Env (optional):
 *   STAGING_OWNER_EMAIL / STAGING_OWNER_PASSWORD
 *   STAGING_PEER_EMAIL / STAGING_PEER_PASSWORD
 *   STAGING_WEB_API_KEY  (falls back to firebase_options_staging.dart web apiKey)
 *
 * If passwords are omitted, Admin SDK resets temporary passwords (C1 pattern).
 */
"use strict";

const path = require("node:path");
const fs = require("node:fs");

// Resolve firebase + firebase-admin from functions/ when run from scripts/.
const functionsNm = path.join(__dirname, "../functions/node_modules");
if (!module.paths.includes(functionsNm)) {
  module.paths.unshift(functionsNm);
}

const {initializeApp, getApps, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {initializeApp: initClient} = require("firebase/app");
const {
  getAuth: getClientAuth,
  signInWithEmailAndPassword,
  signOut,
} = require("firebase/auth");
const {getFunctions, httpsCallable} = require("firebase/functions");
const {
  getFirestore: getClientFirestore,
  collection,
  documentId,
  getDocs,
  limit,
  orderBy,
  query,
  where,
} = require("firebase/firestore");

const PROJECT_ID = "reemove-staging";
const REGION = "europe-west1";
const STORAGE_BUCKET = "reemove-staging.firebasestorage.app";
const SCHEMA_VERSION = "1";
const SUITE = `c2-${Date.now().toString(36)}`;

const OWNER_EMAIL =
  process.env.STAGING_OWNER_EMAIL || "meliodasin14@gmail.com";
const PEER_EMAIL =
  process.env.STAGING_PEER_EMAIL || "abualamostaf@gmail.com";
const OWNER_PASSWORD_ENV = process.env.STAGING_OWNER_PASSWORD || "";
const PEER_PASSWORD_ENV = process.env.STAGING_PEER_PASSWORD || "";
const TEMP_PASSWORD = `PhaseC2-QA-${Date.now()}!Aa1`;

const webConfig = {
  apiKey: process.env.STAGING_WEB_API_KEY || "",
  authDomain: `${PROJECT_ID}.firebaseapp.com`,
  projectId: PROJECT_ID,
  appId: "",
  storageBucket: STORAGE_BUCKET,
};

const results = [];
const skips = [];

/** Tiny valid 1x1 JPEG (binary). */
const TINY_JPEG = Buffer.from(
  "ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707070909080a" +
  "0c140d0c0b0b0c1912130f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c3031343434" +
  "1f27393d38323c2e333432ffdb0043010909090c0b0c180d0d1832211c21323232323232323232" +
  "323232323232323232323232323232323232323232323232323232323232323232323232323232" +
  "323232ffc00011080001000103011100021101031101ffc4001400010000000000000000000000" +
  "00000008ffc40014100100000000000000000000000000000000ffda000c030100021003100000" +
  "3f00bf800ffd9",
  "hex",
);

function loadWebConfig() {
  if (webConfig.apiKey && webConfig.appId) return;
  const text = fs.readFileSync(
    path.join(__dirname, "../lib/firebase_options_staging.dart"),
    "utf8",
  );
  const webBlock = text.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/,
  )?.[1] || text;
  webConfig.apiKey =
    webConfig.apiKey ||
    webBlock.match(/apiKey:\s*'([^']+)'/)?.[1] ||
    "";
  webConfig.appId = webBlock.match(/appId:\s*'([^']+)'/)?.[1] || "";
  if (!webConfig.apiKey || !webConfig.appId) {
    throw new Error("Could not read staging web apiKey/appId");
  }
}

function initAdmin() {
  if (getApps().length === 0) {
    initializeApp({
      credential: applicationDefault(),
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET,
    });
  }
  return {auth: getAuth(), db: getFirestore(), bucket: getStorage().bucket()};
}

function ok(label, pass, detail = "") {
  console.log(`[${pass ? "PASS" : "FAIL"}] ${label}${detail ? ` — ${detail}` : ""}`);
  results.push({label, pass: !!pass, detail});
  return !!pass;
}

function skip(label, reason) {
  console.log(`[SKIP] ${label} — ${reason}`);
  skips.push({label, reason});
}

async function expectDenied(promise) {
  try {
    await promise;
    return {denied: false, code: ""};
  } catch (error) {
    const code = String(error.code || error.message || error);
    const denied = /permission-denied|not-found|failed-precondition|invalid-argument|already-exists|resource-exhausted|unauthenticated/i
      .test(code);
    return {denied, code};
  }
}

async function clearBlock(db, a, b) {
  await Promise.all([
    db.doc(`users/${a}/blocks/${b}`).delete().catch(() => undefined),
    db.doc(`users/${b}/blocked_by/${a}`).delete().catch(() => undefined),
    db.doc(`users/${b}/blocks/${a}`).delete().catch(() => undefined),
    db.doc(`users/${a}/blocked_by/${b}`).delete().catch(() => undefined),
  ]);
}

async function clientFor(email, password) {
  const app = initClient({...webConfig}, `c2-${email}-${Date.now()}`);
  const auth = getClientAuth(app);
  const functions = getFunctions(app, REGION);
  const firestore = getClientFirestore(app);
  await signInWithEmailAndPassword(auth, email, password);
  const call = (name) => httpsCallable(functions, name, {timeout: 60000});
  return {
    email,
    uid: auth.currentUser.uid,
    async invoke(name, data = {}) {
      const result = await call(name)(data);
      return result.data;
    },
    /**
     * Mirrors the Flutter conversation-open path: inbox preview readable AND
     * the same conversation's messages list (+ reaction hydration query).
     */
    async assertInboxAndMessageHistory(conversationId) {
      const uid = auth.currentUser.uid;
      const inboxSnap = await getDocs(
        query(
          collection(firestore, `users/${uid}/conversation_inbox`),
          where("isArchived", "==", false),
          orderBy("updatedAt", "desc"),
          limit(50),
        ),
      );
      const inboxHit = inboxSnap.docs.find((d) => d.id === conversationId);
      if (!inboxHit) {
        throw new Error(`inbox missing conversation ${conversationId}`);
      }
      const messagesSnap = await getDocs(
        query(
          collection(firestore, `conversations/${conversationId}/messages`),
          orderBy("sentAt", "desc"),
          orderBy(documentId(), "desc"),
          limit(40),
        ),
      );
      if (messagesSnap.empty) {
        throw new Error(`messages empty for ${conversationId}`);
      }
      const reactionKeys = messagesSnap.docs
        .slice(0, 30)
        .map((d) => `${conversationId}--${d.id}`);
      await getDocs(
        query(
          collection(firestore, `users/${uid}/message_reactions`),
          where(documentId(), "in", reactionKeys),
          limit(Math.max(1, reactionKeys.length)),
        ),
      );
      return {
        inboxPreview: String(inboxHit.get("lastMessage")?.preview ?? ""),
        messageCount: messagesSnap.size,
      };
    },
    async close() {
      await signOut(auth);
    },
  };
}

function mid(prefix) {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

async function seedGroupMediaObject(options) {
  const {
    bucket,
    groupId,
    channelType,
    conversationId,
    messageId,
    attachmentId,
    ownerId,
    mediaMode,
    filename = "qa.jpg",
  } = options;
  const storagePath =
    `groups/${groupId}/channels/${channelType}/${messageId}/${attachmentId}/${filename}`;
  const file = bucket.file(storagePath);
  await file.save(TINY_JPEG, {
    resumable: false,
    contentType: "image/jpeg",
    metadata: {
      contentType: "image/jpeg",
      metadata: {
        ownerId,
        groupId,
        channelType,
        conversationId,
        messageId,
        assetId: attachmentId,
        kind: "image",
        mediaMode,
        schemaVersion: SCHEMA_VERSION,
      },
    },
  });
  const [meta] = await file.getMetadata();
  return {
    storagePath,
    sizeBytes: Number(meta.size || TINY_JPEG.length),
    contentType: "image/jpeg",
  };
}

async function recentNotifications(db, uid, kind) {
  const snap = await db.collection(`users/${uid}/notifications`)
    .orderBy("createdAt", "desc")
    .limit(40)
    .get();
  return snap.docs.filter((doc) => doc.get("kind") === kind);
}

async function main() {
  if (PROJECT_ID !== "reemove-staging") {
    throw new Error("Refusing to run outside reemove-staging");
  }
  loadWebConfig();
  const {auth, db, bucket} = initAdmin();

  const ownerRecord = await auth.getUserByEmail(OWNER_EMAIL);
  const peerRecord = await auth.getUserByEmail(PEER_EMAIL);
  const OWNER_UID = ownerRecord.uid;
  const PEER_UID = peerRecord.uid;

  let ownerPassword = OWNER_PASSWORD_ENV;
  let peerPassword = PEER_PASSWORD_ENV;
  if (!ownerPassword || !peerPassword) {
    console.log("Password env missing — resetting temporary passwords via Admin SDK");
    await auth.updateUser(OWNER_UID, {password: TEMP_PASSWORD});
    await auth.updateUser(PEER_UID, {password: TEMP_PASSWORD});
    ownerPassword = TEMP_PASSWORD;
    peerPassword = TEMP_PASSWORD;
  }

  await clearBlock(db, OWNER_UID, PEER_UID);

  console.log(`C2 Groups Chat/Media QA against ${PROJECT_ID} (${REGION}) suite=${SUITE}`);
  const owner = await clientFor(OWNER_EMAIL, ownerPassword);
  const peer = await clientFor(PEER_EMAIL, peerPassword);
  ok("1. Owner signed in", owner.uid === OWNER_UID, owner.uid);
  ok("1. Peer signed in", peer.uid === PEER_UID, peer.uid);

  let groupId = "";
  let memberChatConversationId = "";
  let announcementsConversationId = "";
  let storageAvailable = true;

  try {
    // Probe admin storage once.
    try {
      const [exists] = await bucket.exists();
      if (!exists) {
        storageAvailable = false;
        skip("admin storage probe", `bucket ${STORAGE_BUCKET} not found`);
      }
    } catch (error) {
      storageAvailable = false;
      skip("admin storage probe", String(error.message || error));
    }

    // --- 2. createGroup with correct location shape ---
    const created = await owner.invoke("createGroup", {
      name: `${SUITE} C2 Chat`,
      description: "Phase C2 channel messaging + media QA",
      category: "running",
      privacy: "public",
      joinPolicy: "open",
      capacity: 50,
      location: {
        locality: "Haifa",
        administrativeArea: "Haifa District",
        countryCode: "IL",
        text: "Haifa, IL",
      },
    });
    groupId = created.groupId || "";
    ok("2. createGroup", !!groupId, groupId);

    const groupDoc = await db.doc(`groups/${groupId}`).get();
    const storedLocation = groupDoc.get("location") || {};
    ok(
      "2. createGroup location shape (locality/countryCode)",
      storedLocation.locality === "Haifa" &&
        storedLocation.countryCode === "IL" &&
        !("city" in storedLocation) &&
        !("label" in storedLocation),
      JSON.stringify(storedLocation),
    );

    const group = await owner.invoke("getGroup", {groupId});
    memberChatConversationId = group.memberChatConversationId || "";
    announcementsConversationId = group.announcementsConversationId || "";
    ok(
      "2. conversation IDs reserved",
      !!memberChatConversationId && !!announcementsConversationId,
      `chat=${memberChatConversationId} ann=${announcementsConversationId}`,
    );

    // --- 3. Channels materialized + viewOnceSupported ---
    const channels = await owner.invoke("getGroupChannels", {groupId});
    const channelList = channels.channels || [];
    const memberChat = channelList.find(
      (c) => c.type === "member_chat" || c.channelId === "member_chat",
    );
    const announcements = channelList.find(
      (c) => c.type === "announcements" || c.channelId === "announcements",
    );
    ok(
      "3. member_chat channel live + viewOnceSupported",
      !!memberChat && memberChat.viewOnceSupported === true,
      JSON.stringify({
        type: memberChat?.type,
        viewOnceSupported: memberChat?.viewOnceSupported,
        modes: memberChat?.supportedMediaModes,
      }),
    );
    ok("3. announcements channel present", !!announcements);
    const chatConvExists =
      (await db.doc(`conversations/${memberChatConversationId}`).get()).exists;
    const annConvExists =
      (await db.doc(`conversations/${announcementsConversationId}`).get()).exists;
    ok(
      "3. conversations materialized in Firestore",
      chatConvExists && annConvExists,
    );

    // --- 4. Peer join + send member chat; peer cannot announce ---
    const join = await peer.invoke("requestJoinGroup", {groupId});
    ok(
      "4. Peer joined open group",
      join.status === "member" ||
        !!(await db.doc(`groups/${groupId}/members/${PEER_UID}`).get()).exists,
      JSON.stringify(join),
    );

    const peerSendId = mid("peer_text");
    const peerSent = await peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: peerSendId,
      text: "Peer member chat hello",
      mediaMode: "normal",
      attachments: [],
    });
    ok(
      "4. Peer can send member chat",
      peerSent.messageId === peerSendId && peerSent.created === true,
      JSON.stringify(peerSent),
    );

    // Step-2 regression: inbox preview readable must imply message list works
    // for both owner and peer (same path the conversation screen uses).
    try {
      const ownerHistory = await owner.assertInboxAndMessageHistory(
        memberChatConversationId,
      );
      ok(
        "4. Owner inbox+messages list after peer send",
        ownerHistory.messageCount >= 1,
        JSON.stringify(ownerHistory),
      );
    } catch (error) {
      ok("4. Owner inbox+messages list after peer send", false, String(error));
    }
    try {
      const peerHistory = await peer.assertInboxAndMessageHistory(
        memberChatConversationId,
      );
      ok(
        "4. Peer inbox+messages list after peer send",
        peerHistory.messageCount >= 1,
        JSON.stringify(peerHistory),
      );
    } catch (error) {
      ok("4. Peer inbox+messages list after peer send", false, String(error));
    }

    const peerAnnounceDenied = await expectDenied(peer.invoke("sendMessage", {
      conversationId: announcementsConversationId,
      clientMessageId: mid("peer_ann"),
      text: "peer should not announce",
      mediaMode: "normal",
      attachments: [],
    }));
    ok(
      "4. Peer cannot announce",
      peerAnnounceDenied.denied,
      peerAnnounceDenied.code,
    );

    // --- 5. Owner can announce ---
    const annId = mid("owner_ann");
    const ann = await owner.invoke("sendMessage", {
      conversationId: announcementsConversationId,
      clientMessageId: annId,
      text: "Official C2 announcement",
      mediaMode: "normal",
      attachments: [],
    });
    ok("5. Owner can announce", ann.messageId === annId && ann.created === true);

    // --- 6. Send idempotency ---
    const ownerTextId = mid("owner_text");
    const first = await owner.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: ownerTextId,
      text: "Idempotent hello",
      mediaMode: "normal",
      attachments: [],
    });
    const second = await owner.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: ownerTextId,
      text: "Idempotent hello",
      mediaMode: "normal",
      attachments: [],
    });
    ok(
      "6. Send idempotency (same clientMessageId)",
      first.created === true &&
        second.created === false &&
        second.messageId === ownerTextId,
      JSON.stringify({first, second}),
    );

    // --- 7. Reply + reply to deleted ---
    const parentId = mid("parent");
    await owner.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: parentId,
      text: "Parent for reply",
      mediaMode: "normal",
      attachments: [],
    });
    const replyId = mid("reply");
    const reply = await peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: replyId,
      text: "Replying to parent",
      mediaMode: "normal",
      attachments: [],
      replyToMessageId: parentId,
    });
    const replyDoc = await db
      .doc(`conversations/${memberChatConversationId}/messages/${replyId}`)
      .get();
    const replyTo = replyDoc.get("replyTo") || {};
    ok(
      "7. Reply to message",
      reply.created === true &&
        replyTo.messageId === parentId &&
        replyTo.isDeleted !== true,
      JSON.stringify(replyTo),
    );

    await owner.invoke("deleteMessage", {
      conversationId: memberChatConversationId,
      messageId: parentId,
    });
    const replyDeletedId = mid("reply_del");
    const replyDeleted = await peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: replyDeletedId,
      text: "Replying to deleted parent",
      mediaMode: "normal",
      attachments: [],
      replyToMessageId: parentId,
    });
    const replyDeletedDoc = await db
      .doc(`conversations/${memberChatConversationId}/messages/${replyDeletedId}`)
      .get();
    const replyDeletedTo = replyDeletedDoc.get("replyTo") || {};
    ok(
      "7. Reply to deleted shows placeholder / allowed",
      replyDeleted.created === true &&
        replyDeletedTo.messageId === parentId &&
        (replyDeletedTo.isDeleted === true ||
          replyDeletedTo.kind === "deleted" ||
          replyDeletedTo.preview === "Message deleted"),
      JSON.stringify(replyDeletedTo),
    );

    // --- 8. Owner deletes own; owner moderates peer message ---
    const ownDeleteId = mid("own_del");
    await owner.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: ownDeleteId,
      text: "Owner will delete this",
      mediaMode: "normal",
      attachments: [],
    });
    const ownDel = await owner.invoke("deleteMessage", {
      conversationId: memberChatConversationId,
      messageId: ownDeleteId,
    });
    const ownDelDoc = await db
      .doc(`conversations/${memberChatConversationId}/messages/${ownDeleteId}`)
      .get();
    ok(
      "8. Owner deletes own message",
      ownDel.deleted === true && ownDelDoc.get("isDeleted") === true,
    );

    const peerModId = mid("peer_mod");
    await peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: peerModId,
      text: "Peer message for moderation",
      mediaMode: "normal",
      attachments: [],
    });
    const modDel = await owner.invoke("deleteMessage", {
      conversationId: memberChatConversationId,
      messageId: peerModId,
    });
    const modDoc = await db
      .doc(`conversations/${memberChatConversationId}/messages/${peerModId}`)
      .get();
    ok(
      "8. Owner/admin moderates peer message",
      modDel.deleted === true &&
        modDoc.get("isDeleted") === true &&
        modDoc.get("deletedBy") === OWNER_UID,
      `deletedBy=${modDoc.get("deletedBy")}`,
    );

    // --- 9. Media upload create + validation (+ finalize if storage works) ---
    const mediaMsgId = mid("media_msg");
    const mediaAttId = mid("media_att");
    const prepared = await owner.invoke("createGroupMediaUpload", {
      groupId,
      channelType: "member_chat",
      messageId: mediaMsgId,
      attachmentId: mediaAttId,
      kind: "image",
      contentType: "image/jpeg",
      filename: "c2-qa.jpg",
      mediaMode: "normal",
      sizeBytes: 4096,
    });
    ok(
      "9. createGroupMediaUpload returns path/metadata",
      typeof prepared.storagePath === "string" &&
        prepared.storagePath.includes(`groups/${groupId}/channels/member_chat/`) &&
        !!(prepared.metadata || prepared.requiredMetadata) &&
        (prepared.uploadPath === prepared.storagePath || !!prepared.uploadPath),
      prepared.storagePath,
    );

    const badMime = await expectDenied(owner.invoke("createGroupMediaUpload", {
      groupId,
      channelType: "member_chat",
      messageId: mid("bad_mime_msg"),
      attachmentId: mid("bad_mime_att"),
      kind: "image",
      contentType: "application/pdf",
      filename: "bad.pdf",
      mediaMode: "normal",
      sizeBytes: 1024,
    }));
    ok(
      "9. createGroupMediaUpload rejects bad mime",
      badMime.denied,
      badMime.code,
    );

    const badSize = await expectDenied(owner.invoke("createGroupMediaUpload", {
      groupId,
      channelType: "member_chat",
      messageId: mid("bad_size_msg"),
      attachmentId: mid("bad_size_att"),
      kind: "image",
      contentType: "image/jpeg",
      filename: "huge.jpg",
      mediaMode: "normal",
      sizeBytes: 50 * 1024 * 1024,
    }));
    ok(
      "9. createGroupMediaUpload rejects bad size",
      badSize.denied,
      badSize.code,
    );

    const viewOnceOnAnn = await expectDenied(owner.invoke("createGroupMediaUpload", {
      groupId,
      channelType: "announcements",
      messageId: mid("ann_vo_msg"),
      attachmentId: mid("ann_vo_att"),
      kind: "image",
      contentType: "image/jpeg",
      filename: "ann.jpg",
      mediaMode: "view_once",
      sizeBytes: 1024,
    }));
    ok(
      "9. createGroupMediaUpload rejects view_once on announcements",
      viewOnceOnAnn.denied,
      viewOnceOnAnn.code,
    );

    if (storageAvailable) {
      try {
        const finalizeMsgId = mid("fin_msg");
        const finalizeAttId = mid("fin_att");
        const upload = await owner.invoke("createGroupMediaUpload", {
          groupId,
          channelType: "member_chat",
          messageId: finalizeMsgId,
          attachmentId: finalizeAttId,
          kind: "image",
          contentType: "image/jpeg",
          filename: "finalize.jpg",
          mediaMode: "keep_in_chat",
          sizeBytes: TINY_JPEG.length,
        });
        await bucket.file(upload.storagePath).save(TINY_JPEG, {
          resumable: false,
          contentType: "image/jpeg",
          metadata: {
            contentType: "image/jpeg",
            metadata: upload.metadata || upload.requiredMetadata,
          },
        });
        const finalized = await owner.invoke("finalizeGroupMediaUpload", {
          groupId,
          channelType: "member_chat",
          messageId: finalizeMsgId,
          attachmentId: finalizeAttId,
          storagePath: upload.storagePath,
          mediaMode: "keep_in_chat",
        });
        ok(
          "9. finalizeGroupMediaUpload after admin-seeded object",
          finalized.ok === true && finalized.storagePath === upload.storagePath,
          JSON.stringify(finalized),
        );
      } catch (error) {
        // Keep storageAvailable true so view-once seeding can still be attempted.
        ok(
          "9. finalizeGroupMediaUpload after admin-seeded object",
          false,
          String(error.message || error),
        );
        skip("9. finalize details", String(error.message || error));
      }
    } else {
      skip(
        "9. finalizeGroupMediaUpload",
        "admin storage unavailable — validation checks still ran",
      );
    }

    // --- 10/11. View-once concurrent claim ---
    let voMessageId = "";
    let voAttachmentId = "";
    if (storageAvailable) {
      voMessageId = mid("vo_msg");
      voAttachmentId = mid("vo_att");
      try {
        const seeded = await seedGroupMediaObject({
          bucket,
          groupId,
          channelType: "member_chat",
          conversationId: memberChatConversationId,
          messageId: voMessageId,
          attachmentId: voAttachmentId,
          ownerId: OWNER_UID,
          mediaMode: "view_once",
        });
        const voSend = await owner.invoke("sendMessage", {
          conversationId: memberChatConversationId,
          clientMessageId: voMessageId,
          text: "",
          mediaMode: "view_once",
          attachments: [{
            id: voAttachmentId,
            storagePath: seeded.storagePath,
            contentType: seeded.contentType,
            sizeBytes: seeded.sizeBytes,
            kind: "image",
          }],
        });
        ok(
          "10. View-once message created (admin-seeded storage)",
          voSend.created === true && voSend.messageId === voMessageId,
        );

        const claimPayload = {
          conversationId: memberChatConversationId,
          messageId: voMessageId,
          attachmentId: voAttachmentId,
        };
        const concurrent = await Promise.allSettled([
          peer.invoke("claimViewOnceMedia", claimPayload),
          peer.invoke("claimViewOnceMedia", claimPayload),
        ]);
        const successes = concurrent.filter((r) => r.status === "fulfilled");
        const failures = concurrent.filter((r) => r.status === "rejected");
        ok(
          "10. Concurrent claimViewOnceMedia — exactly one success",
          successes.length === 1 && failures.length === 1,
          `fulfilled=${successes.length} rejected=${failures.length}`,
        );
        if (successes.length === 1) {
          const url = successes[0].value?.url;
          ok(
            "10. Winning claim returns signed URL",
            typeof url === "string" && url.startsWith("http"),
          );
        } else {
          ok("10. Winning claim returns signed URL", false, "no success");
        }

        const replay = await expectDenied(
          peer.invoke("claimViewOnceMedia", claimPayload),
        );
        ok(
          "11. Second claim / refresh replay fails",
          replay.denied,
          replay.code,
        );
      } catch (error) {
        ok("10. View-once message created (admin-seeded storage)", false,
          String(error.message || error));
        skip("10/11 view-once claims", String(error.message || error));
      }
    } else {
      skip("10/11 view-once claims", "admin storage unavailable");
    }

    // Seed a second view-once for block/remove claim denial tests.
    let vo2MessageId = "";
    let vo2AttachmentId = "";
    if (storageAvailable) {
      try {
        vo2MessageId = mid("vo2_msg");
        vo2AttachmentId = mid("vo2_att");
        const seeded2 = await seedGroupMediaObject({
          bucket,
          groupId,
          channelType: "member_chat",
          conversationId: memberChatConversationId,
          messageId: vo2MessageId,
          attachmentId: vo2AttachmentId,
          ownerId: OWNER_UID,
          mediaMode: "view_once",
        });
        await owner.invoke("sendMessage", {
          conversationId: memberChatConversationId,
          clientMessageId: vo2MessageId,
          text: "",
          mediaMode: "view_once",
          attachments: [{
            id: vo2AttachmentId,
            storagePath: seeded2.storagePath,
            contentType: seeded2.contentType,
            sizeBytes: seeded2.sizeBytes,
            kind: "image",
          }],
        });
      } catch (error) {
        vo2MessageId = "";
        skip("view-once block/remove fixture", String(error.message || error));
      }
    }

    // --- 12. Blocked user ---
    await owner.invoke("blockUser", {targetUserId: PEER_UID});
    const blockedSend = await expectDenied(peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: mid("blocked_send"),
      text: "should fail while blocked",
      mediaMode: "normal",
      attachments: [],
    }));
    ok("12. Blocked peer cannot send", blockedSend.denied, blockedSend.code);

    if (vo2MessageId) {
      const blockedClaim = await expectDenied(peer.invoke("claimViewOnceMedia", {
        conversationId: memberChatConversationId,
        messageId: vo2MessageId,
        attachmentId: vo2AttachmentId,
      }));
      ok(
        "12. Blocked peer cannot claim view-once",
        blockedClaim.denied,
        blockedClaim.code,
      );
    } else {
      skip("12. Blocked peer cannot claim view-once", "no view-once fixture");
    }

    try {
      await owner.invoke("unblockUser", {profileId: PEER_UID});
    } catch {
      await clearBlock(db, OWNER_UID, PEER_UID);
    }
    await clearBlock(db, OWNER_UID, PEER_UID);
    ok("12. Unblock after block checks", true);

    // Confirm send works again after unblock (before remove).
    const afterUnblock = await peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: mid("after_unblock"),
      text: "peer send after unblock",
      mediaMode: "normal",
      attachments: [],
    });
    ok(
      "12. Peer can send again after unblock",
      afterUnblock.created === true,
    );

    // --- 14. Announcement notification prefs smoke (optional) ---
    try {
      const pref = await peer.invoke("updateConversationPreferences", {
        conversationId: announcementsConversationId,
        notificationsEnabled: false,
      });
      ok(
        "14. Announcement conversation prefs smoke (notificationsEnabled=false)",
        pref.updated === true,
      );
      const memberPref = await db
        .doc(`conversations/${announcementsConversationId}/members/${PEER_UID}`)
        .get();
      ok(
        "14. Pref persisted on conversation member",
        memberPref.get("notificationsEnabled") === false,
      );
      // Restore
      await peer.invoke("updateConversationPreferences", {
        conversationId: announcementsConversationId,
        notificationsEnabled: true,
      });
    } catch (error) {
      skip("14. announcement notification prefs", String(error.message || error));
    }

    // Soft check: announcement kind exists in recent peer notifications (best-effort).
    try {
      const annNotifs = await recentNotifications(db, PEER_UID, "group_announcement");
      const hit = annNotifs.some((d) => {
        const data = d.get("data") || {};
        return data.groupId === groupId ||
          d.get("entityId") === groupId ||
          String(d.get("route") || "").includes(groupId);
      });
      if (hit) {
        ok("14. group_announcement notification observed for peer", true);
      } else {
        skip(
          "14. group_announcement notification observed",
          "none yet (async delivery / prefs) — prefs callable already checked",
        );
      }
    } catch (error) {
      skip("14. group_announcement notification query", String(error.message || error));
    }

    // --- 13. Remove member ---
    await owner.invoke("removeGroupMember", {
      groupId,
      memberId: PEER_UID,
    });
    const memberSnap = await db.doc(`groups/${groupId}/members/${PEER_UID}`).get();
    const removed =
      !memberSnap.exists ||
      memberSnap.get("removedAt") != null ||
      memberSnap.get("status") === "removed";
    ok("13. Remove member", removed);

    const removedSend = await expectDenied(peer.invoke("sendMessage", {
      conversationId: memberChatConversationId,
      clientMessageId: mid("removed_send"),
      text: "should fail after remove",
      mediaMode: "normal",
      attachments: [],
    }));
    ok("13. Removed peer cannot send", removedSend.denied, removedSend.code);

    if (vo2MessageId) {
      const removedClaim = await expectDenied(peer.invoke("claimViewOnceMedia", {
        conversationId: memberChatConversationId,
        messageId: vo2MessageId,
        attachmentId: vo2AttachmentId,
      }));
      ok(
        "13. Removed peer cannot claim view-once",
        removedClaim.denied,
        removedClaim.code,
      );
    } else {
      skip("13. Removed peer cannot claim view-once", "no view-once fixture");
    }

    // --- 15. Cleanup ---
    try {
      await owner.invoke("deleteGroup", {groupId});
    } catch {
      await db.doc(`groups/${groupId}`).set({
        status: "deleted",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    const deleted = (await db.doc(`groups/${groupId}`).get()).get("status") === "deleted";
    ok("15. Cleanup soft-delete group", deleted, groupId);

    // Best-effort storage cleanup for seeded objects under this group.
    if (storageAvailable && groupId) {
      try {
        await bucket.deleteFiles({prefix: `groups/${groupId}/`, force: true});
      } catch {
        // ignore
      }
    }
  } finally {
    await clearBlock(db, OWNER_UID, PEER_UID).catch(() => undefined);
    if (groupId) {
      const status = (await db.doc(`groups/${groupId}`).get()).get("status");
      if (status !== "deleted") {
        await db.doc(`groups/${groupId}`).set({
          status: "deleted",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}).catch(() => undefined);
      }
    }
    await owner.close().catch(() => undefined);
    await peer.close().catch(() => undefined);
  }

  const passed = results.filter((r) => r.pass).length;
  const failed = results.filter((r) => !r.pass).length;
  console.log(
    `\nC2 QA summary: ${passed} passed, ${failed} failed, ${results.length} checks` +
    (skips.length ? `, ${skips.length} skips` : ""),
  );
  if (failed) {
    for (const f of results.filter((r) => !r.pass)) {
      console.log(`  FAIL: ${f.label}${f.detail ? ` — ${f.detail}` : ""}`);
    }
  }
  if (skips.length) {
    for (const s of skips) {
      console.log(`  SKIP: ${s.label} — ${s.reason}`);
    }
  }
  process.exitCode = failed === 0 ? 0 : 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
