import {
  FieldValue,
  GeoPoint,
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {activeProfileSnapshot, requireUid} from "../messaging/conversationAccess";
import {
  asRecord,
  parseCommunityInput,
  parseEventInput,
  parseTrainerServiceInput,
  requiredString,
} from "./sportsPolicy";

async function assertEnabledSport(
  database: Firestore,
  sportId: string,
): Promise<void> {
  const sport = await database.collection(collections.sports).doc(sportId).get();
  if (!sport.exists || sport.get("isEnabled") !== true) {
    throw new HttpsError("failed-precondition", "This sport is unavailable.");
  }
}

function memberSnapshot(
  profile: Record<string, unknown>,
  role: "owner" | "member" | "pending",
  now: Timestamp,
): Record<string, unknown> {
  return {
    userId: profile.id,
    userSnapshot: profile,
    role,
    status: role === "pending" ? "pending" : "active",
    joinedAt: now,
    removedAt: null,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

export const createSportCommunity = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseCommunityInput(request.data);
  await consumeRateLimit(uid, {
    key: "create_sport_community",
    maxAttempts: 10,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  await assertEnabledSport(database, input.sportId);
  const profile = await activeProfileSnapshot(database, uid);
  const now = Timestamp.now();
  const reference = database.collection(collections.teams).doc();
  const batch = database.batch();
  batch.create(reference, {
    sportId: input.sportId,
    ownerId: uid,
    name: input.name,
    description: input.description,
    type: input.type,
    joinPolicy: input.joinPolicy,
    memberCount: 1,
    capacity: input.capacity,
    tags: input.tags,
    city: input.city,
    countryCode: input.countryCode,
    ...(input.pricingText ? {pricingText: input.pricingText} : {}),
    isVerified: false,
    visibility: "public",
    moderationState: "active",
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  batch.create(
    reference.collection("members").doc(uid),
    memberSnapshot(profile, "owner", now),
  );
  await batch.commit();
  await writeAuditEvent({
    actorId: uid,
    action: "sports.community_created",
    targetType: "sport_community",
    targetId: reference.id,
    metadata: {sportId: input.sportId, type: input.type},
  });
  return {communityId: reference.id};
});

export const joinSportCommunity = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const communityId = requiredString(data.communityId, "Community", 120);
  await consumeRateLimit(uid, {
    key: "join_sport_community",
    maxAttempts: 60,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const communityRef = database.collection(collections.teams).doc(communityId);
  const memberRef = communityRef.collection("members").doc(uid);
  const profile = await activeProfileSnapshot(database, uid);
  const status = await database.runTransaction(async (transaction) => {
    const [community, member] = await Promise.all([
      transaction.get(communityRef),
      transaction.get(memberRef),
    ]);
    if (!community.exists || community.get("moderationState") !== "active" ||
        community.get("visibility") !== "public") {
      throw new HttpsError("not-found", "This community is unavailable.");
    }
    if (member.exists && member.get("removedAt") === null) {
      const role = String(member.get("role") ?? "member");
      return role === "pending" ? "pending" : role;
    }
    const joinPolicy = String(community.get("joinPolicy") ?? "open");
    if (joinPolicy === "inviteOnly") {
      throw new HttpsError("permission-denied", "This community is invite only.");
    }
    const memberCount = Number(community.get("memberCount") ?? 0);
    const capacity = Number(community.get("capacity") ?? 0);
    if (joinPolicy === "open" && capacity > 0 && memberCount >= capacity) {
      throw new HttpsError("resource-exhausted", "This community is full.");
    }
    const role = joinPolicy === "approvalRequired" ? "pending" : "member";
    const now = Timestamp.now();
    transaction.set(memberRef, memberSnapshot(profile, role, now));
    if (role === "member") {
      transaction.update(communityRef, {
        memberCount: FieldValue.increment(1),
        updatedAt: now,
      });
    }
    return role;
  });
  await writeAuditEvent({
    actorId: uid,
    action: status === "pending" ?
      "sports.community_join_requested" : "sports.community_joined",
    targetType: "sport_community",
    targetId: communityId,
  });
  return {status};
});

export const leaveSportCommunity = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const communityId = requiredString(data.communityId, "Community", 120);
  const database = getFirestore();
  const communityRef = database.collection(collections.teams).doc(communityId);
  const memberRef = communityRef.collection("members").doc(uid);
  await database.runTransaction(async (transaction) => {
    const [community, member] = await Promise.all([
      transaction.get(communityRef),
      transaction.get(memberRef),
    ]);
    if (!community.exists || !member.exists || member.get("removedAt")) return;
    if (member.get("role") === "owner") {
      throw new HttpsError(
        "failed-precondition",
        "Transfer ownership before leaving this community.",
      );
    }
    const wasActive = member.get("status") === "active";
    const now = Timestamp.now();
    transaction.update(memberRef, {
      removedAt: now,
      status: "removed",
      updatedAt: now,
    });
    if (wasActive) {
      transaction.update(communityRef, {
        memberCount: FieldValue.increment(-1),
        updatedAt: now,
      });
    }
  });
  await writeAuditEvent({
    actorId: uid,
    action: "sports.community_left",
    targetType: "sport_community",
    targetId: communityId,
  });
  return {ok: true};
});

export const respondSportCommunityRequest = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const data = asRecord(request.data);
    const communityId = requiredString(data.communityId, "Community", 120);
    const userId = requiredString(data.userId, "User", 128);
    if (typeof data.approve !== "boolean") {
      throw new HttpsError("invalid-argument", "Decision is invalid.");
    }
    const approve = data.approve;
    await consumeRateLimit(uid, {
      key: "respond_sport_community_request",
      maxAttempts: 100,
      windowSeconds: 60 * 60,
    });
    const database = getFirestore();
    const communityRef = database.collection(collections.teams).doc(communityId);
    const managerRef = communityRef.collection("members").doc(uid);
    const targetRef = communityRef.collection("members").doc(userId);
    await database.runTransaction(async (transaction) => {
      const [community, manager, target] = await Promise.all([
        transaction.get(communityRef),
        transaction.get(managerRef),
        transaction.get(targetRef),
      ]);
      if (!community.exists || community.get("moderationState") !== "active") {
        throw new HttpsError("not-found", "This community is unavailable.");
      }
      const managerRole = String(manager.get("role") ?? "member");
      if (!manager.exists || manager.get("status") !== "active" ||
          (managerRole !== "owner" && managerRole !== "administrator")) {
        throw new HttpsError(
          "permission-denied",
          "Community manager access is required.",
        );
      }
      if (!target.exists || target.get("status") !== "pending" ||
          target.get("removedAt") !== null) {
        throw new HttpsError("failed-precondition", "This request is no longer pending.");
      }
      const now = Timestamp.now();
      if (approve) {
        const memberCount = Number(community.get("memberCount") ?? 0);
        const capacity = Number(community.get("capacity") ?? 0);
        if (capacity > 0 && memberCount >= capacity) {
          throw new HttpsError("resource-exhausted", "This community is full.");
        }
        transaction.update(targetRef, {
          role: "member",
          status: "active",
          removedAt: null,
          updatedAt: now,
        });
        transaction.update(communityRef, {
          memberCount: FieldValue.increment(1),
          updatedAt: now,
        });
      } else {
        transaction.update(targetRef, {
          status: "rejected",
          removedAt: now,
          updatedAt: now,
        });
      }
    });
    await writeAuditEvent({
      actorId: uid,
      action: approve ?
        "sports.community_request_approved" :
        "sports.community_request_rejected",
      targetType: "sport_community_member",
      targetId: `${communityId}:${userId}`,
    });
    return {ok: true};
  },
);

export const createSportsEvent = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseEventInput(request.data);
  await consumeRateLimit(uid, {
    key: "create_sports_event",
    maxAttempts: 20,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  await assertEnabledSport(database, input.sportId);
  const profile = await activeProfileSnapshot(database, uid);
  const now = Timestamp.now();
  const reference = database.collection(collections.events).doc();
  const batch = database.batch();
  batch.create(reference, {
    ownerId: uid,
    ownerSnapshot: profile,
    sportId: input.sportId,
    type: input.type,
    title: input.title,
    description: input.description,
    startAt: Timestamp.fromDate(input.startAt),
    endAt: Timestamp.fromDate(input.endAt),
    timezone: input.timezone,
    location: new GeoPoint(input.latitude, input.longitude),
    geohash: input.geohash,
    ...(input.locality ? {locality: input.locality} : {}),
    ...(input.administrativeArea ? {
      administrativeArea: input.administrativeArea,
    } : {}),
    ...(input.countryCode ? {countryCode: input.countryCode} : {}),
    ...(input.placeId ? {placeId: input.placeId} : {}),
    capacity: input.capacity,
    attendeeCount: 1,
    waitlistCount: 0,
    minimumLevel: input.minimumLevel,
    maximumLevel: input.maximumLevel,
    ...(input.price ? {price: input.price} : {}),
    visibility: "public",
    status: "published",
    moderationState: "active",
    media: [],
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  batch.create(reference.collection("attendees").doc(uid), {
    userId: uid,
    userSnapshot: profile,
    status: "attending",
    joinedAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  });
  await batch.commit();
  await writeAuditEvent({
    actorId: uid,
    action: "sports.event_created",
    targetType: "sports_event",
    targetId: reference.id,
    metadata: {sportId: input.sportId, type: input.type},
  });
  return {eventId: reference.id};
});

export const attendSportsEvent = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const eventId = requiredString(data.eventId, "Event", 120);
  await consumeRateLimit(uid, {
    key: "attend_sports_event",
    maxAttempts: 100,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const eventRef = database.collection(collections.events).doc(eventId);
  const attendeeRef = eventRef.collection("attendees").doc(uid);
  const profile = await activeProfileSnapshot(database, uid);
  const status = await database.runTransaction(async (transaction) => {
    const [event, attendee] = await Promise.all([
      transaction.get(eventRef),
      transaction.get(attendeeRef),
    ]);
    if (!event.exists || event.get("status") !== "published" ||
        event.get("moderationState") !== "active") {
      throw new HttpsError("not-found", "This event is unavailable.");
    }
    const endAt = event.get("endAt");
    if (endAt instanceof Timestamp && endAt.toMillis() <= Date.now()) {
      throw new HttpsError("failed-precondition", "This event has ended.");
    }
    const existing = String(attendee.get("status") ?? "none");
    if (attendee.exists && (existing === "attending" || existing === "waitlisted")) {
      return existing;
    }
    const attendeeCount = Number(event.get("attendeeCount") ?? 0);
    const capacity = Number(event.get("capacity") ?? 0);
    const nextStatus = capacity > 0 && attendeeCount >= capacity ?
      "waitlisted" : "attending";
    const now = Timestamp.now();
    transaction.set(attendeeRef, {
      userId: uid,
      userSnapshot: profile,
      status: nextStatus,
      joinedAt: attendee.exists ? attendee.get("joinedAt") ?? now : now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(eventRef, {
      [nextStatus === "attending" ? "attendeeCount" : "waitlistCount"]:
        FieldValue.increment(1),
      updatedAt: now,
    });
    return nextStatus;
  });
  await writeAuditEvent({
    actorId: uid,
    action: status === "waitlisted" ?
      "sports.event_waitlisted" : "sports.event_attending",
    targetType: "sports_event",
    targetId: eventId,
  });
  return {status};
});

export const leaveSportsEvent = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const eventId = requiredString(data.eventId, "Event", 120);
  const database = getFirestore();
  const eventRef = database.collection(collections.events).doc(eventId);
  const attendeeRef = eventRef.collection("attendees").doc(uid);
  let previousStatus = "none";
  await database.runTransaction(async (transaction) => {
    const waitlistQuery = eventRef.collection("attendees")
      .where("status", "==", "waitlisted")
      .orderBy("joinedAt")
      .limit(1);
    const [event, attendee, waitlist] = await Promise.all([
      transaction.get(eventRef),
      transaction.get(attendeeRef),
      transaction.get(waitlistQuery),
    ]);
    if (!event.exists || !attendee.exists) return;
    previousStatus = String(attendee.get("status") ?? "none");
    if (previousStatus !== "attending" && previousStatus !== "waitlisted") return;
    const now = Timestamp.now();
    transaction.update(attendeeRef, {status: "cancelled", updatedAt: now});
    if (previousStatus === "attending" && !waitlist.empty) {
      transaction.update(waitlist.docs[0].ref, {
        status: "attending",
        updatedAt: now,
      });
      transaction.update(eventRef, {
        waitlistCount: FieldValue.increment(-1),
        updatedAt: now,
      });
    } else {
      transaction.update(eventRef, {
        [previousStatus === "attending" ? "attendeeCount" : "waitlistCount"]:
          FieldValue.increment(-1),
        updatedAt: now,
      });
    }
  });
  await writeAuditEvent({
    actorId: uid,
    action: "sports.event_left",
    targetType: "sports_event",
    targetId: eventId,
    metadata: {previousStatus},
  });
  return {ok: true};
});

export const upsertTrainerService = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseTrainerServiceInput(request.data);
  await consumeRateLimit(uid, {
    key: "upsert_trainer_service",
    maxAttempts: 40,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  await assertEnabledSport(database, input.sportId);
  const profileRef = database.collection(collections.users).doc(uid);
  const profile = await profileRef.get();
  if (!profile.exists || profile.get("moderationState") !== "active") {
    throw new HttpsError("failed-precondition", "Your profile is unavailable.");
  }
  const verificationType = String(profile.get("verificationType") ?? "none");
  if (profile.get("isVerified") !== true ||
      (verificationType !== "trainer" && verificationType !== "business")) {
    throw new HttpsError(
      "permission-denied",
      "A verified trainer or business profile is required.",
    );
  }
  const professional = profile.get("professionalDetails");
  const professionalMap = typeofRecord(professional);
  const now = Timestamp.now();
  const trainerRef = database.collection(collections.trainerProfiles).doc(uid);
  const trainer = await trainerRef.get();
  const trainerCreatedAt = trainer.get("createdAt") instanceof Timestamp ?
    trainer.get("createdAt") as Timestamp : now;
  const existingMinimumPrice = typeofRecord(trainer.get("minimumPrice"));
  const existingAmount = typeof existingMinimumPrice.amountMinor === "number" ?
    existingMinimumPrice.amountMinor : Number.POSITIVE_INFINITY;
  const existingCurrency = typeof existingMinimumPrice.currency === "string" ?
    existingMinimumPrice.currency : input.price.currency;
  const minimumPrice = existingCurrency === input.price.currency &&
      existingAmount <= input.price.amountMinor ? existingMinimumPrice : input.price;
  const serviceRef = input.serviceId ?
    database.collection(collections.trainerServices).doc(input.serviceId) :
    database.collection(collections.trainerServices).doc();
  let serviceCreatedAt = now;
  if (input.serviceId) {
    const existing = await serviceRef.get();
    if (!existing.exists || existing.get("trainerId") !== uid) {
      throw new HttpsError("permission-denied", "This service is unavailable.");
    }
    const existingCreatedAt = existing.get("createdAt");
    if (existingCreatedAt instanceof Timestamp) serviceCreatedAt = existingCreatedAt;
  }
  const batch = database.batch();
  batch.set(trainerRef, {
    userId: uid,
    displayName: String(profile.get("displayName") ?? "Trainer"),
    username: String(profile.get("username") ?? ""),
    ...(profile.get("avatarUrl") ? {
      avatarUrl: String(profile.get("avatarUrl")),
    } : {}),
    bio: String(profile.get("bio") ?? ""),
    headline: String(professionalMap.headline ?? "Sport trainer"),
    sportIds: FieldValue.arrayUnion(input.sportId),
    specialties: Array.isArray(professionalMap.specialties) ?
      professionalMap.specialties : [],
    yearsExperience: Number(professionalMap.yearsExperience ?? 0),
    rating: 0,
    reviewCount: 0,
    city: String(profile.get("locality") ?? ""),
    countryCode: String(profile.get("countryCode") ?? ""),
    acceptingClients: true,
    isVerified: profile.get("isVerified") === true,
    minimumPrice,
    moderationState: "active",
    createdAt: trainerCreatedAt,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  }, {merge: true});
  batch.set(serviceRef, {
    trainerId: uid,
    sportId: input.sportId,
    title: input.title,
    description: input.description,
    type: input.type,
    deliveryMode: input.deliveryMode,
    durationMinutes: input.durationMinutes,
    price: input.price,
    isActive: true,
    moderationState: "active",
    createdAt: serviceCreatedAt,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  }, {merge: true});
  await batch.commit();
  await writeAuditEvent({
    actorId: uid,
    action: input.serviceId ?
      "sports.trainer_service_updated" : "sports.trainer_service_created",
    targetType: "trainer_service",
    targetId: serviceRef.id,
    metadata: {sportId: input.sportId},
  });
  return {serviceId: serviceRef.id};
});

function typeofRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value) ?
    value as Record<string, unknown> : {};
}
