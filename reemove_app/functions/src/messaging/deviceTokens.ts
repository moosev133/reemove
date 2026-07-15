import {createHash} from "node:crypto";

import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {currentSchemaVersion} from "../core/schema";
import {requireUid} from "./conversationAccess";
import {recordValue} from "./messagingPolicy";

function tokenValue(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Messaging token is invalid.");
  }
  const token = value.trim();
  if (token.length < 20 || token.length > 4096) {
    throw new HttpsError("invalid-argument", "Messaging token is invalid.");
  }
  return token;
}

function platformValue(value: unknown): string {
  const allowed = ["ios", "android", "web", "macos", "other"];
  if (typeof value === "string" && allowed.includes(value)) return value;
  return "other";
}

export function deviceTokenId(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export const registerMessagingDevice = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = recordValue(request.data);
  const token = tokenValue(data.token);
  const platform = platformValue(data.platform);
  await consumeRateLimit(uid, {
    key: "register_messaging_device",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });
  const now = Timestamp.now();
  const reference = getFirestore().doc(`users/${uid}/device_tokens/${deviceTokenId(token)}`);
  await reference.set({
    uid,
    token,
    platform,
    messagingEnabled: true,
    lastSeenAt: now,
    updatedAt: now,
    createdAt: now,
    schemaVersion: currentSchemaVersion,
  }, {merge: true});
  return {registered: true};
});

export const unregisterMessagingDevice = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = recordValue(request.data);
  const token = tokenValue(data.token);
  await getFirestore().doc(`users/${uid}/device_tokens/${deviceTokenId(token)}`).delete();
  return {unregistered: true};
});
