#!/usr/bin/env node
/**
 * Soft-delete one verified stale "New follower" notification on staging QA
 * accounts when no follower edge exists. No production writes. No apply:true.
 */
const {spawnSync} = require("node:child_process");

const PROJECT_ID = "reemove-staging";
const MAIN_UID = "rAVFw0NRryd4nYjXMUU2qjIDUAy1";
const SECOND_UID = "SXYHRzqwvnawTyxgEEdpfwNqRnG2";
const NOTIFICATION_ID =
  "555c5472b872b5a47beb8fd7aa9b9f4fb6ca779a8593820eee56ce8b0e35a42f";

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

function fieldString(doc, path) {
  let current = doc?.fields;
  for (const part of path.split(".")) {
    if (!current) return null;
    if (part.includes("[")) {
      const [name, indexText] = part.split("[");
      const index = Number(indexText.replace("]", ""));
      current = current[name]?.arrayValue?.values?.[index]?.mapValue?.fields;
      continue;
    }
    const next = current[part];
    if (!next) return null;
    if (next.stringValue !== undefined) return next.stringValue;
    if (next.integerValue !== undefined) return next.integerValue;
    if (next.nullValue !== undefined) return null;
    if (next.timestampValue !== undefined) return next.timestampValue;
    if (next.mapValue?.fields) {
      current = next.mapValue.fields;
      continue;
    }
    return null;
  }
  return null;
}

async function main() {
  const token = accessToken();
  const now = new Date().toISOString();

  const [edge, following, notification] = await Promise.all([
    firestoreGet(token, `users/${MAIN_UID}/followers/${SECOND_UID}`),
    firestoreGet(token, `users/${SECOND_UID}/following/${MAIN_UID}`),
    firestoreGet(
      token,
      `users/${MAIN_UID}/notifications/${NOTIFICATION_ID}`,
    ),
  ]);

  if (edge.ok || following.ok) {
    throw new Error("Follower edge exists; refusing cleanup.");
  }
  if (!notification.ok) {
    throw new Error(`Notification missing: ${notification.status}`);
  }

  const kind = fieldString(notification.body, "kind");
  const title = fieldString(notification.body, "title");
  const actorId = fieldString(notification.body, "entityId");
  const deletedAt = fieldString(notification.body, "deletedAt");
  if (kind !== "new_follower" || title !== "New follower") {
    throw new Error(`Unexpected notification kind/title: ${kind}/${title}`);
  }
  if (actorId !== SECOND_UID) {
    throw new Error(`Unexpected actorId: ${actorId}`);
  }
  if (deletedAt) {
    console.log(JSON.stringify({alreadyCleaned: true, notificationId: NOTIFICATION_ID}, null, 2));
    return;
  }

  const patch = await firestorePatch(
    token,
    `users/${MAIN_UID}/notifications/${NOTIFICATION_ID}`,
    {
      deletedAt: {timestampValue: now},
      readAt: {timestampValue: now},
      updatedAt: {timestampValue: now},
      data: {
        mapValue: {
          fields: {
            profileId: {stringValue: SECOND_UID},
            status: {stringValue: "resolved"},
            cleanedBy: {stringValue: "phase_a_false_new_follower_fix"},
            source: {stringValue: "stale_new_follower_cleanup"},
          },
        },
      },
    },
    ["deletedAt", "readAt", "updatedAt", "data"],
  );
  if (!patch.ok) {
    throw new Error(`Cleanup failed: ${JSON.stringify(patch.body)}`);
  }

  const summary = await firestorePatch(
    token,
    `users/${MAIN_UID}/private/notification_summary`,
    {
      unreadCount: {integerValue: "0"},
      updatedAt: {timestampValue: now},
    },
    ["unreadCount", "updatedAt"],
  );
  if (!summary.ok) {
    throw new Error(`Summary reset failed: ${JSON.stringify(summary.body)}`);
  }

  console.log(JSON.stringify({
    cleaned: true,
    projectId: PROJECT_ID,
    notificationId: NOTIFICATION_ID,
    recipientId: MAIN_UID,
    actorId: SECOND_UID,
    kind,
    title,
    reason: "new_follower without follower edge",
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
