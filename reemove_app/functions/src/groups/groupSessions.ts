import {
  getFirestore,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {currentSchemaVersion} from "../core/schema";
import {requireUid} from "../messaging/conversationAccess";
import {
  deliverGroupSessionNotification,
} from "../notifications/groupNotifications";
import {iterateActiveGroupMembers} from "./groupChannels";
import {
  activeMemberRole,
  activeProfileSnapshot,
  assertActiveGroup,
  groupRef,
  memberRef,
  requireActiveMember,
} from "./groupsAccess";
import {
  asRecord,
  emptyRsvpCounts,
  optionalString,
  parseGroupSessionRsvpStatus,
  parseIsoDate,
  requiredString,
  resolveGroupSessionType,
  type GroupPrivacy,
  type GroupSessionRsvpStatus,
  type GroupSessionType,
} from "./groupsPolicy";

export function sessionTypeLabel(sessionType: GroupSessionType): string {
  switch (sessionType) {
  case "training":
    return "Training";
  case "match":
    return "Match";
  default:
    return "Event";
  }
}

export function serializeGroupSession(
  doc: DocumentSnapshot,
  options?: {
    viewerRsvp?: GroupSessionRsvpStatus | null;
    includeRsvpCounts?: boolean;
  },
): Record<string, unknown> {
  const rawType = doc.get("sessionType") ?? doc.get("activity");
  let sessionType: GroupSessionType = "event";
  try {
    sessionType = resolveGroupSessionType(rawType, doc.get("activity"));
  } catch {
    sessionType = "event";
  }
  const counts = doc.get("rsvpCounts");
  const rsvpCounts = emptyRsvpCounts();
  if (counts !== null && typeof counts === "object" && !Array.isArray(counts)) {
    const record = counts as Record<string, unknown>;
    for (const key of Object.keys(rsvpCounts) as GroupSessionRsvpStatus[]) {
      const value = Number(record[key] ?? 0);
      rsvpCounts[key] = Number.isFinite(value) ? Math.max(0, value) : 0;
    }
  }
  return {
    sessionId: doc.id,
    title: doc.get("title"),
    sessionType,
    activity: doc.get("activity") ?? sessionType,
    description: doc.get("description") ?? "",
    startAt: doc.get("startAt")?.toDate?.()?.toISOString?.() ?? null,
    endAt: doc.get("endAt")?.toDate?.()?.toISOString?.() ?? null,
    location: doc.get("location") ?? {},
    capacity: doc.get("capacity") ?? 0,
    status: doc.get("status"),
    createdBy: doc.get("createdBy"),
    ...(options?.includeRsvpCounts === false ? {} : {rsvpCounts}),
    viewerRsvp: options?.viewerRsvp ?? null,
  };
}

export async function notifyActiveMembersOfSession(options: {
  database?: Firestore;
  groupId: string;
  groupName: string;
  sessionId: string;
  sessionTitle: string;
  sessionType: GroupSessionType;
  actorId: string;
  kind: "group_session_scheduled" | "group_session_updated" | "group_session_cancelled";
}): Promise<void> {
  const database = options.database ?? getFirestore();
  for await (const page of iterateActiveGroupMembers(database, options.groupId)) {
    await Promise.all(page.map(async (member) => {
      if (member.id === options.actorId) return;
      await deliverGroupSessionNotification({
        recipientId: member.id,
        actorId: options.actorId,
        groupId: options.groupId,
        groupName: options.groupName,
        sessionId: options.sessionId,
        sessionTitle: options.sessionTitle,
        sessionType: options.sessionType,
        kind: options.kind,
      });
    }));
  }
}

export const respondToGroupSessionRsvp = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const body = asRecord(request.data);
    const groupId = requiredString(body.groupId, "groupId", 128);
    const sessionId = requiredString(body.sessionId, "sessionId", 128);
    const status = parseGroupSessionRsvpStatus(body.status);
    await consumeRateLimit(uid, {
      key: "group_session_rsvp",
      maxAttempts: 120,
      windowSeconds: 60 * 60,
    });

    const database = getFirestore();
    await requireActiveMember(database, groupId, uid);
    const sessionRef = groupRef(database, groupId)
      .collection("sessions")
      .doc(sessionId);
    const rsvpRef = sessionRef.collection("rsvps").doc(uid);
    const profile = await activeProfileSnapshot(database, uid);
    const now = Timestamp.now();

    await database.runTransaction(async (transaction) => {
      const session = await transaction.get(sessionRef);
      if (!session.exists) {
        throw new HttpsError("not-found", "Session not found.");
      }
      if (session.get("status") !== "scheduled") {
        throw new HttpsError(
          "failed-precondition",
          "Only scheduled sessions accept RSVPs.",
        );
      }
      const existing = await transaction.get(rsvpRef);
      const previous = existing.exists ?
        String(existing.get("status") ?? "") as GroupSessionRsvpStatus | "" :
        "";
      if (previous === status) {
        return;
      }

      const counts = emptyRsvpCounts();
      const rawCounts = session.get("rsvpCounts");
      if (rawCounts !== null && typeof rawCounts === "object") {
        const record = rawCounts as Record<string, unknown>;
        for (const key of Object.keys(counts) as GroupSessionRsvpStatus[]) {
          counts[key] = Math.max(0, Number(record[key] ?? 0) || 0);
        }
      }

      if (previous && previous in counts) {
        counts[previous as GroupSessionRsvpStatus] = Math.max(
          0,
          counts[previous as GroupSessionRsvpStatus] - 1,
        );
      }

      const capacity = Number(session.get("capacity") ?? 0);
      if (
        status === "going" &&
        capacity > 0 &&
        previous !== "going" &&
        counts.going >= capacity
      ) {
        throw new HttpsError(
          "resource-exhausted",
          "This session is at capacity.",
        );
      }
      counts[status] += 1;

      transaction.set(rsvpRef, {
        userId: uid,
        status,
        userSnapshot: profile,
        updatedAt: now,
        createdAt: existing.exists ? existing.get("createdAt") ?? now : now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
      transaction.update(sessionRef, {
        rsvpCounts: counts,
        updatedAt: now,
      });
    });

    await writeAuditEvent({
      actorId: uid,
      action: "groups.session_rsvp",
      targetType: "group_session",
      targetId: `${groupId}:${sessionId}`,
      metadata: {status},
    });
    return {ok: true, status};
  },
);

export const listGroupSessionRsvps = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const body = asRecord(request.data);
  const groupId = requiredString(body.groupId, "groupId", 128);
  const sessionId = requiredString(body.sessionId, "sessionId", 128);
  const database = getFirestore();
  await requireActiveMember(database, groupId, uid);
  const session = await groupRef(database, groupId)
    .collection("sessions")
    .doc(sessionId)
    .get();
  if (!session.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }
  const snapshot = await session.ref.collection("rsvps").limit(200).get();
  return {
    session: serializeGroupSession(session, {
      viewerRsvp: snapshot.docs.find((doc) => doc.id === uid)?.get("status") ??
        null,
    }),
    rsvps: snapshot.docs.map((doc) => ({
      userId: doc.id,
      status: doc.get("status"),
      displayName: String(
        (doc.get("userSnapshot") as Record<string, unknown> | undefined)
          ?.displayName ?? "",
      ),
      username: String(
        (doc.get("userSnapshot") as Record<string, unknown> | undefined)
          ?.username ?? "",
      ),
      updatedAt: doc.get("updatedAt")?.toDate?.()?.toISOString?.() ?? null,
    })),
  };
});

