import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {assertActiveGroup, groupRef, requireActiveMember} from "../groups/groupsAccess";
import {currentSchemaVersion} from "../core/schema";
import {safeDocumentId} from "../feed/contentPolicy";
import {parseNotificationPreferencesUpdate} from "./notificationPolicy";
import {
  parseGroupNotificationPreferencesUpdate,
  parseStoredGroupNotificationPreferences,
  groupNotificationPreferencesDocId,
} from "./groupNotificationPolicy";

function requireUid(value: string | undefined): string {
  if (!value) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return value;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  throw new HttpsError("invalid-argument", "The request is invalid.");
}

export const updateNotificationPreferences = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    await consumeRateLimit(uid, {
      key: "update_notification_preferences",
      maxAttempts: 60,
      windowSeconds: 60 * 60,
    });
    const data = asRecord(request.data);
    const preferences = parseNotificationPreferencesUpdate(data.preferences);
    const now = Timestamp.now();
    await getFirestore().doc(`users/${uid}/private/preferences`).set({
      uid,
      notifications: preferences,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    await writeAuditEvent({
      actorId: uid,
      action: "notifications.preferences_updated",
      targetType: "user",
      targetId: uid,
      metadata: {
        masterEnabled: preferences.masterEnabled,
        quietHoursEnabled: preferences.quietHours.enabled,
      },
    });
    return {ok: true, preferences};
  },
);

export const getGroupNotificationPreferences = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const database = getFirestore();
    const groupId = safeDocumentId(data.groupId, "groupId");

    // Authorization: only active group members may read their preferences.
    const groupSnap = await groupRef(database, groupId).get();
    assertActiveGroup(groupSnap);
    await requireActiveMember(database, groupId, uid);

    const snapshot = await database.doc(
      `users/${uid}/private/${groupNotificationPreferencesDocId(groupId)}`,
    ).get();
    const preferences = parseStoredGroupNotificationPreferences(
      snapshot.data(),
    );
    return {ok: true, preferences};
  },
);

export const updateGroupNotificationPreferences = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    await consumeRateLimit(uid, {
      key: "update_group_notification_preferences",
      maxAttempts: 60,
      windowSeconds: 60 * 60,
    });
    const data = asRecord(request.data);
    const database = getFirestore();
    const groupId = safeDocumentId(data.groupId, "groupId");

    // Authorization: only active group members may update their preferences.
    const groupSnap = await groupRef(database, groupId).get();
    assertActiveGroup(groupSnap);
    await requireActiveMember(database, groupId, uid);

    const parsed = parseGroupNotificationPreferencesUpdate(
      asRecord(data.preferences),
    );
    const now = Timestamp.now();
    await database.doc(
      `users/${uid}/private/${groupNotificationPreferencesDocId(groupId)}`,
    ).set({
      uid,
      groupId,
      muted: parsed.muted,
      memberChatEnabled: parsed.memberChatEnabled,
      announcementsEnabled: parsed.announcementsEnabled,
      sessionsEnabled: parsed.sessionsEnabled,
      invitationsEnabled: parsed.invitationsEnabled,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});

    await writeAuditEvent({
      actorId: uid,
      action: "notifications.group_preferences_updated",
      targetType: "group",
      targetId: groupId,
    });

    return {ok: true, preferences: parsed};
  },
);

export const markNotificationRead = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const notificationId = safeDocumentId(
      data.notificationId,
      "notificationId",
    );
    const database = getFirestore();
    const notificationRef = database.doc(
      `users/${uid}/notifications/${notificationId}`,
    );
    const summaryRef = database.doc(
      `users/${uid}/private/notification_summary`,
    );
    const now = Timestamp.now();
    await database.runTransaction(async (transaction) => {
      const [notification, summary] = await Promise.all([
        transaction.get(notificationRef),
        transaction.get(summaryRef),
      ]);
      if (!notification.exists || notification.get("deletedAt") instanceof Timestamp) {
        throw new HttpsError("not-found", "This notification is unavailable.");
      }
      if (notification.get("readAt") instanceof Timestamp) return;
      const unreadCount = summary.exists ?
        Math.max(0, Number(summary.get("unreadCount") ?? 0) - 1) : 0;
      transaction.update(notificationRef, {readAt: now, updatedAt: now});
      transaction.set(summaryRef, {
        uid,
        unreadCount,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    });
    return {ok: true};
  },
);

