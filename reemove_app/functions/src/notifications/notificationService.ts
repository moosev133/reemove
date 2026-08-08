import {createHash} from "node:crypto";

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentSnapshot,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {
  getMessaging,
  type MulticastMessage,
} from "firebase-admin/messaging";
import {logger} from "firebase-functions";

import {collections, currentSchemaVersion} from "../core/schema";
import {
  boundedPushBody,
  categoryEnabled,
  isWithinQuietHours,
  notificationBucket,
  parseStoredNotificationPreferences,
  quietHoursEnd,
  safeNotificationRoute,
  type NotificationCategory,
  type NotificationKind,
  type ParsedNotificationPreferences,
} from "./notificationPolicy";
import {
  groupNotificationCategoryForKind,
  groupNotificationPreferencesDocId,
  parseStoredGroupNotificationPreferences,
} from "./groupNotificationPolicy";

const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

export type NotificationActor = {
  id: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  isVerified: boolean;
};

export type NotificationInput = {
  eventId: string;
  recipientId: string;
  actorId?: string;
  actor?: NotificationActor;
  category: NotificationCategory;
  kind: NotificationKind;
  title: string;
  body: string;
  route: string;
  groupKey: string;
  entityType?: string;
  entityId?: string;
  imageUrl?: string;
  data?: Record<string, string>;
  priority?: "normal" | "high";
  suppressPush?: boolean;
  suppressionReason?: string;
};

type RecipientToken = {
  uid: string;
  token: string;
  documentId: string;
};

type NotificationWriteResult = {
  duplicate: boolean;
  notificationId: string;
  preferences: ParsedNotificationPreferences;
};

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function safeText(value: string, maximum: number): string {
  const normalized = value.trim().replace(/\s+/g, " ");
  return normalized.length <= maximum ? normalized : normalized.slice(0, maximum);
}

async function actorSnapshot(uid: string): Promise<NotificationActor | undefined> {
  if (!uid) return undefined;
  const profile = await getFirestore().collection(collections.users).doc(uid).get();
  if (!profile.exists || profile.get("moderationState") !== "active") {
    return undefined;
  }
  const avatarUrl = profile.get("avatarUrl");
  return {
    id: uid,
    username: String(profile.get("username") ?? ""),
    displayName: String(profile.get("displayName") ?? "Athlete"),
    ...(typeof avatarUrl === "string" && avatarUrl.length > 0 ? {avatarUrl} : {}),
    isVerified: profile.get("isVerified") === true,
  };
}

async function reciprocalBlockExists(
  recipientId: string,
  actorId: string | undefined,
): Promise<boolean> {
  if (!actorId || actorId === recipientId) return false;
  const database = getFirestore();
  const [forward, reverse] = await Promise.all([
    database.doc(`users/${recipientId}/blocks/${actorId}`).get(),
    database.doc(`users/${actorId}/blocks/${recipientId}`).get(),
  ]);
  return forward.exists || reverse.exists;
}

function actorList(
  existing: unknown,
  actor: NotificationActor | undefined,
): NotificationActor[] {
  const actors = Array.isArray(existing) ? existing.filter((item) =>
    item !== null && typeof item === "object") as NotificationActor[] : [];
  if (!actor) return actors.slice(0, 3);
  return [actor, ...actors.filter((item) => item.id !== actor.id)].slice(0, 3);
}

