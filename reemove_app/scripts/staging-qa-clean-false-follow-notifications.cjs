#!/usr/bin/env node
/**
 * Soft-delete malformed/stale follow notifications for staging QA accounts
 * when they do not match a real pending request or follower edge.
 * Staging only. No production. No apply:true.
 */
const {spawnSync} = require("node:child_process");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";
const PAIR = new Set([MAIN_UID, SECOND_UID]);

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

async function firestorePatch(token, path, fields, fieldPaths) {
  const mask = fieldPaths
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join("&");
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${path}?${mask}`;
  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({fields}),
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
  return value;
}

function decodeDoc(body) {
  if (!body?.fields) return null;
  const out = {};
  for (const [k, v] of Object.entries(body.fields)) {
    out[k] = decodeValue(v);
  }
  return out;
}

function docIdFromName(name) {
  const parts = String(name).split("/");
  return parts[parts.length - 1] || null;
}

async function listNotifications(token, uid) {
  const result = await firestoreRunQuery(token, `/users/${uid}`, {
    from: [{collectionId: "notifications"}],
    orderBy: [{field: {fieldPath: "createdAt"}, direction: "DESCENDING"}],
    limit: 50,
  });
  if (!Array.isArray(result.body)) return [];
  return result.body
    .filter((row) => row.document)
    .map((row) => {
      const doc = decodeDoc(row.document);
      return {
        id: docIdFromName(row.document.name),
        ...doc,
      };
    });
}

function actorBetweenPair(notification, recipientId) {
  const actorId = String(
    notification.actorId ||
      notification.entityId ||
      notification.data?.profileId ||
      "",
  );
  if (!actorId || !PAIR.has(actorId)) return null;
  if (actorId === recipientId) return null;
  return actorId;
}

async function main() {
  const token = accessToken();
  const now = new Date().toISOString();
  const cleaned = [];

  for (const uid of [MAIN_UID, SECOND_UID]) {
    const notifications = await listNotifications(token, uid);
    for (const notification of notifications) {
      if (notification.deletedAt) continue;
      const kind = notification.kind;
      const actorId = actorBetweenPair(notification, uid);
      if (!actorId) continue;

      let shouldClean = false;
      let reason = "";

      if (kind === "new_follower") {
        const edge = await firestoreGet(
          token,
          `users/${uid}/followers/${actorId}`,
        );
        if (!edge.ok) {
          shouldClean = true;
          reason = "new_follower without follower edge";
        } else {
          const source = decodeDoc(edge.body)?.source;
          if (source !== "direct_follow") {
            shouldClean = true;
            reason = `new_follower with non-direct edge source=${source}`;
          }
        }
      } else if (kind === "follow_request") {
        const requestId = `${actorId}--${uid}`;
        const request = await firestoreGet(token, `follow_requests/${requestId}`);
        const status = notification.data?.status;
        if (!request.ok || status === "resolved" || status === "declined") {
          shouldClean = true;
          reason = "follow_request without pending request doc";
        }
      } else if (
        kind === "follow_request_accepted" &&
        notification.title?.includes("declined")
      ) {
        shouldClean = true;
        reason = "malformed accepted/declined title mismatch";
      }

      if (!shouldClean) continue;

      const existingData = notification.data && typeof notification.data === "object" ?
        notification.data :
        {};
      const dataFields = {
        ...Object.fromEntries(
          Object.entries(existingData).map(([key, value]) => [
            key,
            typeof value === "string" ?
              {stringValue: value} :
              typeof value === "number" ?
                {integerValue: String(value)} :
                {stringValue: String(value)},
          ]),
        ),
        status: {stringValue: "resolved"},
        cleanedBy: {stringValue: "phase_a_false_new_follower_contract_fix"},
        cleanupReason: {stringValue: reason},
      };

      const patch = await firestorePatch(
        token,
        `users/${uid}/notifications/${notification.id}`,
        {
          deletedAt: {timestampValue: now},
          readAt: {timestampValue: now},
          updatedAt: {timestampValue: now},
          data: {mapValue: {fields: dataFields}},
        },
        ["deletedAt", "readAt", "updatedAt", "data"],
      );
      if (!patch.ok) {
        throw new Error(`Cleanup failed for ${uid}/${notification.id}: ${JSON.stringify(patch.body)}`);
      }
      cleaned.push({
        recipientId: uid,
        notificationId: notification.id,
        kind,
        actorId,
        reason,
      });
    }

    await firestorePatch(
      token,
      `users/${uid}/private/notification_summary`,
      {
        unreadCount: {integerValue: "0"},
        updatedAt: {timestampValue: now},
      },
      ["unreadCount", "updatedAt"],
    );
  }

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    cleanedCount: cleaned.length,
    cleaned,
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
