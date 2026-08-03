#!/usr/bin/env node
/**
 * Live diagnose pending follow-request inbox delivery on reemove-staging.
 * Read-heavy; optional --repair writes one missing pending notification.
 */
const {spawnSync} = require("node:child_process");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";
const REPAIR = process.argv.includes("--repair");

function accessToken() {
  const result = spawnSync("gcloud", ["auth", "print-access-token"], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(result.stderr || "Failed to print access token");
  }
  return result.stdout.trim();
}

async function firestoreGet(token, path) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${path}`;
  const response = await fetch(url, {
    headers: {Authorization: `Bearer ${token}`},
  });
  const body = await response.json();
  return {ok: response.ok, status: response.status, body};
}

async function firestoreRunQuery(token, parent, structuredQuery) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents${parent}:runQuery`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({structuredQuery}),
  });
  const body = await response.json();
  return {ok: response.ok, status: response.status, body};
}

async function firestoreList(token, path, pageSize = 50) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${path}?pageSize=${pageSize}`;
  const response = await fetch(url, {
    headers: {Authorization: `Bearer ${token}`},
  });
  const body = await response.json();
  return {ok: response.ok, status: response.status, body};
}

function decodeValue(value) {
  if (value == null) return null;
  if (value.stringValue !== undefined) return value.stringValue;
  if (value.integerValue !== undefined) return Number(value.integerValue);
  if (value.booleanValue !== undefined) return value.booleanValue;
  if (value.timestampValue !== undefined) return value.timestampValue;
  if (value.nullValue !== undefined) return null;
  if (value.mapValue?.fields) {
    const out = {};
    for (const [k, v] of Object.entries(value.mapValue.fields)) {
      out[k] = decodeValue(v);
    }
    return out;
  }
  if (value.arrayValue?.values) {
    return value.arrayValue.values.map(decodeValue);
  }
  return value;
}

function decodeDoc(body) {
  if (!body?.fields) return null;
  const out = {__name: body.name};
  for (const [k, v] of Object.entries(body.fields)) {
    out[k] = decodeValue(v);
  }
  return out;
}

function docIdFromName(name) {
  if (!name) return null;
  const parts = String(name).split("/");
  return parts[parts.length - 1] || null;
}

async function listCollection(token, parentPath, collectionId, orderField = "createdAt") {
  const result = await firestoreRunQuery(token, `/${parentPath}`, {
    from: [{collectionId}],
    orderBy: [{field: {fieldPath: orderField}, direction: "DESCENDING"}],
    limit: 40,
  });
  if (!Array.isArray(result.body)) {
    // Fallback list without order
    const listed = await firestoreList(token, `${parentPath}/${collectionId}`);
    const docs = listed.body.documents || [];
    return docs.map((doc) => ({id: docIdFromName(doc.name), ...decodeDoc(doc)}));
  }
  return result.body
    .filter((row) => row.document)
    .map((row) => ({
      id: docIdFromName(row.document.name),
      ...decodeDoc(row.document),
    }));
}

async function main() {
  const token = accessToken();
  const requestId = `${SECOND_UID}--${MAIN_UID}`;
  const reverseRequestId = `${MAIN_UID}--${SECOND_UID}`;

  const [
    mainUser,
    secondUser,
    request,
    reverseRequest,
    mainSummary,
    secondSummary,
    edgeFollower,
    edgeFollowing,
  ] = await Promise.all([
    firestoreGet(token, `users/${MAIN_UID}`),
    firestoreGet(token, `users/${SECOND_UID}`),
    firestoreGet(token, `follow_requests/${requestId}`),
    firestoreGet(token, `follow_requests/${reverseRequestId}`),
    firestoreGet(token, `users/${MAIN_UID}/private/notification_summary`),
    firestoreGet(token, `users/${SECOND_UID}/private/notification_summary`),
    firestoreGet(token, `users/${MAIN_UID}/followers/${SECOND_UID}`),
    firestoreGet(token, `users/${SECOND_UID}/following/${MAIN_UID}`),
  ]);

  const mainNotifs = await listCollection(token, `users/${MAIN_UID}`, "notifications");
  const secondNotifs = await listCollection(token, `users/${SECOND_UID}`, "notifications");
  const mainEvents = await listCollection(token, `users/${MAIN_UID}`, "notification_events");
  const secondEvents = await listCollection(token, `users/${SECOND_UID}`, "notification_events");

  // Audit via query on actor/target is hard without indexes; list recent and filter.
  const auditListed = await firestoreRunQuery(token, "", {
    from: [{collectionId: "audit_logs"}],
    orderBy: [{field: {fieldPath: "createdAt"}, direction: "DESCENDING"}],
    limit: 80,
  });
  const audits = Array.isArray(auditListed.body) ?
    auditListed.body.filter((row) => row.document).map((row) => {
      const doc = decodeDoc(row.document);
      return {
        id: docIdFromName(row.document.name),
        action: doc.action,
        actorId: doc.actorId,
        targetId: doc.targetId,
        createdAt: doc.createdAt,
      };
    }).filter((e) =>
      [MAIN_UID, SECOND_UID].includes(e.actorId) ||
      [MAIN_UID, SECOND_UID].includes(e.targetId)
    ) :
    [];

  const pendingEventId = `follow_request_pending_${SECOND_UID}_${MAIN_UID}`;
  const {createHash} = require("node:crypto");
  const eventHash = createHash("sha256").update(pendingEventId).digest("hex");
  const eventDoc = await firestoreGet(
    token,
    `users/${MAIN_UID}/notification_events/${eventHash}`,
  );

  const report = {
    projectId: PROJECT_ID,
    direction: {
      requesterUid: SECOND_UID,
      requesterUsername: decodeDoc(secondUser.body)?.username,
      targetUid: MAIN_UID,
      targetUsername: decodeDoc(mainUser.body)?.username,
      expectedRequestId: requestId,
    },
    mainPrivacy: {
      accountPrivacy: decodeDoc(mainUser.body)?.accountPrivacy,
      followApprovalPolicy: decodeDoc(mainUser.body)?.followApprovalPolicy,
      followersCount: decodeDoc(mainUser.body)?.followersCount,
      followingCount: decodeDoc(mainUser.body)?.followingCount,
    },
    request: request.ok ? decodeDoc(request.body) : {missing: true, status: request.status},
    reverseRequest: reverseRequest.ok ? decodeDoc(reverseRequest.body) : null,
    edges: {
      mainFollowersSecond: edgeFollower.ok ? decodeDoc(edgeFollower.body) : null,
      secondFollowingMain: edgeFollowing.ok ? decodeDoc(edgeFollowing.body) : null,
    },
    summaries: {
      main: mainSummary.ok ? decodeDoc(mainSummary.body) : null,
      second: secondSummary.ok ? decodeDoc(secondSummary.body) : null,
    },
    expectedPendingEvent: {
      eventId: pendingEventId,
      eventHash,
      exists: eventDoc.ok,
      doc: eventDoc.ok ? decodeDoc(eventDoc.body) : null,
    },
    mainNotifications: mainNotifs.map((n) => ({
      id: n.id,
      kind: n.kind,
      title: n.title,
      body: n.body,
      entityId: n.entityId,
      deletedAt: n.deletedAt ?? null,
      readAt: n.readAt ?? null,
      data: n.data ?? null,
      createdAt: n.createdAt,
      latestAt: n.latestAt,
      route: n.route,
      category: n.category,
      groupKey: n.groupKey,
    })),
    secondNotifications: secondNotifs.map((n) => ({
      id: n.id,
      kind: n.kind,
      title: n.title,
      deletedAt: n.deletedAt ?? null,
      data: n.data ?? null,
      createdAt: n.createdAt,
    })),
    mainNotificationEvents: mainEvents.slice(0, 20).map((e) => ({
      id: e.id,
      eventId: e.eventId,
      notificationId: e.notificationId,
      createdAt: e.createdAt,
    })),
    secondNotificationEvents: secondEvents.slice(0, 10).map((e) => ({
      id: e.id,
      eventId: e.eventId,
      notificationId: e.notificationId,
      createdAt: e.createdAt,
    })),
    relevantAudits: audits.slice(0, 20),
    activeMainFollowRequestNotifs: mainNotifs.filter(
      (n) => n.kind === "follow_request" && !n.deletedAt,
    ),
    softDeletedMainFollowRequestNotifs: mainNotifs.filter(
      (n) => n.kind === "follow_request" && n.deletedAt,
    ),
  };

  // Verdict
  const req = report.request;
  const active = report.activeMainFollowRequestNotifs;
  let verdict = "unknown";
  if (!req || req.missing || req.status !== "pending") {
    verdict = "no_pending_request";
  } else if (active.length > 0) {
    verdict = "notification_exists_check_client_filter";
  } else if (report.softDeletedMainFollowRequestNotifs.some(
    (n) => n.entityId === SECOND_UID || n.data?.requesterId === SECOND_UID,
  )) {
    verdict = "notification_soft_deleted";
  } else if (!report.expectedPendingEvent.exists) {
    verdict = "notification_never_created";
  } else {
    verdict = "event_exists_but_inbox_missing_or_deleted";
  }
  report.verdict = verdict;

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