export const markAllNotificationsRead = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    await consumeRateLimit(uid, {
      key: "mark_all_notifications_read",
      maxAttempts: 30,
      windowSeconds: 60 * 60,
    });
    const database = getFirestore();
    const now = Timestamp.now();
    let updated = 0;
    while (true) {
      const snapshot = await database.collection(`users/${uid}/notifications`)
        .where("readAt", "==", null)
        .where("deletedAt", "==", null)
        .limit(499)
        .get();
      if (snapshot.empty) break;
      const batch = database.batch();
      for (const document of snapshot.docs) {
        batch.update(document.ref, {readAt: now, updatedAt: now});
      }
      await batch.commit();
      updated += snapshot.size;
      if (snapshot.size < 499) break;
    }
    await database.doc(`users/${uid}/private/notification_summary`).set({
      uid,
      unreadCount: 0,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    return {ok: true, updated};
  },
);

export const deleteNotification = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const notificationId = safeDocumentId(
      data.notificationId,
      "notificationId",
    );
    const database = getFirestore();
    const notificationRef = database.doc(
      `users/${uid}/notifications/${notificationId}`,
    );
    const summaryRef = database.doc(
      `users/${uid}/private/notification_summary`,
    );
    const now = Timestamp.now();
    await database.runTransaction(async (transaction) => {
      const [notification, summary] = await Promise.all([
        transaction.get(notificationRef),
        transaction.get(summaryRef),
      ]);
      if (!notification.exists) return;
      const unread = !(notification.get("readAt") instanceof Timestamp) &&
        !(notification.get("deletedAt") instanceof Timestamp);
      const unreadCount = summary.exists ?
        Math.max(0, Number(summary.get("unreadCount") ?? 0) - (unread ? 1 : 0)) : 0;
      transaction.update(notificationRef, {
        deletedAt: now,
        updatedAt: now,
      });
      transaction.set(summaryRef, {
        uid,
        unreadCount,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    });
    return {ok: true};
  },
);

export const clearReadNotifications = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    await consumeRateLimit(uid, {
      key: "clear_read_notifications",
      maxAttempts: 20,
      windowSeconds: 60 * 60,
    });
    const database = getFirestore();
    const snapshot = await database.collection(`users/${uid}/notifications`)
      .where("readAt", "!=", null)
      .limit(500)
      .get();
    const now = Timestamp.now();
    const batch = database.batch();
    let updated = 0;
    for (const document of snapshot.docs) {
      if (document.get("deletedAt") instanceof Timestamp) continue;
      batch.update(document.ref, {
        deletedAt: now,
        updatedAt: now,
      });
      updated += 1;
    }
    if (updated > 0) await batch.commit();
    return {ok: true, updated};
  },
);

export async function purgeExpiredNotificationEvents(): Promise<number> {
  const database = getFirestore();
  const now = Timestamp.now();
  const expired = await database.collectionGroup("notification_events")
    .where("expiresAt", "<=", now)
    .limit(500)
    .get();
  if (expired.empty) return 0;
  const batch = database.batch();
  for (const document of expired.docs) batch.delete(document.ref);
  await batch.commit();
  return expired.size;
}

export async function purgeDeletedNotifications(): Promise<number> {
  const database = getFirestore();
  const threshold = Timestamp.fromMillis(
    Date.now() - 30 * 24 * 60 * 60 * 1000,
  );
  const deleted = await database.collectionGroup("notifications")
    .where("deletedAt", "<=", threshold)
    .limit(500)
    .get();
  if (deleted.empty) return 0;
  const batch = database.batch();
  for (const document of deleted.docs) batch.delete(document.ref);
  await batch.commit();
  return deleted.size;
}

export async function resetNotificationSummary(uid: string): Promise<void> {
  await getFirestore().doc(`users/${uid}/private/notification_summary`).set({
    uid,
    unreadCount: 0,
    latestAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    schemaVersion: currentSchemaVersion,
  }, {merge: true});
}
