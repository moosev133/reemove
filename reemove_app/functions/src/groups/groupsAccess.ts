import {
  FieldValue,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {collections, currentSchemaVersion} from "../core/schema";
import {activeProfileSnapshot} from "../messaging/conversationAccess";
import {
  isManagerRole,
  nextMemberCount,
  type GroupMemberRole,
  type GroupPrivacy,
} from "./groupsPolicy";

export function groupRef(database: Firestore, groupId: string) {
  return database.collection(collections.groups).doc(groupId);
}

export function memberRef(
  database: Firestore,
  groupId: string,
  uid: string,
) {
  return groupRef(database, groupId).collection("members").doc(uid);
}

export function joinRequestRef(
  database: Firestore,
  groupId: string,
  uid: string,
) {
  return groupRef(database, groupId).collection("join_requests").doc(uid);
}

export function invitationRef(
  database: Firestore,
  groupId: string,
  uid: string,
) {
  return groupRef(database, groupId).collection("invitations").doc(uid);
}

export function membershipInboxRef(
  database: Firestore,
  uid: string,
  groupId: string,
) {
  return database.doc(`users/${uid}/group_memberships/${groupId}`);
}

export function invitationInboxRef(
  database: Firestore,
  uid: string,
  groupId: string,
) {
  return database.doc(`users/${uid}/group_invitations/${groupId}`);
}

export async function assertNotBlocked(
  database: Firestore,
  a: string,
  b: string,
): Promise<void> {
  const [ab, ba] = await Promise.all([
    database.doc(`users/${a}/blocks/${b}`).get(),
    database.doc(`users/${b}/blocks/${a}`).get(),
  ]);
  if (ab.exists || ba.exists) {
    throw new HttpsError(
      "failed-precondition",
      "This group action is unavailable.",
    );
  }
}

export function assertActiveGroup(snapshot: DocumentSnapshot): void {
  if (!snapshot.exists ||
      snapshot.get("moderationState") !== "active" ||
      snapshot.get("status") === "deleted") {
    throw new HttpsError("not-found", "This group is unavailable.");
  }
}

export function activeMemberRole(
  snapshot: DocumentSnapshot,
): GroupMemberRole | null {
  if (!snapshot.exists ||
      (snapshot.get("removedAt") !== null &&
        snapshot.get("removedAt") !== undefined) ||
      snapshot.get("status") !== "active") {
    return null;
  }
  const role = String(snapshot.get("role") ?? "");
  if (role === "owner" || role === "admin" || role === "member") {
    return role;
  }
  return null;
}

export async function requireActiveMember(
  database: Firestore,
  groupId: string,
  uid: string,
): Promise<GroupMemberRole> {
  const member = await memberRef(database, groupId, uid).get();
  const role = activeMemberRole(member);
  if (!role) {
    throw new HttpsError("permission-denied", "Group membership is required.");
  }
  return role;
}

export async function requireManager(
  database: Firestore,
  groupId: string,
  uid: string,
): Promise<GroupMemberRole> {
  const role = await requireActiveMember(database, groupId, uid);
  if (!isManagerRole(role)) {
    throw new HttpsError(
      "permission-denied",
      "Owner or admin access is required.",
    );
  }
  return role;
}

export function canViewGroupDocument(
  privacy: GroupPrivacy,
  isMember: boolean,
): boolean {
  if (isMember) return true;
  return privacy === "public";
}

export function canListGroupInDiscovery(privacy: GroupPrivacy): boolean {
  return privacy === "public";
}

export function memberDocument(
  profile: Record<string, unknown>,
  role: GroupMemberRole,
  now: Timestamp,
): Record<string, unknown> {
  return {
    userId: profile.id,
    userSnapshot: profile,
    role,
    status: "active",
    joinedAt: now,
    removedAt: null,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

export function membershipInboxDocument(
  groupId: string,
  role: GroupMemberRole,
  group: DocumentSnapshot,
  now: Timestamp,
): Record<string, unknown> {
  return {
    groupId,
    role,
    status: "active",
    joinedAt: now,
    updatedAt: now,
    groupSnapshot: {
      name: String(group.get("name") ?? ""),
      privacy: String(group.get("privacy") ?? "public"),
      avatarUrl: group.get("avatarUrl") ?? null,
      category: String(group.get("category") ?? ""),
      memberCount: Number(group.get("memberCount") ?? 0),
    },
    schemaVersion: currentSchemaVersion,
  };
}

export function softRemoveMemberInTx(
  transaction: Transaction,
  database: Firestore,
  groupSnap: DocumentSnapshot,
  memberSnap: DocumentSnapshot,
  uid: string,
  now: Timestamp,
): void {
  const groupId = groupSnap.id;
  const wasActive = activeMemberRole(memberSnap) !== null;
  transaction.update(memberSnap.ref, {
    status: "removed",
    removedAt: now,
    updatedAt: now,
  });
  transaction.delete(membershipInboxRef(database, uid, groupId));
  if (wasActive) {
    const count = Number(groupSnap.get("memberCount") ?? 0);
    transaction.update(groupSnap.ref, {
      memberCount: nextMemberCount(count, -1),
      updatedAt: now,
    });
  }
}

export async function listManagerUids(
  database: Firestore,
  groupId: string,
): Promise<string[]> {
  const snapshot = await groupRef(database, groupId)
    .collection("members")
    .where("status", "==", "active")
    .where("role", "in", ["owner", "admin"])
    .limit(50)
    .get();
  return snapshot.docs
    .filter((doc) => doc.get("removedAt") === null || doc.get("removedAt") === undefined)
    .map((doc) => doc.id);
}

export {activeProfileSnapshot, FieldValue, Timestamp};
