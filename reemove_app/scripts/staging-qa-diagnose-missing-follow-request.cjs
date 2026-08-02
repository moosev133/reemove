#!/usr/bin/env node
/**
 * Live staging diagnosis for missing follow-request Activity inbox item.
 * Read-only against reemove-staging.
 */
const {spawnSync} = require("node:child_process");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";

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
  const out = {name: body.name};
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

async function listCollection(token, parent, collectionId, limit = 40, orderField = "createdAt") {
  const result = await firestoreRunQuery(token, parent, {
    from: [{collectionId}],
    orderBy: [{field: {fieldPath: orderField}, direction: "DESCENDING"}],
    limit,
  });
  if (!Array.isArray(result.body)) {
    return {error: result.status, body: result.body};
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
    mainNotifs,
    secondNotifs,
    mainEvents,
    secondEvents,
  ] = await Promise.all([
    firestoreGet(token, `users/${MAIN_UID}`),
    firestoreGet(token, `users/${SECOND_UID}`),
    firestoreGet(token, `follow_requests/${requestId}`),
    firestoreGet(token, `follow_requests/${reverseRequestId}`),
    firestoreGet(token, `users/${MAIN_UID}/private/notification_summary`),
    firestoreGet(token, `users/${SECOND_UID}/private/notification_summary`),
    listCollection(token, `/users/${MAIN_UID}`, "notifications", 30),
    listCollection(token, `/users/${SECOND_UID}`, "notifications", 30),
    listCollection(token, `/users/${MAIN_UID}`, "notification_events", 30),
    listCollection(token, `/users/${SECOND_UID}`, "notification_events", 30),
  ]);

  // Audit logs filtered client-side from recent scan
  const auditQuery = await firestoreRunQuery(token, "", {
    from: [{collectionId: "audit_logs"}],
    orderBy: [{field: {fieldPath: "createdAt"}, direction: "DESCENDING"}],
    limit: 80,
  });
  const audits = Array.isArray(auditQuery.body) ?
    auditQuery.body.filter((row) => row.document).map((row) => {
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
    {error: auditQuery.status, body: auditQuery.body};

  const summarizeNotifs = (list) => Array.isArray(list) ?
    list.map((n) => ({
      id: n.id,
      kind: n.kind,
      title: n.title,
      body: n.body,
      entityId: n.entityId,
      deletedAt: n.deletedAt ?? null,
      readAt: n.readAt ?? null,
      createdAt: n.createdAt,
      data: n.data ?? null,
      category: n.category,
      route: n.route,
      groupKey: n.groupKey,
    })) :
    list;

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    main: {
      uid: MAIN_UID,
      username: decodeDoc(mainUser.body)?.username,
      accountPrivacy: decodeDoc(mainUser.body)?.accountPrivacy,
      followApprovalPolicy: decodeDoc(mainUser.body)?.followApprovalPolicy,
      followersCount: decodeDoc(mainUser.body)?.followersCount,
    },
    second: {
      uid: SECOND_UID,
      username: decodeDoc(secondUser.body)?.username,
      accountPrivacy: decodeDoc(secondUser.body)?.accountPrivacy,
      followApprovalPolicy: decodeDoc(secondUser.body)?.followApprovalPolicy,
    },
    followRequest: request.ok ? decodeDoc(request.body) : null,
    reverseRequest: reverseRequest.ok ? decodeDoc(reverseRequest.body) : null,
    mainSummary: mainSummary.ok ? decodeDoc(mainSummary.body) : null,
    secondSummary: secondSummary.ok ? decodeDoc(secondSummary.body) : null,
    mainNotifications: summarizeNotifs(mainNotifs),
    secondNotifications: summarizeNotifs(secondNotifs),
    mainNotificationEvents: Array.isArray(mainEvents) ?
      mainEvents.map((e) => ({
        id: e.id,
        eventId: e.eventId,
        notificationId: e.notificationId,
        createdAt: e.createdAt,
      })) :
      mainEvents,
    secondNotificationEvents: Array.isArray(secondEvents) ?
      secondEvents.map((e) => ({
        id: e.id,
        eventId: e.eventId,
        notificationId: e.notificationId,
        createdAt: e.createdAt,
      })) :
      secondEvents,
    qaAudits: audits,
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
