import {GeoPoint, Timestamp, getFirestore} from "firebase-admin/firestore";
import {geohashForLocation} from "geofire-common";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

import {currentSchemaVersion, collections} from "../core/schema";
import {primaryRegion} from "../core/functionOptions";

type SourceKind = "place" | "person" | "event" | "route";

function text(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value.trim() : fallback;
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string =>
    typeof item === "string" && item.trim().length > 0) : [];
}

function geoPoint(value: unknown): GeoPoint | null {
  return value instanceof GeoPoint ? value : null;
}

function mediaImage(data: Record<string, unknown>): string | null {
  const media = Array.isArray(data.media) ? data.media : [];
  for (const item of media) {
    if (typeof item !== "object" || item === null) continue;
    const url = (item as Record<string, unknown>).downloadUrl;
    if (typeof url === "string" && url.length > 0) return url;
  }
  const imageUrl = data.imageUrl;
  return typeof imageUrl === "string" && imageUrl.length > 0 ? imageUrl : null;
}

async function writeIndex(
  kind: SourceKind,
  sourceId: string,
  data: Record<string, unknown> | null,
): Promise<void> {
  const database = getFirestore();
  const ref = database.collection(collections.nearbyEntities).doc(`${kind}_${sourceId}`);
  if (!data) {
    await ref.delete();
    return;
  }
  await ref.set({
    ...data,
    type: kind,
    sourceId,
    active: true,
    updatedAt: Timestamp.now(),
    schemaVersion: currentSchemaVersion,
  }, {merge: false});
}

export const syncNearbyPlace = onDocumentWritten({
  document: "places/{placeId}",
  region: primaryRegion,
}, async (event) => {
  const placeId = event.params.placeId;
  const snapshot = event.data?.after;
  if (!snapshot?.exists) return writeIndex("place", placeId, null);
  const data = snapshot.data() as Record<string, unknown>;
  const location = geoPoint(data.location);
  const visible = data.visibility === "public" && data.moderationState === "active";
  if (!visible || !location) return writeIndex("place", placeId, null);
  return writeIndex("place", placeId, {
    title: text(data.name, "Sports place"),
    subtitle: text(data.addressLine, text(data.city)),
    location,
    geohash: geohashForLocation([location.latitude, location.longitude]),
    sportIds: strings(data.sportIds),
    placeType: text(data.type, "other"),
    imageUrl: mediaImage(data),
    verified: data.isVerified === true,
    rating: typeof data.rating === "number" ? data.rating : 0,
    city: text(data.city),
    countryCode: text(data.countryCode).toUpperCase(),
    approximate: false,
  });
});

export const syncNearbyEvent = onDocumentWritten({
  document: "events/{eventId}",
  region: primaryRegion,
}, async (event) => {
  const eventId = event.params.eventId;
  const snapshot = event.data?.after;
  if (!snapshot?.exists) return writeIndex("event", eventId, null);
  const data = snapshot.data() as Record<string, unknown>;
  const location = geoPoint(data.location);
  const visible = data.status === "published" && data.moderationState === "active";
  if (!visible || !location) return writeIndex("event", eventId, null);
  return writeIndex("event", eventId, {
    title: text(data.title, "Sports event"),
    subtitle: text(data.locality, text(data.timezone)),
    location,
    geohash: geohashForLocation([location.latitude, location.longitude]),
    sportIds: [text(data.sportId)].filter(Boolean),
    eventType: text(data.type, "meetup"),
    ownerId: text(data.ownerId),
    imageUrl: mediaImage(data),
    startsAt: data.startAt ?? null,
    endsAt: data.endAt ?? null,
    capacity: typeof data.capacity === "number" ? data.capacity : 0,
    attendeeCount: typeof data.attendeeCount === "number" ? data.attendeeCount : 0,
    approximate: false,
  });
});

export const syncNearbyRoute = onDocumentWritten({
  document: "sports_routes/{routeId}",
  region: primaryRegion,
}, async (event) => {
  const routeId = event.params.routeId;
  const snapshot = event.data?.after;
  if (!snapshot?.exists) return writeIndex("route", routeId, null);
  const data = snapshot.data() as Record<string, unknown>;
  const location = geoPoint(data.startLocation);
  const visible = data.visibility === "public" && data.moderationState === "active";
  if (!visible || !location) return writeIndex("route", routeId, null);
  return writeIndex("route", routeId, {
    title: text(data.name, "Sports route"),
    ownerId: text(data.ownerId, "system"),
    subtitle: text(data.locality, text(data.city)),
    location,
    geohash: geohashForLocation([location.latitude, location.longitude]),
    sportIds: strings(data.sportIds),
    routeType: text(data.routeType, "loop"),
    imageUrl: typeof data.coverUrl === "string" ? data.coverUrl : null,
    distanceMeters: typeof data.distanceMeters === "number" ? data.distanceMeters : 0,
    elevationGainMeters: typeof data.elevationGainMeters === "number" ?
      data.elevationGainMeters : 0,
    difficulty: text(data.difficulty, "moderate"),
    path: Array.isArray(data.path) ? data.path.slice(0, 120) : [],
    verified: data.isVerified === true,
    approximate: false,
  });
});

async function syncPersonIndex(uid: string): Promise<void> {
  const database = getFirestore();
  const [snapshot, preferences, privateProfile] = await Promise.all([
    database.doc(`users/${uid}`).get(),
    database.doc(`users/${uid}/private/preferences`).get(),
    database.doc(`users/${uid}/private/profile`).get(),
  ]);
  if (!snapshot.exists) return writeIndex("person", uid, null);
  const data = snapshot.data() as Record<string, unknown>;
  const location = geoPoint(data.location);
  const publiclyVisible = data.visibility === "public" &&
    data.moderationState === "active" && data.onboardingCompleted === true;
  if (!publiclyVisible || !location) return writeIndex("person", uid, null);

  const discovery = preferences.get("discovery") as Record<string, unknown> | undefined;
  if (discovery?.showNearbyPeople !== true) return writeIndex("person", uid, null);
  const audienceSegment = privateProfile.get("isMinor") === true ? "minor" : "adult";
  const coarseLatitude = Math.round(location.latitude * 100) / 100;
  const coarseLongitude = Math.round(location.longitude * 100) / 100;
  const coarseLocation = new GeoPoint(coarseLatitude, coarseLongitude);
  return writeIndex("person", uid, {
    title: text(data.displayName, "ReeMove athlete"),
    subtitle: text(data.primarySportId, "Athlete"),
    username: text(data.username),
    location: coarseLocation,
    geohash: geohashForLocation([coarseLatitude, coarseLongitude]),
    sportIds: strings(data.favoriteSportIds),
    imageUrl: typeof data.avatarUrl === "string" ? data.avatarUrl : null,
    verified: data.isVerified === true,
    verificationType: text(data.verificationType, "none"),
    audienceSegment,
    approximate: true,
  });
}

export const syncNearbyPerson = onDocumentWritten({
  document: "users/{uid}",
  region: primaryRegion,
}, async (event) => syncPersonIndex(event.params.uid));

export const syncNearbyPersonPreferences = onDocumentWritten({
  document: "users/{uid}/private/preferences",
  region: primaryRegion,
}, async (event) => syncPersonIndex(event.params.uid));

export const syncNearbyPersonPrivateProfile = onDocumentWritten({
  document: "users/{uid}/private/profile",
  region: primaryRegion,
}, async (event) => syncPersonIndex(event.params.uid));
