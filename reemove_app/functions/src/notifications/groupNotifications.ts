import {createHash} from "node:crypto";

import {getFirestore, Timestamp} from "firebase-admin/firestore";

import {currentSchemaVersion} from "../core/schema";
import {createAndDeliverNotification} from "./notificationService";

function eventDocId(eventId: string): string {
  return createHash("sha256").update(eventId).digest("hex");
}

async function actorLabel(actorId: string): Promise<{
  username: string;
  displayName: string;
}> {
  const snap = await getFirestore().collection("users").doc(actorId).get();
  const username = String(snap.get("username") ?? "someone");
  const displayName = String(snap.get("displayName") ?? username);
  return {username, displayName};
}

export async function deliverGroupJoinRequestNotification(input: {
  groupId: string;
  groupName: string;
  requesterId: string;
  recipientId: string;
}): Promise<void> {
  const {username, displayName} = await actorLabel(input.requesterId);
  await createAndDeliverNotification({
    eventId: `group_join_request_${input.groupId}_${input.requesterId}`,
    recipientId: input.recipientId,
    actorId: input.requesterId,
    category: "activity",
    kind: "group_join_request",
    title: "Group join request",
    body: `${displayName} (@${username}) requested to join ${input.groupName}.`,
    route: `/discover/groups/${encodeURIComponent(input.groupId)}/requests`,
    groupKey: `group_join_request:${input.groupId}:${input.requesterId}`,
    entityType: "group",
    entityId: input.groupId,
    data: {
      groupId: input.groupId,
      requesterId: input.requesterId,
      status: "pending",
    },
  });
}

export async function deliverGroupJoinAcceptedNotification(input: {
  groupId: string;
  groupName: string;
  actorId: string;
  requesterId: string;
}): Promise<void> {
  const {username, displayName} = await actorLabel(input.actorId);
  await createAndDeliverNotification({
    eventId: `group_join_accepted_${input.groupId}_${input.requesterId}`,
    recipientId: input.requesterId,
    actorId: input.actorId,
    category: "activity",
    kind: "group_join_accepted",
    title: "Join request accepted",
    body: `${displayName} (@${username}) accepted you into ${input.groupName}.`,
    route: `/discover/groups/${encodeURIComponent(input.groupId)}`,
    groupKey: `group_join_accepted:${input.groupId}`,
    entityType: "group",
    entityId: input.groupId,
    data: {
      groupId: input.groupId,
      status: "accepted",
    },
  });
}

export async function deliverGroupInvitationNotification(input: {
  groupId: string;
  groupName: string;
  inviterId: string;
  inviteeId: string;
}): Promise<void> {
  const {username, displayName} = await actorLabel(input.inviterId);
  await createAndDeliverNotification({
    eventId: `group_invitation_${input.groupId}_${input.inviteeId}`,
    recipientId: input.inviteeId,
    actorId: input.inviterId,
    category: "activity",
    kind: "group_invitation",
    title: "Group invitation",
    body: `${displayName} (@${username}) invited you to ${input.groupName}.`,
    route: `/discover/groups/invitations`,
    groupKey: `group_invitation:${input.groupId}:${input.inviteeId}`,
    entityType: "group",
    entityId: input.groupId,
    data: {
      groupId: input.groupId,
      inviterId: input.inviterId,
      status: "pending",
    },
  });
}

export async function deliverGroupInvitationAcceptedNotification(input: {
  groupId: string;
  groupName: string;
  inviterId: string;
  inviteeId: string;
}): Promise<void> {
  const {username, displayName} = await actorLabel(input.inviteeId);
  await createAndDeliverNotification({
    eventId: `group_invitation_accepted_${input.groupId}_${input.inviteeId}`,
    recipientId: input.inviterId,
    actorId: input.inviteeId,
    category: "activity",
    kind: "group_invitation_accepted",
    title: "Invitation accepted",
    body: `${displayName} (@${username}) joined ${input.groupName}.`,
    route: `/discover/groups/${encodeURIComponent(input.groupId)}`,
    groupKey: `group_invitation_accepted:${input.groupId}:${input.inviteeId}`,
    entityType: "group",
    entityId: input.groupId,
    data: {
      groupId: input.groupId,
      inviteeId: input.inviteeId,
      status: "accepted",
    },
  });
}

