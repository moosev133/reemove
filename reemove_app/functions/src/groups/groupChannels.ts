import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
  type WriteBatch,
} from "firebase-admin/firestore";

import {collections, currentSchemaVersion} from "../core/schema";
import {
  setRealtimeAcl,
  updateRealtimeAcl,
} from "../messaging/conversations";
import {activeProfileSnapshot} from "../messaging/conversationAccess";
import {
  activeMemberRole,
  groupRef,
  memberRef,
} from "./groupsAccess";
import {
  groupChannelContracts,
  type GroupChannelType,
  type GroupMemberRole,
} from "./groupsPolicy";

/** Stay under Firestore's 500-op batch limit with headroom. */
export const channelSyncBatchSize = 400;

export const sportsGroupConversationSource = "sports_group";

type ChannelBinding = {
  type: GroupChannelType;
  conversationId: string;
};

function conversationMemberData(
  snapshot: Record<string, unknown>,
  role: GroupMemberRole,
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

function conversationInboxData(options: {
  conversationId: string;
  title: string;
  groupId: string;
  channelType: GroupChannelType;
  now: Timestamp;
  memberSnapshots?: Record<string, unknown>[];
}): Record<string, unknown> {
  return {
    conversationId: options.conversationId,
    type: "group",
    source: sportsGroupConversationSource,
    groupId: options.groupId,
    channelType: options.channelType,
    title: options.title,
    memberSnapshots: (options.memberSnapshots ?? []).slice(0, 12),
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

function channelTitle(groupName: string, channelType: GroupChannelType): string {
  if (channelType === "announcements") {
    return `${groupName} Announcements`;
  }
  return groupName;
}

function conversationDoc(options: {
  groupId: string;
  channelType: GroupChannelType;
  title: string;
  createdBy: string;
  memberCount: number;
  now: Timestamp;
}): Record<string, unknown> {
  return {
    type: "group",
    source: sportsGroupConversationSource,
    groupId: options.groupId,
    channelType: options.channelType,
    title: options.title,
    createdBy: options.createdBy,
    memberCount: options.memberCount,
    moderationState: "active",
    createdAt: options.now,
    updatedAt: options.now,
    schemaVersion: currentSchemaVersion,
  };
}

export async function commitBatchedOps(
  database: Firestore,
  applyOps: Array<(batch: WriteBatch) => void>,
): Promise<void> {
  for (let index = 0; index < applyOps.length; index += channelSyncBatchSize) {
    const batch = database.batch();
    const slice = applyOps.slice(index, index + channelSyncBatchSize);
    for (const apply of slice) apply(batch);
    await batch.commit();
  }
}

function channelBindingsFromGroup(group: DocumentSnapshot): ChannelBinding[] {
  const memberChatId = String(group.get("memberChatConversationId") ?? "");
  const announcementsId = String(group.get("announcementsConversationId") ?? "");
  const bindings: ChannelBinding[] = [];
  if (memberChatId) {
    bindings.push({type: "member_chat", conversationId: memberChatId});
  }
  if (announcementsId) {
    bindings.push({type: "announcements", conversationId: announcementsId});
  }
  return bindings;
}

async function loadChannelBindings(
  database: Firestore,
  groupId: string,
): Promise<ChannelBinding[]> {
  const channels = await groupRef(database, groupId)
    .collection("channels")
    .limit(10)
    .get();
  if (channels.empty) {
    const group = await groupRef(database, groupId).get();
    return channelBindingsFromGroup(group);
  }
  return channels.docs
    .map((doc) => {
      const type = String(doc.get("type") ?? doc.id) as GroupChannelType;
      const conversationId = String(doc.get("conversationId") ?? "");
      if (
        (type !== "member_chat" && type !== "announcements") ||
        !conversationId
      ) {
        return null;
      }
      return {type, conversationId};
    })
    .filter((item): item is ChannelBinding => item !== null);
}

/**
 * Materialize real conversation docs + owner membership for reserved channel IDs.
 * Used by createGroup (and ensure for C1 groups missing conversation docs).
 */
export async function materializeGroupChannelConversations(options: {
  database?: Firestore;
  groupId: string;
  groupName: string;
  ownerId: string;
  ownerProfile: Record<string, unknown>;
  memberChatConversationId: string;
  announcementsConversationId: string;
  now?: Timestamp;
}): Promise<void> {
  const database = options.database ?? getFirestore();
  const now = options.now ?? Timestamp.now();
  const bindings: ChannelBinding[] = [
    {type: "member_chat", conversationId: options.memberChatConversationId},
    {
      type: "announcements",
      conversationId: options.announcementsConversationId,
    },
  ];

  const batch = database.batch();
  for (const binding of bindings) {
    const conversationRef = database
      .collection(collections.conversations)
      .doc(binding.conversationId);
    const title = channelTitle(options.groupName, binding.type);
    batch.set(
      conversationRef,
      conversationDoc({
        groupId: options.groupId,
        channelType: binding.type,
        title,
        createdBy: options.ownerId,
        memberCount: 1,
        now,
      }),
      {merge: true},
    );
    batch.set(
      conversationRef.collection("members").doc(options.ownerId),
      conversationMemberData(options.ownerProfile, "owner", now),
      {merge: true},
    );
    batch.set(
      database.doc(
        `users/${options.ownerId}/conversation_inbox/${binding.conversationId}`,
      ),
      conversationInboxData({
        conversationId: binding.conversationId,
        title,
        groupId: options.groupId,
        channelType: binding.type,
        now,
        memberSnapshots: [options.ownerProfile],
      }),
      {merge: true},
    );
    batch.set(
      groupRef(database, options.groupId).collection("channels").doc(binding.type),
      {
        type: binding.type,
        conversationId: binding.conversationId,
        supportedMediaModes: groupChannelContracts()
          .find((item) => item.type === binding.type)?.supportedMediaModes ?? [],
        publishRoles: groupChannelContracts()
          .find((item) => item.type === binding.type)?.publishRoles ?? [],
        readRoles: groupChannelContracts()
          .find((item) => item.type === binding.type)?.readRoles ?? [],
        phase: "c2_live",
        updatedAt: now,
        createdAt: now,
        schemaVersion: currentSchemaVersion,
      },
      {merge: true},
    );
  }
  await batch.commit();

  await Promise.all(bindings.map((binding) =>
    setRealtimeAcl(binding.conversationId, [options.ownerId]),
  ));
}

export async function addUserToGroupChannels(options: {
  database?: Firestore;
  groupId: string;
  uid: string;
  role?: GroupMemberRole;
  profile?: Record<string, unknown>;
}): Promise<void> {
  const database = options.database ?? getFirestore();
  const group = await groupRef(database, options.groupId).get();
  if (!group.exists) return;
  const bindings = await loadChannelBindings(database, options.groupId);
  if (bindings.length === 0) return;

  const role = options.role ??
    activeMemberRole(await memberRef(database, options.groupId, options.uid).get()) ??
    "member";
  const profile = options.profile ??
    await activeProfileSnapshot(database, options.uid);
  const now = Timestamp.now();
  const groupName = String(group.get("name") ?? "Group");

  const ops: Array<(batch: WriteBatch) => void> = [];
  for (const binding of bindings) {
    const conversationRef = database
      .collection(collections.conversations)
      .doc(binding.conversationId);
    const title = channelTitle(groupName, binding.type);
    ops.push((batch) => {
      batch.set(
        conversationRef.collection("members").doc(options.uid),
        conversationMemberData(profile, role, now),
        {merge: true},
      );
      batch.set(
        database.doc(
          `users/${options.uid}/conversation_inbox/${binding.conversationId}`,
        ),
        conversationInboxData({
          conversationId: binding.conversationId,
          title,
          groupId: options.groupId,
          channelType: binding.type,
          now,
          memberSnapshots: [profile],
        }),
        {merge: true},
      );
      batch.set(
        conversationRef,
        {
          memberCount: FieldValue.increment(1),
          updatedAt: now,
        },
        {merge: true},
      );
    });
  }
  await commitBatchedOps(database, ops);
  await Promise.all(bindings.map((binding) =>
    updateRealtimeAcl(binding.conversationId, [options.uid], []),
  ));
}

export async function removeUserFromGroupChannels(options: {
  database?: Firestore;
  groupId: string;
  uid: string;
}): Promise<void> {
  const database = options.database ?? getFirestore();
  const bindings = await loadChannelBindings(database, options.groupId);
  if (bindings.length === 0) return;
  const now = Timestamp.now();
  const ops: Array<(batch: WriteBatch) => void> = [];
  for (const binding of bindings) {
    const conversationRef = database
      .collection(collections.conversations)
      .doc(binding.conversationId);
    ops.push((batch) => {
      batch.set(
        conversationRef.collection("members").doc(options.uid),
        {
          removedAt: now,
          updatedAt: now,
          unreadCount: 0,
        },
        {merge: true},
      );
      batch.delete(
        database.doc(
          `users/${options.uid}/conversation_inbox/${binding.conversationId}`,
        ),
      );
      batch.set(
        conversationRef,
        {
          memberCount: FieldValue.increment(-1),
          updatedAt: now,
        },
        {merge: true},
      );
    });
  }
  await commitBatchedOps(database, ops);
  await Promise.all(bindings.map((binding) =>
    updateRealtimeAcl(binding.conversationId, [], [options.uid]),
  ));
}

export async function syncGroupChannelRoles(options: {
  database?: Firestore;
  groupId: string;
  uid: string;
  role: GroupMemberRole;
}): Promise<void> {
  const database = options.database ?? getFirestore();
  const bindings = await loadChannelBindings(database, options.groupId);
  if (bindings.length === 0) return;
  const now = Timestamp.now();
  const ops: Array<(batch: WriteBatch) => void> = [];
  for (const binding of bindings) {
    ops.push((batch) => {
      batch.set(
        database
          .collection(collections.conversations)
          .doc(binding.conversationId)
          .collection("members")
          .doc(options.uid),
        {role: options.role, updatedAt: now},
        {merge: true},
      );
    });
  }
  await commitBatchedOps(database, ops);
}

/**
 * Lazy ensure for C1 groups that have reserved conversation IDs / channel
 * contracts but no live conversation docs. Does not require apply:true backfill.
 */
export async function ensureGroupChannelsMaterialized(
  groupId: string,
  database: Firestore = getFirestore(),
): Promise<ChannelBinding[]> {
  const group = await groupRef(database, groupId).get();
  if (!group.exists) return [];

  let bindings = channelBindingsFromGroup(group);
  const now = Timestamp.now();
  const contracts = groupChannelContracts();
  const groupName = String(group.get("name") ?? "Group");
  const ownerId = String(group.get("ownerId") ?? "");

  if (bindings.length < 2) {
    const memberChatId = bindings.find((b) => b.type === "member_chat")
      ?.conversationId ??
      database.collection(collections.conversations).doc().id;
    const announcementsId = bindings.find((b) => b.type === "announcements")
      ?.conversationId ??
      database.collection(collections.conversations).doc().id;
    await group.ref.set({
      memberChatConversationId: memberChatId,
      announcementsConversationId: announcementsId,
      updatedAt: now,
    }, {merge: true});
    bindings = [
      {type: "member_chat", conversationId: memberChatId},
      {type: "announcements", conversationId: announcementsId},
    ];
  }

  const ownerProfile = ownerId ?
    await activeProfileSnapshot(database, ownerId).catch(() => ({
      id: ownerId,
      username: "",
      displayName: "Athlete",
      isVerified: false,
    })) :
    {id: "unknown", username: "", displayName: "Athlete", isVerified: false};

  for (const binding of bindings) {
    const conversationRef = database
      .collection(collections.conversations)
      .doc(binding.conversationId);
    const conversation = await conversationRef.get();
    const contract = contracts.find((item) => item.type === binding.type);
    if (!conversation.exists) {
      await conversationRef.set(conversationDoc({
        groupId,
        channelType: binding.type,
        title: channelTitle(groupName, binding.type),
        createdBy: ownerId || "system",
        memberCount: 0,
        now,
      }));
    } else if (conversation.get("source") !== sportsGroupConversationSource) {
      await conversationRef.set({
        source: sportsGroupConversationSource,
        groupId,
        channelType: binding.type,
        updatedAt: now,
      }, {merge: true});
    }

    await groupRef(database, groupId).collection("channels").doc(binding.type).set({
      type: binding.type,
      conversationId: binding.conversationId,
      supportedMediaModes: contract?.supportedMediaModes ?? [],
      publishRoles: contract?.publishRoles ?? [],
      readRoles: contract?.readRoles ?? [],
      phase: "c2_live",
      updatedAt: now,
      createdAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  }

  // Sync active sports members into conversation membership (chunked).
  let cursor: DocumentSnapshot | undefined;
  const aclByConversation = new Map<string, string[]>();
  for (const binding of bindings) aclByConversation.set(binding.conversationId, []);

  for (;;) {
    let query = groupRef(database, groupId)
      .collection("members")
      .where("removedAt", "==", null)
      .orderBy("__name__")
      .limit(channelSyncBatchSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;

    const ops: Array<(batch: WriteBatch) => void> = [];
    for (const member of page.docs) {
      const role = activeMemberRole(member);
      if (!role) continue;
      const profile = (member.get("userSnapshot") as Record<string, unknown> | undefined) ??
        {id: member.id, username: "", displayName: "Athlete", isVerified: false};
      if (!profile.id) (profile as {id: string}).id = member.id;

      for (const binding of bindings) {
        const conversationRef = database
          .collection(collections.conversations)
          .doc(binding.conversationId);
        const title = channelTitle(groupName, binding.type);
        ops.push((batch) => {
          batch.set(
            conversationRef.collection("members").doc(member.id),
            conversationMemberData(
              {...profile, id: member.id},
              role,
              now,
            ),
            {merge: true},
          );
          batch.set(
            database.doc(
              `users/${member.id}/conversation_inbox/${binding.conversationId}`,
            ),
            conversationInboxData({
              conversationId: binding.conversationId,
              title,
              groupId,
              channelType: binding.type,
              now,
              memberSnapshots: [{...profile, id: member.id}],
            }),
            {merge: true},
          );
        });
        aclByConversation.get(binding.conversationId)?.push(member.id);
      }
    }
    await commitBatchedOps(database, ops);
    cursor = page.docs[page.docs.length - 1];
    if (page.size < channelSyncBatchSize) break;
  }

  // Recount memberCount from synced membership.
  for (const binding of bindings) {
    const memberIds = [...new Set(aclByConversation.get(binding.conversationId) ?? [])];
    const memberCount = memberIds.length;
    await database.collection(collections.conversations)
      .doc(binding.conversationId)
      .set({memberCount, updatedAt: now}, {merge: true});
    if (memberIds.length === 0 && ownerId) memberIds.push(ownerId);
    await setRealtimeAcl(binding.conversationId, memberIds);
  }

  // Seed owner if no members were found (edge case).
  if (ownerId) {
    const sample = await database
      .collection(collections.conversations)
      .doc(bindings[0].conversationId)
      .collection("members")
      .doc(ownerId)
      .get();
    if (!sample.exists) {
      await materializeGroupChannelConversations({
        database,
        groupId,
        groupName,
        ownerId,
        ownerProfile,
        memberChatConversationId: bindings.find((b) => b.type === "member_chat")!
          .conversationId,
        announcementsConversationId: bindings.find((b) => b.type === "announcements")!
          .conversationId,
        now,
      });
    }
  }

  return bindings;
}

export async function deactivateGroupChannelConversations(
  groupId: string,
  database: Firestore = getFirestore(),
): Promise<void> {
  const bindings = await loadChannelBindings(database, groupId);
  const now = Timestamp.now();
  for (const binding of bindings) {
    await database.collection(collections.conversations)
      .doc(binding.conversationId)
      .set({
        moderationState: "deleted",
        updatedAt: now,
      }, {merge: true});
  }
}

/** Paginate active sports group members for large-channel fan-out. */
export async function* iterateActiveGroupMembers(
  database: Firestore,
  groupId: string,
  pageSize = channelSyncBatchSize,
): AsyncGenerator<DocumentSnapshot[]> {
  let cursor: DocumentSnapshot | undefined;
  for (;;) {
    let query = groupRef(database, groupId)
      .collection("members")
      .where("removedAt", "==", null)
      .orderBy("__name__")
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) return;
    const active = page.docs.filter((doc) => activeMemberRole(doc) !== null);
    if (active.length > 0) yield active;
    cursor = page.docs[page.docs.length - 1];
    if (page.size < pageSize) return;
  }
}
