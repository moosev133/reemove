#!/usr/bin/env node
/**
 * Diagnose false "New follower" notifications for staging QA accounts.
 * Read-only against reemove-staging. No production. No apply:true.
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

async function listNotifications(token, uid) {
  const result = await firestoreRunQuery(token, `/users/${uid}`, {
    from: [{collectionId: "notifications"}],
    orderBy: [{field: {fieldPath: "createdAt"}, direction: "DESCENDING"}],
    limit: 40,
  });
  if (!result.ok || !Array.isArray(result.body)) {
    return {error: result.status, body: result.body};
  }
  return result.body
    .filter((row) => row.document)
    .map((row) => {
      const doc = decodeDoc(row.document);
      return {
        id: docIdFromName(row.document.name),
        kind: doc.kind,
        title: doc.title,
        body: doc.body,
        eventId: doc.eventId,
        actorId: doc.actorId ?? doc.entityId,
        recipientId: uid,
        entityId: doc.entityId,
        createdAt: doc.createdAt,
        deletedAt: doc.deletedAt ?? null,
        readAt: doc.readAt ?? null,
        data: doc.data ?? null,
        route: doc.route,
        groupKey: doc.groupKey,
      };
    });
}

async function main() {
  const token = accessToken();

  const [
    mainUser,
    secondUser,
    mmmmmmUsername,
    edgeFollower,
    edgeFollowing,
    reverseFollower,
    reverseFollowing,
    requestSecondToMain,
    requestMainToSecond,
    mainSummary,
    secondSummary,
  ] = await Promise.all([
    firestoreGet(token, `users/${MAIN_UID}`),
    firestoreGet(token, `users/${SECOND_UID}`),
    firestoreGet(token, "usernames/mmmmmm"),
    firestoreGet(token, `users/${MAIN_UID}/followers/${SECOND_UID}`),
    firestoreGet(token, `users/${SECOND_UID}/following/${MAIN_UID}`),
    firestoreGet(token, `users/${SECOND_UID}/followers/${MAIN_UID}`),
    firestoreGet(token, `users/${MAIN_UID}/following/${SECOND_UID}`),
    firestoreGet(token, `follow_requests/${SECOND_UID}--${MAIN_UID}`),
    firestoreGet(token, `follow_requests/${MAIN_UID}--${SECOND_UID}`),
    firestoreGet(token, `users/${MAIN_UID}/private/notification_summary`),
    firestoreGet(token, `users/${SECOND_UID}/private/notification_summary`),
  ]);

  const mainNotifs = await listNotifications(token, MAIN_UID);
  const secondNotifs = await listNotifications(token, SECOND_UID);

  const newFollowerNotifs = (Array.isArray(mainNotifs) ? mainNotifs : [])
    .filter((n) => n.kind === "new_follower");
  const followRequestNotifs = (Array.isArray(mainNotifs) ? mainNotifs : [])
    .filter((n) => n.kind === "follow_request" || n.kind === "follow_request_accepted");

  const report = {
    projectId: PROJECT_ID,
    main: decodeDoc(mainUser.body),
    second: decodeDoc(secondUser.body),
    mmmmmmUsernameDoc: mmmmmmUsername.ok ? decodeDoc(mmmmmmUsername.body) : null,
    edges: {
      mainFollowersSecond: edgeFollower.ok ? decodeDoc(edgeFollower.body) : null,
      secondFollowingMain: edgeFollowing.ok ? decodeDoc(edgeFollowing.body) : null,
      secondFollowersMain: reverseFollower.ok ? decodeDoc(reverseFollower.body) : null,
      mainFollowingSecond: reverseFollowing.ok ? decodeDoc(reverseFollowing.body) : null,
    },
    requests: {
      secondToMain: requestSecondToMain.ok ?
        decodeDoc(requestSecondToMain.body) :
        null,
      mainToSecond: requestMainToSecond.ok ?
        decodeDoc(requestMainToSecond.body) :
        null,
    },
    summaries: {
      main: mainSummary.ok ? decodeDoc(mainSummary.body) : null,
      second: secondSummary.ok ? decodeDoc(secondSummary.body) : null,
    },
    mainNewFollowerNotifications: newFollowerNotifs,
    mainFollowRequestNotifications: followRequestNotifs,
    mainNotificationsRecent: Array.isArray(mainNotifs) ?
      mainNotifs.slice(0, 15) :
      mainNotifs,
    secondNotificationsRecent: Array.isArray(secondNotifs) ?
      secondNotifs.slice(0, 15) :
      secondNotifs,
  };

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
