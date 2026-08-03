#!/usr/bin/env node
/**
 * Repair live pending follow request inbox on reemove-staging:
 * clear stale notification_events idempotency key, write pending inbox item.
 * Does NOT delete the pending follow_requests doc. Staging only.
 */
const {spawnSync} = require("node:child_process");
const {createHash} = require("node:crypto");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";
const REQUEST_ID = `${SECOND_UID}--${MAIN_UID}`;
const EVENT_ID = `follow_request_pending_${SECOND_UID}_${MAIN_UID}`;
const EVENT_HASH = createHash("sha256").update(EVENT_ID).digest("hex");

function accessToken() {
  const result = spawnSync("gcloud", ["auth", "print-access-token"], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(result.stderr || "Failed to print access token");
  }
  return result.stdout.trim();
}

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function notificationBucket(date, windowHours = 12) {
  return Math.floor(date.getTime() / (windowHours * 60 * 60 * 1000));
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

async function firestoreDelete(token, path) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${path}`;
  const response = await fetch(url, {
    method: "DELETE",
    headers: {Authorization: `Bearer ${token}`},
  });
  return {ok: response.ok || response.status === 404, status: response.status};
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
  for (const [k, v] of Object.entries(body.fields)) out[k] = decodeValue(v);
  return out;
}

async function main() {
  const token = accessToken();
  const now = new Date();
  const nowIso = now.toISOString();

  const request = await firestoreGet(token, `follow_requests/${REQUEST_ID}`);
  if (!request.ok) {
    throw new Error(`Pending request missing: ${request.status}`);
  }
  const requestDoc = decodeDoc(request.body);
  if (requestDoc.status !== "pending") {
    throw new Error(`Request status is ${requestDoc.status}, expected pending`);
  }
  if (requestDoc.requesterId !== SECOND_UID || requestDoc.targetId !== MAIN_UID) {
    throw new Error("Request direction mismatch");
  }

  const second = decodeDoc((await firestoreGet(token, `users/${SECOND_UID}`)).body);
  const username = second.username || "mmmmmm";
  const displayName = second.displayName || username;
  const avatarUrl = typeof second.avatarUrl === "string" ? second.avatarUrl : null;

  const staleEvent = await firestoreGet(
    token,
    `users/${MAIN_UID}/notification_events/${EVENT_HASH}`,
  );
  let clearedEvent = false;
  if (staleEvent.ok) {
    const staleNotifId = decodeDoc(staleEvent.body)?.notificationId;
    if (staleNotifId) {
      const staleNotif = await firestoreGet(
        token,
        `users/${MAIN_UID}/notifications/${staleNotifId}`,
      );
      const deletedAt = staleNotif.ok ? decodeDoc(staleNotif.body)?.deletedAt : null;
      if (!staleNotif.ok || deletedAt) {
        const del = await firestoreDelete(
          token,
          `users/${MAIN_UID}/notification_events/${EVENT_HASH}`,
        );
        clearedEvent = del.ok;
      }
    } else {
      clearedEvent = (await firestoreDelete(
        token,
        `users/${MAIN_UID}/notification_events/${EVENT_HASH}`,
      )).ok;
    }
  }

  // After clear, recreate with current group bucket (same helper contract).
  const groupKey = `follow_request_pending:${SECOND_UID}`;
  const notificationId = hash(
    `${MAIN_UID}:${groupKey}:${notificationBucket(now)}`,
  );
  const title = "Follow request";
  const body = `${displayName} (@${username}) requested to follow you.`;
  const route = `/profile/user/${encodeURIComponent(String(username).toLowerCase())}`;

  const actorFields = {
    id: {stringValue: SECOND_UID},
    username: {stringValue: String(username)},
    displayName: {stringValue: String(displayName)},
    isVerified: {booleanValue: false},
  };
  if (avatarUrl) actorFields.avatarUrl = {stringValue: avatarUrl};

  const notifFields = {
    id: {stringValue: notificationId},
    recipientId: {stringValue: MAIN_UID},
    category: {stringValue: "activity"},
    kind: {stringValue: "follow_request"},
    title: {stringValue: title},
    body: {stringValue: body},
    route: {stringValue: route},
    groupKey: {stringValue: groupKey},
    groupCount: {integerValue: "1"},
    actors: {arrayValue: {values: [{mapValue: {fields: actorFields}}]}},
    latestActorId: {stringValue: SECOND_UID},
    entityType: {stringValue: "user"},
    entityId: {stringValue: SECOND_UID},
    data: {
      mapValue: {
        fields: {
          profileId: {stringValue: SECOND_UID},
          requesterId: {stringValue: SECOND_UID},
          targetId: {stringValue: MAIN_UID},
          requestId: {stringValue: REQUEST_ID},
          status: {stringValue: "pending"},
          source: {stringValue: "follow_request_pending"},
        },
      },
    },
    readAt: {nullValue: null},
    deletedAt: {nullValue: null},
    createdAt: {timestampValue: nowIso},
    latestAt: {timestampValue: nowIso},
    updatedAt: {timestampValue: nowIso},
    schemaVersion: {integerValue: "1"},
  };

  const notifWrite = await firestorePatch(
    token,
    `users/${MAIN_UID}/notifications/${notificationId}`,
    notifFields,
    Object.keys(notifFields),
  );
  if (!notifWrite.ok) {
    throw new Error(`Notification write failed: ${JSON.stringify(notifWrite.body)}`);
  }

  const eventWrite = await firestorePatch(
    token,
    `users/${MAIN_UID}/notification_events/${EVENT_HASH}`,
    {
      eventId: {stringValue: EVENT_ID},
      notificationId: {stringValue: notificationId},
      recipientId: {stringValue: MAIN_UID},
      createdAt: {timestampValue: nowIso},
      expiresAt: {
        timestampValue: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      },
      schemaVersion: {integerValue: "1"},
    },
    ["eventId", "notificationId", "recipientId", "createdAt", "expiresAt", "schemaVersion"],
  );
  if (!eventWrite.ok) {
    throw new Error(`Event write failed: ${JSON.stringify(eventWrite.body)}`);
  }

  const summaryWrite = await firestorePatch(
    token,
    `users/${MAIN_UID}/private/notification_summary`,
    {
      uid: {stringValue: MAIN_UID},
      unreadCount: {integerValue: "1"},
      latestAt: {timestampValue: nowIso},
      updatedAt: {timestampValue: nowIso},
      schemaVersion: {integerValue: "1"},
    },
    ["uid", "unreadCount", "latestAt", "updatedAt", "schemaVersion"],
  );
  if (!summaryWrite.ok) {
    throw new Error(`Summary write failed: ${JSON.stringify(summaryWrite.body)}`);
  }

  const verify = await firestoreGet(
    token,
    `users/${MAIN_UID}/notifications/${notificationId}`,
  );
  const verifyDoc = decodeDoc(verify.body);

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    requestId: REQUEST_ID,
    requestStatus: requestDoc.status,
    clearedStaleEvent: clearedEvent,
    eventId: EVENT_ID,
    eventHash: EVENT_HASH,
    notificationId,
    notification: {
      kind: verifyDoc.kind,
      title: verifyDoc.title,
      body: verifyDoc.body,
      category: verifyDoc.category,
      entityId: verifyDoc.entityId,
      deletedAt: verifyDoc.deletedAt,
      data: verifyDoc.data,
      route: verifyDoc.route,
    },
    summaryUnreadCount: 1,
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
