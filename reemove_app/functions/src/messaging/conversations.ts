import {getDatabase} from "firebase-admin/database";
import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentData,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {
  activeProfileSnapshot,
  assertConversationMember,
  assertGroupAdministrator,
  assertUsersCanMessage,
  requireUid,
} from "./conversationAccess";
import {directConversationId, maximumGroupMembers} from "./messagingPolicy";
import {
  parseConversationRequest,
  parseCreateGroupRequest,
  parseDirectRequest,
  parsePreferencesRequest,
  parseUpdateGroupRequest,
} from "./requestData";

function memberData(
  snapshot: Record<string, unknown>,
  role: "owner" | "admin" | "member",
  now: Timestamp,
): Record<string, unknown> {
  return {
    userId: snapshot.id,
    userSnapshot: snapshot,
    role,
    joinedAt: now,
    lastReadAt: now,
    unreadCount: 0,
    notificationsEnabled: true,
    mutedUntil: null,
    archivedAt: null,
    removedAt: null,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

function inboxData(options: {
  conversationId: string;
  type: "direct" | "group";
  title: string;
  avatarUrl?: string;
  memberSnapshots: Record<string, unknown>[];
  now: Timestamp;
}): Record<string, unknown> {
  return {
    conversationId: options.conversationId,
    type: options.type,
    title: options.title,
    ...(options.avatarUrl ? {avatarUrl: options.avatarUrl} : {}),
    memberSnapshots: options.memberSnapshots.slice(0, 12),
    unreadCount: 0,
    notificationsEnabled: true,
    mutedUntil: null,
    archivedAt: null,
    removedAt: null,
    isArchived: false,
    createdAt: options.now,
    updatedAt: options.now,
    schemaVersion: currentSchemaVersion,
  };
}

function profileDisplayName(snapshot: Record<string, unknown>): string {
  const value = snapshot.displayName;
  return typeof value === "string" && value.trim() ? value.trim() : "Athlete";
}

function profileAvatar(snapshot: Record<string, unknown>): string | undefined {
  return typeof snapshot.avatarUrl === "string" && snapshot.avatarUrl ?
    snapshot.avatarUrl : undefined;
}

/** RTDB ACL is best-effort; never block callable completion on hung sockets. */
const realtimeAclTimeoutMs = 2_500;

async function withRealtimeAclTimeout<T>(operation: Promise<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      operation,
      new Promise<T>((_resolve, reject) => {
        timer = setTimeout(
          () => reject(new Error("realtime_acl_timeout")),
          realtimeAclTimeoutMs,
        );
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

export async function setRealtimeAcl(
  conversationId: string,
  memberIds: Iterable<string>,
): Promise<void> {
  try {
    const values: Record<string, boolean> = {};
    for (const memberId of memberIds) values[memberId] = true;
    await withRealtimeAclTimeout(
      getDatabase().ref(`messaging_acl/${conversationId}`).set(values),
    );
  } catch {
    // Conversation docs are authoritative; RTDB ACL is best-effort (emulator/network).
  }
}

export async function updateRealtimeAcl(
  conversationId: string,
  added: Iterable<string>,
  removed: Iterable<string>,
): Promise<void> {
  try {
    const values: Record<string, boolean | null> = {};
    for (const memberId of added) {
      values[`messaging_acl/${conversationId}/${memberId}`] = true;
    }
    for (const memberId of removed) {
      values[`messaging_acl/${conversationId}/${memberId}`] = null;
      values[`presence/${conversationId}/${memberId}`] = null;
      values[`typing/${conversationId}/${memberId}`] = null;
    }
    if (Object.keys(values).length > 0) {
      await withRealtimeAclTimeout(getDatabase().ref().update(values));
    }
  } catch {
    // Conversation docs are authoritative; RTDB ACL is best-effort (emulator/network).
  }
}

export const createDirectConversation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const {targetUserId} = parseDirectRequest(request.data);
  await consumeRateLimit(uid, {
    key: "create_direct_conversation",
    maxAttempts: 80,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  await assertUsersCanMessage(database, uid, targetUserId);
  return ensureDirectConversationBetween(database, uid, targetUserId);
});

/** Shared by createDirectConversation and message-request accept. */
export async function ensureDirectConversationBetween(
  database: ReturnType<typeof getFirestore>,
  uid: string,
  targetUserId: string,
): Promise<{conversationId: string; existing: boolean}> {
  const [creator, target] = await Promise.all([
    activeProfileSnapshot(database, uid),
    activeProfileSnapshot(database, targetUserId),
  ]);
  const conversationId = directConversationId(uid, targetUserId);
  const conversationRef = database.collection(collections.conversations).doc(conversationId);
  const existing = await conversationRef.get();
  if (existing.exists) {
    const existingMember = await conversationRef.collection("members").doc(uid).get();
    if (!existingMember.exists || existingMember.get("removedAt")) {
      throw new HttpsError("failed-precondition", "This conversation is unavailable.");
    }
    await setRealtimeAcl(conversationId, [uid, targetUserId]);
    return {conversationId, existing: true};
  }

  const now = Timestamp.now();
  const members = [creator, target];
  const batch = database.batch();
  batch.create(conversationRef, {
    type: "direct",
    directKey: [uid, targetUserId].sort().join("--"),
    title: "",
    createdBy: uid,
    memberCount: 2,
    moderationState: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  batch.create(
    conversationRef.collection("members").doc(uid),
    memberData(creator, "member", now),
  );
  batch.create(
    conversationRef.collection("members").doc(targetUserId),
    memberData(target, "member", now),
  );
  batch.set(
    database.doc(`users/${uid}/conversation_inbox/${conversationId}`),
    inboxData({
      conversationId,
      type: "direct",
      title: profileDisplayName(target),
      avatarUrl: profileAvatar(target),
      memberSnapshots: members,
      now,
    }),
  );
  batch.set(
    database.doc(`users/${targetUserId}/conversation_inbox/${conversationId}`),
    inboxData({
      conversationId,
      type: "direct",
      title: profileDisplayName(creator),
      avatarUrl: profileAvatar(creator),
      memberSnapshots: members,
      now,
    }),
  );
  await batch.commit();
  await setRealtimeAcl(conversationId, [uid, targetUserId]);
  await writeAuditEvent({
    action: "messaging.direct_created",
    actorId: uid,
    targetType: "conversation",
    targetId: conversationId,
    metadata: {targetUserId},
  });
  return {conversationId, existing: false};
}

export const createGroupConversation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseCreateGroupRequest(request.data);
  const memberIds = [...new Set([uid, ...parsed.memberIds.filter((item) => item !== uid)])];
  if (memberIds.length < 3) {
    throw new HttpsError("invalid-argument", "Choose at least two people for a group.");
  }
  if (memberIds.length > maximumGroupMembers) {
    throw new HttpsError("invalid-argument", "This group contains too many members.");
  }
  await consumeRateLimit(uid, {
    key: "create_group_conversation",
    maxAttempts: 20,
    windowSeconds: 24 * 60 * 60,
  });

  const database = getFirestore();
  const profiles = await Promise.all(
    memberIds.map((memberId) => activeProfileSnapshot(database, memberId)),
  );
  for (const memberId of memberIds) {
    if (memberId !== uid) await assertUsersCanMessage(database, uid, memberId);
  }
  const now = Timestamp.now();
  const conversationRef = database.collection(collections.conversations).doc();
  const batch = database.batch();
  batch.create(conversationRef, {
    type: "group",
    title: parsed.title,
    createdBy: uid,
    memberCount: memberIds.length,
    moderationState: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  for (let index = 0; index < memberIds.length; index += 1) {
    const memberId = memberIds[index];
    const snapshot = profiles[index];
    batch.create(
      conversationRef.collection("members").doc(memberId),
      memberData(snapshot, memberId === uid ? "owner" : "member", now),
    );
    batch.set(
      database.doc(`users/${memberId}/conversation_inbox/${conversationRef.id}`),
      inboxData({
        conversationId: conversationRef.id,
        type: "group",
        title: parsed.title,
        memberSnapshots: profiles,
        now,
      }),
    );
  }
  await batch.commit();
  await setRealtimeAcl(conversationRef.id, memberIds);
  await writeAuditEvent({
    actorId: uid,
    action: "messaging.group_created",
    targetType: "conversation",
    targetId: conversationRef.id,
    metadata: {memberCount: memberIds.length},
  });
  return {conversationId: conversationRef.id};
});

export const updateGroupConversation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseUpdateGroupRequest(request.data);
  const access = await assertConversationMember(parsed.conversationId, uid);
  assertGroupAdministrator(access);
  await consumeRateLimit(uid, {
    key: "update_group_conversation",
    maxAttempts: 80,
    windowSeconds: 60 * 60,
  });

  const database = access.database;
  const conversationRef = access.conversation.ref;
  const memberQuery = await conversationRef.collection("members")
    .where("removedAt", "==", null).limit(maximumGroupMembers).get();
  const current = new Map<string, QueryDocumentSnapshot<DocumentData>>(
    memberQuery.docs.map((item) => [item.id, item]),
  );
  const additions = parsed.addMemberIds.filter((item) => !current.has(item));
  const removals = parsed.removeMemberIds.filter((item) => current.has(item));
  const ownerRemoval = removals.find((item) => current.get(item)?.get("role") === "owner");
  if (ownerRemoval) {
    throw new HttpsError("failed-precondition", "The group owner cannot be removed.");
  }
  if (current.size + additions.length - removals.length > maximumGroupMembers) {
    throw new HttpsError("invalid-argument", "This group contains too many members.");
  }
  for (const memberId of additions) await assertUsersCanMessage(database, uid, memberId);
  const additionProfiles = await Promise.all(
    additions.map((memberId) => activeProfileSnapshot(database, memberId)),
  );

  if (parsed.avatarStoragePath) {
    const expectedPrefix = `conversation_groups/${parsed.conversationId}/${uid}/`;
    if (!parsed.avatarStoragePath.startsWith(expectedPrefix)) {
      throw new HttpsError("invalid-argument", "Group image path is invalid.");
    }
    const [metadata] = await getStorage().bucket().file(parsed.avatarStoragePath).getMetadata();
    if (metadata.metadata?.ownerId !== uid ||
        metadata.metadata?.conversationId !== parsed.conversationId) {
      throw new HttpsError("failed-precondition", "Group image ownership could not be verified.");
    }
  }

  const finalSnapshots = new Map<string, Record<string, unknown>>();
  for (const [memberId, document] of current.entries()) {
    if (!removals.includes(memberId)) {
      finalSnapshots.set(memberId, document.get("userSnapshot") as Record<string, unknown>);
    }
  }
  for (let index = 0; index < additions.length; index += 1) {
    finalSnapshots.set(additions[index], additionProfiles[index]);
  }
  const title = parsed.title ?? String(access.conversation.get("title") ?? "Group");
  const avatarUrl = parsed.avatarUrl ??
    (access.conversation.get("avatarUrl") ? String(access.conversation.get("avatarUrl")) : undefined);
  const now = Timestamp.now();
  const batch = database.batch();
  batch.update(conversationRef, {
    title,
    ...(parsed.avatarUrl ? {avatarUrl: parsed.avatarUrl} : {}),
    ...(parsed.avatarStoragePath ? {avatarStoragePath: parsed.avatarStoragePath} : {}),
    memberCount: finalSnapshots.size,
    updatedAt: now,
  });

  for (let index = 0; index < additions.length; index += 1) {
    const memberId = additions[index];
    batch.set(
      conversationRef.collection("members").doc(memberId),
      memberData(additionProfiles[index], "member", now),
    );
  }
  for (const memberId of removals) {
    batch.update(conversationRef.collection("members").doc(memberId), {
      removedAt: now,
      updatedAt: now,
      unreadCount: 0,
    });
    batch.delete(database.doc(`users/${memberId}/conversation_inbox/${parsed.conversationId}`));
  }
  const memberSnapshots = [...finalSnapshots.values()].slice(0, 12);
  for (const memberId of finalSnapshots.keys()) {
    const inboxRef = database.doc(`users/${memberId}/conversation_inbox/${parsed.conversationId}`);
    if (additions.includes(memberId)) {
      batch.set(inboxRef, inboxData({
        conversationId: parsed.conversationId,
        type: "group",
        title,
        avatarUrl,
        memberSnapshots,
        now,
      }));
    } else {
      batch.set(inboxRef, {
        title,
        ...(avatarUrl ? {avatarUrl} : {avatarUrl: FieldValue.delete()}),
        memberSnapshots,
        updatedAt: now,
      }, {merge: true});
    }
  }
  await batch.commit();
  await updateRealtimeAcl(parsed.conversationId, additions, removals);
  await writeAuditEvent({
    actorId: uid,
    action: "messaging.group_updated",
    targetType: "conversation",
    targetId: parsed.conversationId,
    metadata: {added: additions.length, removed: removals.length},
  });
  return {updated: true};
});

export const leaveConversation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const {conversationId} = parseConversationRequest(request.data);
  const access = await assertConversationMember(conversationId, uid);
  const now = Timestamp.now();
  const inboxRef = access.database.doc(`users/${uid}/conversation_inbox/${conversationId}`);

  if (access.conversation.get("type") === "direct") {
    const batch = access.database.batch();
    batch.set(inboxRef, {isArchived: true, archivedAt: now, updatedAt: now}, {merge: true});
    batch.set(access.member.ref, {archivedAt: now, updatedAt: now}, {merge: true});
    await batch.commit();
    return {archived: true};
  }

  if (access.member.get("role") === "owner" &&
      Number(access.conversation.get("memberCount") ?? 0) > 1) {
    throw new HttpsError(
      "failed-precondition",
      "Transfer group ownership before leaving this group.",
    );
  }
  const batch = access.database.batch();
  batch.update(access.member.ref, {removedAt: now, updatedAt: now, unreadCount: 0});
  batch.update(access.conversation.ref, {
    memberCount: Math.max(0, Number(access.conversation.get("memberCount") ?? 1) - 1),
    updatedAt: now,
  });
  batch.delete(inboxRef);
  await batch.commit();
  await updateRealtimeAcl(conversationId, [], [uid]);
  await writeAuditEvent({
    actorId: uid,
    action: "messaging.group_left",
    targetType: "conversation",
    targetId: conversationId,
  });
  return {left: true};
});

export const updateConversationPreferences = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const parsed = parsePreferencesRequest(request.data);
    const access = await assertConversationMember(parsed.conversationId, uid);
    const now = Timestamp.now();
    const changes: Record<string, unknown> = {updatedAt: now};
    if (parsed.mutedUntil) changes.mutedUntil = Timestamp.fromDate(parsed.mutedUntil);
    if (parsed.notificationsEnabled !== undefined) {
      changes.notificationsEnabled = parsed.notificationsEnabled;
      if (parsed.notificationsEnabled) changes.mutedUntil = FieldValue.delete();
    }
    if (parsed.archived !== undefined) {
      changes.isArchived = parsed.archived;
      changes.archivedAt = parsed.archived ? now : FieldValue.delete();
    }
    const batch = access.database.batch();
    batch.set(access.member.ref, changes, {merge: true});
    batch.set(
      access.database.doc(`users/${uid}/conversation_inbox/${parsed.conversationId}`),
      changes,
      {merge: true},
    );
    await batch.commit();
    return {updated: true};
  },
);