/** Shared list implementation used by listGroupSessions callable. */
export async function listSessionsForViewer(options: {
  database: Firestore;
  groupId: string;
  uid: string;
}): Promise<{sessions: Record<string, unknown>[]}> {
  const {database, groupId, uid} = options;
  const group = await groupRef(database, groupId).get();
  assertActiveGroup(group);
  const privacy = String(group.get("privacy")) as GroupPrivacy;
  const role = activeMemberRole(
    await memberRef(database, groupId, uid).get(),
  );
  if (privacy !== "public" && !role) {
    throw new HttpsError("permission-denied", "Schedule is private.");
  }
  const snapshot = await groupRef(database, groupId)
    .collection("sessions")
    .where("status", "in", ["scheduled", "cancelled", "completed"])
    .orderBy("startAt", "asc")
    .limit(50)
    .get();

  const sessions: Record<string, unknown>[] = [];
  for (const doc of snapshot.docs) {
    let viewerRsvp: GroupSessionRsvpStatus | null = null;
    if (role) {
      const rsvp = await doc.ref.collection("rsvps").doc(uid).get();
      if (rsvp.exists) {
        viewerRsvp = String(rsvp.get("status") ?? "") as GroupSessionRsvpStatus;
      }
    }
    sessions.push(serializeGroupSession(doc, {
      viewerRsvp,
      includeRsvpCounts: !!role,
    }));
  }
  return {sessions};
}

export function parseSessionPatch(body: Record<string, unknown>): {
  patch: Record<string, unknown>;
  sessionType?: GroupSessionType;
  title?: string;
  significant: boolean;
} {
  const patch: Record<string, unknown> = {updatedAt: Timestamp.now()};
  let significant = false;
  let sessionType: GroupSessionType | undefined;
  let title: string | undefined;

  if (body.title !== undefined) {
    title = requiredString(body.title, "title", 120);
    patch.title = title;
    significant = true;
  }
  if (body.sessionType !== undefined || body.activity !== undefined) {
    sessionType = resolveGroupSessionType(body.sessionType, body.activity);
    patch.sessionType = sessionType;
    if (body.activity !== undefined) {
      patch.activity =
        optionalString(body.activity, "activity", 64) || sessionType;
    } else if (body.sessionType !== undefined) {
      patch.activity = sessionType;
    }
    significant = true;
  }
  if (body.description !== undefined) {
    patch.description = optionalString(body.description, "description", 2000);
  }
  if (body.startAt !== undefined) {
    patch.startAt = Timestamp.fromDate(parseIsoDate(body.startAt, "startAt"));
    significant = true;
  }
  if (body.endAt !== undefined) {
    patch.endAt = Timestamp.fromDate(parseIsoDate(body.endAt, "endAt"));
    significant = true;
  }
  if (body.capacity !== undefined) {
    const capacity = Number(body.capacity);
    if (!Number.isInteger(capacity) || capacity < 0 || capacity > 10000) {
      throw new HttpsError("invalid-argument", "capacity is invalid.");
    }
    patch.capacity = capacity;
  }
  if (body.location !== undefined) {
    patch.location = asRecord(body.location);
  }
  return {patch, sessionType, title, significant};
}

