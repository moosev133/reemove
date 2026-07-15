import {GeoPoint, Timestamp, getFirestore} from "firebase-admin/firestore";
import {distanceBetween, geohashQueryBounds} from "geofire-common";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections} from "../core/schema";
import {requireUid} from "../messaging/conversationAccess";
import {
  distanceLabel,
  parseDiscoveryLocation,
  parseNearbySearchInput,
} from "./nearbyPolicy";
import {encodeGeohash, roundCoordinate} from "../onboarding/geohash";

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string =>
    typeof item === "string") : [];
}

function serializeValue(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof GeoPoint) {
    return {latitude: value.latitude, longitude: value.longitude};
  }
  if (Array.isArray(value)) return value.map(serializeValue);
  if (typeof value === "object" && value !== null) {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>)
      .map(([key, item]) => [key, serializeValue(item)]));
  }
  return value;
}

export const searchNearby = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseNearbySearchInput(request.data);
  await consumeRateLimit(uid, {
    key: "nearby_search",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });

  const database = getFirestore();
  const [privateProfile, blocks, blockedBy] = await Promise.all([
    database.doc(`users/${uid}/private/profile`).get(),
    database.collection(collections.users).doc(uid).collection("blocks").get(),
    database.collection(collections.users).doc(uid).collection("blocked_by").get(),
  ]);
  const viewerSegment = privateProfile.get("isMinor") === true ? "minor" : "adult";
  const blockedIds = new Set([
    ...blocks.docs.map((item) => item.id),
    ...blockedBy.docs.map((item) => item.id),
  ]);
  const center: [number, number] = [input.latitude, input.longitude];
  const radiusMeters = input.radiusKm * 1000;
  const bounds = geohashQueryBounds(center, radiusMeters);
  const reference = database.collection(collections.nearbyEntities);
  const snapshots = await Promise.all(bounds.map(([start, end]) =>
    reference.orderBy("geohash").startAt(start).endAt(end).limit(120).get()));

  const now = Date.now();
  const seen = new Set<string>();
  const results: Array<Record<string, unknown>> = [];
  for (const snapshot of snapshots) {
    for (const document of snapshot.docs) {
      if (seen.has(document.id)) continue;
      seen.add(document.id);
      const data = document.data();
      if (data.active !== true || !input.types.includes(data.type)) continue;
      const sourceId = String(data.sourceId ?? "");
      const ownerId = String(data.ownerId ?? sourceId);
      if (!sourceId || sourceId === uid || blockedIds.has(ownerId)) continue;
      if (data.type === "person" && data.audienceSegment !== viewerSegment) continue;
      if (data.type === "event") {
        const endsAt = data.endsAt instanceof Timestamp ? data.endsAt.toMillis() : 0;
        if (endsAt > 0 && endsAt < now) continue;
      }
      const sportIds = strings(data.sportIds);
      if (input.sportIds.length > 0 &&
          !sportIds.some((sportId) => input.sportIds.includes(sportId))) continue;
      const point = data.location;
      if (!(point instanceof GeoPoint)) continue;
      const distanceKm = distanceBetween(
        [point.latitude, point.longitude],
        center,
      );
      if (distanceKm > input.radiusKm) continue;
      const approximate = data.approximate === true;
      const item = serializeValue({
        id: document.id,
        ...data,
        distanceKm: approximate ? Math.max(1, Math.round(distanceKm)) :
          Math.round(distanceKm * 10) / 10,
        distanceLabel: distanceLabel(distanceKm, approximate),
      }) as Record<string, unknown>;
      delete item.audienceSegment;
      delete item.active;
      results.push(item);
    }
  }

  results.sort((left, right) =>
    Number(left.distanceKm ?? 0) - Number(right.distanceKm ?? 0));
  return {
    items: results.slice(0, input.limit),
    center: {latitude: input.latitude, longitude: input.longitude},
    radiusKm: input.radiusKm,
    generatedAt: new Date().toISOString(),
  };
});

export const updateDiscoveryLocation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const input = parseDiscoveryLocation(request.data);
  await consumeRateLimit(uid, {
    key: "update_discovery_location",
    maxAttempts: 20,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const userRef = database.collection(collections.users).doc(uid);
  const preferencesRef = userRef.collection("private").doc("preferences");
  const now = Timestamp.now();
  const coarseLatitude = roundCoordinate(input.latitude);
  const coarseLongitude = roundCoordinate(input.longitude);
  const publicLocation = new GeoPoint(coarseLatitude, coarseLongitude);
  const exactLocation = new GeoPoint(input.latitude, input.longitude);
  const sharedFields = {
    ...(input.locality ? {locality: input.locality} : {}),
    ...(input.administrativeArea ? {
      administrativeArea: input.administrativeArea,
    } : {}),
    ...(input.countryCode ? {countryCode: input.countryCode} : {}),
  };
  await database.runTransaction(async (transaction) => {
    const user = await transaction.get(userRef);
    if (!user.exists || user.get("moderationState") !== "active") {
      throw new HttpsError("failed-precondition", "Your profile is unavailable.");
    }
    transaction.update(userRef, {
      location: publicLocation,
      geohash: encodeGeohash(coarseLatitude, coarseLongitude, 6),
      ...sharedFields,
      updatedAt: now,
    });
    transaction.set(preferencesRef, {
      locationPermission: "granted",
      exactLocation: {
        location: exactLocation,
        geohash: encodeGeohash(input.latitude, input.longitude, 9),
        ...sharedFields,
        capturedAt: now,
      },
      updatedAt: now,
    }, {merge: true});
  });
  await writeAuditEvent({
    actorId: uid,
    action: "nearby.location_updated",
    targetType: "user",
    targetId: uid,
    metadata: {countryCode: input.countryCode ?? "unknown"},
  });
  return {ok: true, updatedAt: now.toDate().toISOString()};
});