async function writeNotification(
  input: NotificationInput,
  actor: NotificationActor | undefined,
): Promise<NotificationWriteResult> {
  const database = getFirestore();
  const now = Timestamp.now();
  const preferenceRef = database.doc(
    `users/${input.recipientId}/private/preferences`,
  );
  const eventRef = database.doc(
    `users/${input.recipientId}/notification_events/${hash(input.eventId)}`,
  );
  const groupId = hash(
    `${input.recipientId}:${input.groupKey}:${notificationBucket(now.toDate())}`,
  );
  const notificationRef = database.doc(
    `users/${input.recipientId}/notifications/${groupId}`,
  );
  const summaryRef = database.doc(
    `users/${input.recipientId}/private/notification_summary`,
  );
  const preferencesSnapshot = await preferenceRef.get();
  const preferences = parseStoredNotificationPreferences(
    preferencesSnapshot.get("notifications"),
  );
  let duplicate = false;

  await database.runTransaction(async (transaction) => {
    const [event, existing, summary] = await Promise.all([
      transaction.get(eventRef),
      transaction.get(notificationRef),
      transaction.get(summaryRef),
    ]);
    if (event.exists) {
      duplicate = true;
      return;
    }
    const activeExisting = existing.exists &&
      !(existing.get("deletedAt") instanceof Timestamp);
    const wasUnread = activeExisting &&
      !(existing.get("readAt") instanceof Timestamp);
    const unreadCount = summary.exists ?
      Math.max(0, Number(summary.get("unreadCount") ?? 0)) : 0;
    const groupCount = activeExisting ?
      Math.max(1, Number(existing.get("groupCount") ?? 1)) + 1 : 1;
    const route = safeNotificationRoute(input.route);
    transaction.set(notificationRef, {
      id: notificationRef.id,
      recipientId: input.recipientId,
      category: input.category,
      kind: input.kind,
      title: safeText(input.title, 120),
      body: safeText(input.body, 500),
      route,
      groupKey: safeText(input.groupKey, 200),
      groupCount,
      actors: actorList(activeExisting ? existing.get("actors") : undefined, actor),
      latestActorId: actor?.id ?? input.actorId ?? null,
      ...(input.entityType ? {entityType: safeText(input.entityType, 80)} : {}),
      ...(input.entityId ? {entityId: safeText(input.entityId, 200)} : {}),
      ...(input.imageUrl ? {imageUrl: safeText(input.imageUrl, 2000)} : {}),
      data: input.data ?? {},
      readAt: null,
      deletedAt: null,
      createdAt: activeExisting ? existing.get("createdAt") ?? now : now,
      latestAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    transaction.create(eventRef, {
      eventId: input.eventId,
      notificationId: notificationRef.id,
      recipientId: input.recipientId,
      createdAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 30 * 24 * 60 * 60 * 1000),
      schemaVersion: currentSchemaVersion,
    });
    transaction.set(summaryRef, {
      uid: input.recipientId,
      unreadCount: wasUnread ? unreadCount : unreadCount + 1,
      latestAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  });
  return {duplicate, notificationId: notificationRef.id, preferences};
}

async function tokensFor(uid: string): Promise<RecipientToken[]> {
  const snapshot = await getFirestore().collection(`users/${uid}/device_tokens`)
    .where("messagingEnabled", "==", true)
    .limit(20)
    .get();
  return snapshot.docs.flatMap((document) => {
    const token = document.get("token");
    return typeof token === "string" && token.length > 0 ? [{
      uid,
      token,
      documentId: document.id,
    }] : [];
  });
}

async function writeDelivery(
  input: NotificationInput,
  notificationId: string,
  data: Record<string, unknown>,
): Promise<void> {
  const now = Timestamp.now();
  await getFirestore().collection(collections.notificationDeliveries)
    .doc(hash(`${input.eventId}:${input.recipientId}`))
    .set({
      eventId: input.eventId,
      notificationId,
      recipientId: input.recipientId,
      type: input.kind,
      category: input.category,
      route: safeNotificationRoute(input.route),
      ...data,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
}

async function sendPush(
  input: NotificationInput,
  notificationId: string,
  preferences: ParsedNotificationPreferences,
): Promise<void> {
  const tokens = await tokensFor(input.recipientId);
  if (tokens.length === 0) {
    await writeDelivery(input, notificationId, {
      status: "suppressed_no_tokens",
      tokenCount: 0,
    });
    return;
  }
  const route = safeNotificationRoute(input.route);
  const body = boundedPushBody(input.body, preferences.showPreviews);
  const payload: MulticastMessage = {
    tokens: tokens.map((item) => item.token),
    notification: {
      title: safeText(input.title, 120),
      body,
      ...(input.imageUrl ? {imageUrl: input.imageUrl} : {}),
    },
    data: {
      notificationId,
      type: input.kind,
      category: input.category,
      route,
      entityType: input.entityType ?? "",
      entityId: input.entityId ?? "",
      ...input.data,
    },
    android: {
      priority: input.priority ?? "normal",
      collapseKey: safeText(input.groupKey, 64),
      notification: {
        tag: safeText(input.groupKey, 64),
      },
    },
    apns: {
      headers: {
        "apns-collapse-id": safeText(input.groupKey, 64),
      },
      payload: {
        aps: {
          sound: input.priority === "high" ? "default" : undefined,
          threadId: safeText(input.groupKey, 64),
        },
      },
    },
  };
  const response = await getMessaging().sendEachForMulticast(payload);
  const cleanup = getFirestore().batch();
  response.responses.forEach((item, index) => {
    if (!item.success && item.error && invalidTokenCodes.has(item.error.code)) {
      const token = tokens[index];
      cleanup.delete(getFirestore().doc(
        `users/${token.uid}/device_tokens/${token.documentId}`,
      ));
    }
  });
  await cleanup.commit();
  await writeDelivery(input, notificationId, {
    status: response.failureCount === 0 ? "sent" :
      response.successCount === 0 ? "failed" : "partially_sent",
    tokenCount: tokens.length,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });
}

export async function createAndDeliverNotification(
  input: NotificationInput,
): Promise<{created: boolean; notificationId?: string}> {
  if (!input.recipientId || input.actorId === input.recipientId) {
    return {created: false};
  }
  if (await reciprocalBlockExists(input.recipientId, input.actorId)) {
    return {created: false};
  }
  const recipient: DocumentSnapshot = await getFirestore()
    .collection(collections.users).doc(input.recipientId).get();
  if (!recipient.exists || recipient.get("moderationState") !== "active") {
    return {created: false};
  }

  // Group-specific category suppression.
  //
  // When a user disables a category for a group, we do not create the
  // durable inbox notification at all (no notification doc, no delivery
  // record).
  if (input.data) {
    const groupId = typeof input.data.groupId === "string" ?
      input.data.groupId.trim() :
      "";
    const category = groupNotificationCategoryForKind(input.kind);
    if (groupId && category) {
      const groupPrefsSnapshot = await getFirestore().doc(
        `users/${input.recipientId}/private/${groupNotificationPreferencesDocId(groupId)}`,
      ).get();
      const prefs = parseStoredGroupNotificationPreferences(
        groupPrefsSnapshot.data(),
      );
      if (prefs.muted) {
        return {created: false};
      }
      const enabled = category === "member_chat" ?
        prefs.memberChatEnabled :
        category === "announcements" ?
          prefs.announcementsEnabled :
          category === "sessions" ?
            prefs.sessionsEnabled :
            prefs.invitationsEnabled;
      if (!enabled) {
        return {created: false};
      }
    }
  }

  const actor = input.actor ?? (input.actorId ?
    await actorSnapshot(input.actorId) : undefined);
  const result = await writeNotification(input, actor);
  if (result.duplicate) {
    return {created: false, notificationId: result.notificationId};
  }
  if (input.suppressPush) {
    await writeDelivery(input, result.notificationId, {
      status: "suppressed_context_preferences",
      suppressionReason: safeText(
        input.suppressionReason ?? "context_preferences",
        80,
      ),
      tokenCount: 0,
    });
    return {created: true, notificationId: result.notificationId};
  }
  if (!categoryEnabled(result.preferences, input.category)) {
    await writeDelivery(input, result.notificationId, {
      status: "suppressed_preferences",
      tokenCount: 0,
    });
    return {created: true, notificationId: result.notificationId};
  }
  if (isWithinQuietHours(new Date(), result.preferences.quietHours)) {
    const deliverAfter = Timestamp.fromDate(
      quietHoursEnd(new Date(), result.preferences.quietHours),
    );
    await writeDelivery(input, result.notificationId, {
      status: "deferred_quiet_hours",
      tokenCount: 0,
      deliverAfter,
      deferredPayload: {
        title: safeText(input.title, 120),
        body: safeText(input.body, 500),
        route: safeNotificationRoute(input.route),
        groupKey: safeText(input.groupKey, 200),
        entityType: input.entityType ?? null,
        entityId: input.entityId ?? null,
        imageUrl: input.imageUrl ?? null,
        data: input.data ?? {},
        priority: input.priority ?? "normal",
      },
    });
    return {created: true, notificationId: result.notificationId};
  }
  try {
    await sendPush(input, result.notificationId, result.preferences);
  } catch (error: unknown) {
    logger.error("Notification push delivery failed.", {
      eventId: input.eventId,
      recipientId: input.recipientId,
      error: error instanceof Error ? error.message : String(error),
    });
    await writeDelivery(input, result.notificationId, {
      status: "failed",
      tokenCount: 0,
      errorCode: error instanceof Error ? error.name : "unknown",
    });
  }
  return {created: true, notificationId: result.notificationId};
}

export async function deliverDeferredNotification(
  delivery: QueryDocumentSnapshot,
): Promise<void> {
  const payload = delivery.get("deferredPayload") as Record<string, unknown> | undefined;
  const recipientId = String(delivery.get("recipientId") ?? "");
  const notificationId = String(delivery.get("notificationId") ?? "");
  const eventId = String(delivery.get("eventId") ?? delivery.id);
  if (!payload || !recipientId || !notificationId) {
    await delivery.ref.update({status: "failed_invalid_deferred_payload"});
    return;
  }
  const preferencesDocument = await getFirestore().doc(
    `users/${recipientId}/private/preferences`,
  ).get();
  const preferences = parseStoredNotificationPreferences(
    preferencesDocument.get("notifications"),
  );
  const input: NotificationInput = {
    eventId,
    recipientId,
    category: String(delivery.get("category")) as NotificationCategory,
    kind: String(delivery.get("type")) as NotificationKind,
    title: String(payload.title ?? "ReeMove"),
    body: String(payload.body ?? "You have a new update."),
    route: String(payload.route ?? "/home/activity"),
    groupKey: String(payload.groupKey ?? notificationId),
    ...(typeof payload.entityType === "string" ? {
      entityType: payload.entityType,
    } : {}),
    ...(typeof payload.entityId === "string" ? {
      entityId: payload.entityId,
    } : {}),
    ...(typeof payload.imageUrl === "string" ? {imageUrl: payload.imageUrl} : {}),
    data: payload.data !== null && typeof payload.data === "object" ?
      payload.data as Record<string, string> : {},
    priority: payload.priority === "high" ? "high" : "normal",
  };
  if (!categoryEnabled(preferences, input.category)) {
    await delivery.ref.update({
      status: "suppressed_preferences",
      updatedAt: Timestamp.now(),
      deferredPayload: FieldValue.delete(),
    });
    return;
  }
  await sendPush(input, notificationId, preferences);
  await delivery.ref.update({
    deferredPayload: FieldValue.delete(),
    deliveredAfterQuietHours: true,
    updatedAt: Timestamp.now(),
  });
}