/**
 * Soft-resolves any still-pending "join request" notifications a manager may
 * have for a given requester/group pair (e.g. because another manager already
 * accepted/declined the request, or the requester cancelled it). Mirrors the
 * pattern used by resolvePendingMessageRequestNotifications.
 */
export async function resolveGroupJoinRequestNotifications(
  recipientId: string,
  groupId: string,
  requesterId: string,
): Promise<number> {
  if (!recipientId || !groupId || !requesterId) return 0;
  const database = getFirestore();
  const notifications = await database.collection("users").doc(recipientId)
    .collection("notifications")
    .where("kind", "==", "group_join_request")
    .where("entityId", "==", groupId)
    .limit(50)
    .get();

  const matching = notifications.docs.filter((document) => {
    const data = document.get("data");
    const dataRequesterId = data !== null && typeof data === "object" ?
      (data as Record<string, unknown>).requesterId :
      undefined;
    return String(dataRequesterId ?? "") === requesterId;
  });
  if (matching.length === 0) return 0;

  const now = Timestamp.now();
  let resolvedUnread = 0;
  const batch = database.batch();
  for (const document of matching) {
    if (document.get("deletedAt") instanceof Timestamp) continue;
    const wasUnread = !(document.get("readAt") instanceof Timestamp);
    if (wasUnread) resolvedUnread += 1;
    const existingData = document.get("data");
    batch.set(document.ref, {
      deletedAt: now,
      updatedAt: now,
      readAt: document.get("readAt") instanceof Timestamp ?
        document.get("readAt") :
        now,
      data: {
        ...(existingData !== null && typeof existingData === "object" ?
          existingData as Record<string, unknown> :
          {}),
        status: "resolved",
      },
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  }
  batch.delete(database.doc(
    `users/${recipientId}/notification_events/${eventDocId(
      `group_join_request_${groupId}_${requesterId}`,
    )}`,
  ));
  if (resolvedUnread > 0) {
    const summaryRef = database.doc(
      `users/${recipientId}/private/notification_summary`,
    );
    const summary = await summaryRef.get();
    const current = Number(summary.get("unreadCount") ?? 0);
    batch.set(summaryRef, {
      uid: recipientId,
      unreadCount: Math.max(0, current - resolvedUnread),
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  }
  await batch.commit();
  return matching.length;
}

export async function deliverGroupSessionNotification(input: {
  recipientId: string;
  actorId: string;
  groupId: string;
  groupName: string;
  sessionId: string;
  sessionTitle: string;
  sessionType: string;
  kind:
    | "group_session_scheduled"
    | "group_session_updated"
    | "group_session_cancelled";
}): Promise<void> {
  const {username, displayName} = await actorLabel(input.actorId);
  const typeLabel = input.sessionType === "training" ?
    "training" :
    input.sessionType === "match" ?
      "match" :
      "event";
  const titles: Record<typeof input.kind, string> = {
    group_session_scheduled: "New group session",
    group_session_updated: "Session updated",
    group_session_cancelled: "Session cancelled",
  };
  const bodies: Record<typeof input.kind, string> = {
    group_session_scheduled:
      `${displayName} (@${username}) scheduled ${typeLabel} “${input.sessionTitle}” in ${input.groupName}.`,
    group_session_updated:
      `${displayName} (@${username}) updated ${typeLabel} “${input.sessionTitle}” in ${input.groupName}.`,
    group_session_cancelled:
      `${displayName} (@${username}) cancelled ${typeLabel} “${input.sessionTitle}” in ${input.groupName}.`,
  };
  await createAndDeliverNotification({
    eventId: `${input.kind}_${input.groupId}_${input.sessionId}_${input.recipientId}`,
    recipientId: input.recipientId,
    actorId: input.actorId,
    category: "events",
    kind: input.kind,
    title: titles[input.kind],
    body: bodies[input.kind],
    route: `/discover/groups/${encodeURIComponent(input.groupId)}/schedule`,
    groupKey: `${input.kind}:${input.groupId}:${input.sessionId}`,
    entityType: "group_session",
    entityId: input.sessionId,
    data: {
      groupId: input.groupId,
      sessionId: input.sessionId,
      sessionType: input.sessionType,
      status: input.kind === "group_session_cancelled" ? "cancelled" : "scheduled",
    },
  });
}
