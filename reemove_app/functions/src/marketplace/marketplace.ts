import {getDatabase} from "firebase-admin/database";
import {
  FieldValue,
  GeoPoint,
  getFirestore,
  Timestamp,
  type DocumentData,
  type DocumentSnapshot,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {
  activeProfileSnapshot,
  assertUsersCanMessage,
  requireUid,
} from "../messaging/conversationAccess";
import {directConversationId} from "../messaging/messagingPolicy";
import {
  asRecord,
  distanceKm,
  hasProhibitedMarketplaceLanguage,
  listingActions,
  listingStatuses,
  normalizeMarketplaceSearchText,
  optionalText,
  parseListingInput,
  parseSearchRequest,
  reportReasons,
  safeId,
  searchPrefixes,
  type ListingInput,
} from "./marketplacePolicy";

const marketplaceListings = "marketplace_listings";
const marketplaceReports = "marketplace_reports";
const marketplaceViews = "marketplace_views";
const marketplaceThreads = "marketplace_threads";

function sellerSnapshot(profile: Record<string, unknown>, uid: string): Record<string, unknown> {
  return {
    uid,
    username: String(profile.username ?? ""),
    displayName: String(profile.displayName ?? "Athlete"),
    ...(profile.avatarUrl ? {avatarUrl: String(profile.avatarUrl)} : {}),
    isVerified: profile.isVerified === true,
    verificationType: String(profile.verificationType ?? "none"),
  };
}

function mediaMap(input: ListingInput["media"]): Record<string, unknown>[] {
  return input.map((item) => ({
    id: item.id,
    storagePath: item.storagePath,
    kind: "image",
    processingState: "ready",
    downloadUrl: item.downloadUrl,
    contentType: item.contentType,
    sizeBytes: item.sizeBytes,
  }));
}

async function verifyListingMedia(
  uid: string,
  listingId: string,
  media: ListingInput["media"],
): Promise<void> {
  const bucket = getStorage().bucket();
  for (const item of media) {
    const prefix = `marketplace/${uid}/${listingId}/`;
    if (!item.storagePath.startsWith(prefix)) {
      throw new HttpsError("permission-denied", "A listing photo is not owned by your account.");
    }
    try {
      const [metadata] = await bucket.file(item.storagePath).getMetadata();
      const custom = metadata.metadata ?? {};
      if (custom.ownerId !== uid || custom.listingId !== listingId ||
          custom.assetId !== item.id || custom.schemaVersion !== "1" ||
          !String(metadata.contentType ?? "").startsWith("image/") ||
          Number(metadata.size ?? 0) <= 0 || Number(metadata.size ?? 0) > 15 * 1024 * 1024) {
        throw new Error("metadata mismatch");
      }
    } catch {
      throw new HttpsError("failed-precondition", "A listing photo could not be verified.");
    }
  }
}

async function deleteRemovedListingMedia(
  previousMedia: unknown,
  nextMedia: ListingInput["media"],
): Promise<void> {
  if (!Array.isArray(previousMedia)) return;
  const retained = new Set(nextMedia.map((item) => item.storagePath));
  const removed = previousMedia
    .map((item) => asRecord(item, "media item"))
    .map((item) => String(item.storagePath ?? ""))
    .filter((path) => path.length > 0 && !retained.has(path));
  await Promise.allSettled(removed.map((path) => getStorage().bucket().file(path).delete()));
}

async function assertEnabledCatalogValues(
  database: Firestore,
  input: ListingInput,
): Promise<void> {
  const [sport, category] = await Promise.all([
    database.collection(collections.sports).doc(input.sportId).get(),
    database.collection("marketplace_categories").doc(input.categoryId).get(),
  ]);
  if (!sport.exists || sport.get("isEnabled") !== true) {
    throw new HttpsError("failed-precondition", "This sport is unavailable.");
  }
  if (!category.exists || category.get("isActive") !== true) {
    throw new HttpsError("failed-precondition", "This marketplace category is unavailable.");
  }
  const supportedSports = category.get("sportIds");
  if (Array.isArray(supportedSports) && supportedSports.length > 0 &&
      !supportedSports.includes(input.sportId)) {
    throw new HttpsError("invalid-argument", "This category does not support the selected sport.");
  }
}

function listingWriteData(
  input: ListingInput,
  seller: Record<string, unknown>,
  uid: string,
): Record<string, unknown> {
  return {
    sellerId: uid,
    seller: sellerSnapshot(seller, uid),
    title: input.title,
    description: input.description,
    categoryId: input.categoryId,
    sportId: input.sportId,
    condition: input.condition,
    price: input.price,
    media: mediaMap(input.media),
    location: new GeoPoint(input.location.latitude, input.location.longitude),
    geohash: input.geohash,
    ...(input.locality ? {locality: input.locality} : {}),
    ...(input.administrativeArea ? {administrativeArea: input.administrativeArea} : {}),
    ...(input.countryCode ? {countryCode: input.countryCode} : {}),
    deliveryOptions: input.deliveryOptions,
    isNegotiable: input.isNegotiable,
    searchPrefixes: searchPrefixes(input.title, input.description),
    moderationState: "active",
    schemaVersion: currentSchemaVersion,
  };
}

function requireOwnedListing(
  snapshot: DocumentSnapshot<DocumentData>,
  uid: string,
): void {
  if (!snapshot.exists || snapshot.get("sellerId") !== uid) {
    throw new HttpsError("not-found", "This listing is unavailable.");
  }
}

function listingAvailable(snapshot: DocumentSnapshot<DocumentData>): boolean {
  if (!snapshot.exists || snapshot.get("moderationState") !== "active" ||
      !["active", "reserved"].includes(String(snapshot.get("status")))) {
    return false;
  }
  const expiresAt = snapshot.get("expiresAt");
  return !(expiresAt instanceof Timestamp) || expiresAt.toMillis() > Date.now();
}

async function isBlockedBetween(
  database: Firestore,
  viewerId: string,
  sellerId: string,
): Promise<boolean> {
  if (viewerId === sellerId) return false;
  const [viewerBlock, sellerBlock] = await Promise.all([
    database.doc(`users/${viewerId}/blocks/${sellerId}`).get(),
    database.doc(`users/${sellerId}/blocks/${viewerId}`).get(),
  ]);
  return viewerBlock.exists || sellerBlock.exists;
}

async function blockedMarketplaceSellerIds(
  database: Firestore,
  uid: string,
): Promise<Set<string>> {
  const [blocked, blockedBy] = await Promise.all([
    database.doc(`users/${uid}`).collection("blocks").limit(500).get(),
    database.doc(`users/${uid}`).collection("blocked_by").limit(500).get(),
  ]);
  return new Set<string>([
    ...blocked.docs.map((item) => item.id),
    ...blockedBy.docs.map((item) => item.id),
  ]);
}

async function assertListingVisibleTo(
  database: Firestore,
  listing: DocumentSnapshot<DocumentData>,
  uid: string,
): Promise<void> {
  if (!listingAvailable(listing) ||
      await isBlockedBetween(database, uid, String(listing.get("sellerId") ?? ""))) {
    throw new HttpsError("not-found", "This listing is unavailable.");
  }
}

function timestampIso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

function serializableListing(
  document: QueryDocumentSnapshot<DocumentData> | DocumentSnapshot<DocumentData>,
  isFavorited: boolean,
  calculatedDistanceKm?: number,
): Record<string, unknown> {
  const data = document.data() ?? {};
  const point = data.location;
  return {
    id: document.id,
    ...data,
    location: point instanceof GeoPoint ? {
      latitude: point.latitude,
      longitude: point.longitude,
    } : point,
    isFavorited,
    ...(calculatedDistanceKm === undefined ? {} : {
      distanceKm: Math.round(calculatedDistanceKm * 10) / 10,
    }),
    createdAt: timestampIso(data.createdAt),
    updatedAt: timestampIso(data.updatedAt),
    publishedAt: timestampIso(data.publishedAt),
    expiresAt: timestampIso(data.expiresAt),
    reservedAt: timestampIso(data.reservedAt),
    soldAt: timestampIso(data.soldAt),
  };
}

async function favoriteIdsFor(
  database: Firestore,
  uid: string,
  ids: string[],
): Promise<Set<string>> {
  if (ids.length === 0) return new Set<string>();
  const snapshots = await database.getAll(...ids.map((id) =>
    database.doc(`users/${uid}/marketplace_favorites/${id}`),
  ));
  return new Set(snapshots.filter((item) => item.exists).map((item) => item.id));
}

function compareListings(
  first: {snapshot: QueryDocumentSnapshot<DocumentData>; distance?: number},
  second: {snapshot: QueryDocumentSnapshot<DocumentData>; distance?: number},
  sort: string,
): number {
  if (sort === "nearest") return (first.distance ?? Infinity) - (second.distance ?? Infinity);
  const firstPrice = Number(first.snapshot.get("price.amountMinor") ??
    (first.snapshot.get("price") as Record<string, unknown> | undefined)?.amountMinor ?? 0);
  const secondPrice = Number(second.snapshot.get("price.amountMinor") ??
    (second.snapshot.get("price") as Record<string, unknown> | undefined)?.amountMinor ?? 0);
  if (sort === "priceLowToHigh") return firstPrice - secondPrice;
  if (sort === "priceHighToLow") return secondPrice - firstPrice;
  const firstDate = first.snapshot.get("publishedAt");
  const secondDate = second.snapshot.get("publishedAt");
  const firstMillis = firstDate instanceof Timestamp ? firstDate.toMillis() : 0;
  const secondMillis = secondDate instanceof Timestamp ? secondDate.toMillis() : 0;
  return secondMillis - firstMillis || first.snapshot.id.localeCompare(second.snapshot.id);
}

export const createMarketplaceListing = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  await consumeRateLimit(uid, {
    key: "marketplace_create_listing",
    maxAttempts: 20,
    windowSeconds: 24 * 60 * 60,
  });
  const input = parseListingInput(request.data);
  const database = getFirestore();
  await assertEnabledCatalogValues(database, input);
  const profile = await activeProfileSnapshot(database, uid);
  const listingRef = input.listingId ?
    database.collection(marketplaceListings).doc(input.listingId) :
    database.collection(marketplaceListings).doc();
  const existing = await listingRef.get();
  if (existing.exists) throw new HttpsError("already-exists", "This listing already exists.");
  await verifyListingMedia(uid, listingRef.id, input.media);
  const now = Timestamp.now();
  await listingRef.create({
    ...listingWriteData(input, profile, uid),
    status: "draft",
    favoriteCount: 0,
    viewCount: 0,
    conversationCount: 0,
    createdAt: now,
    updatedAt: now,
  });
  await writeAuditEvent({
    actorId: uid,
    action: "marketplace.listing_created",
    targetType: "marketplace_listing",
    targetId: listingRef.id,
  });
  return {listingId: listingRef.id};
});

export const updateMarketplaceListing = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  await consumeRateLimit(uid, {
    key: "marketplace_update_listing",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });
  const input = parseListingInput(request.data);
  if (!input.listingId) throw new HttpsError("invalid-argument", "Listing id is required.");
  const database = getFirestore();
  await assertEnabledCatalogValues(database, input);
  const ref = database.collection(marketplaceListings).doc(input.listingId);
  const [listing, profile] = await Promise.all([
    ref.get(),
    activeProfileSnapshot(database, uid),
  ]);
  requireOwnedListing(listing, uid);
  if (!["draft", "paused", "rejected", "expired"].includes(String(listing.get("status")))) {
    throw new HttpsError(
      "failed-precondition",
      "Only draft, paused, rejected, or expired listings can be edited.",
    );
  }
  await verifyListingMedia(uid, ref.id, input.media);
  const previousMedia = listing.get("media");
  await ref.update({
    ...listingWriteData(input, profile, uid),
    status: "draft",
    rejectionReason: FieldValue.delete(),
    reservedAt: FieldValue.delete(),
    pausedAt: FieldValue.delete(),
    soldAt: FieldValue.delete(),
    updatedAt: Timestamp.now(),
  });
  await deleteRemovedListingMedia(previousMedia, input.media);
  return {ok: true};
});

export const publishMarketplaceListing = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const listingId = safeId(data.listingId, "Listing id");
  await consumeRateLimit(uid, {
    key: "marketplace_publish_listing",
    maxAttempts: 30,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const ref = database.collection(marketplaceListings).doc(listingId);
  const listing = await ref.get();
  requireOwnedListing(listing, uid);
  if (!["draft", "rejected", "expired"].includes(String(listing.get("status")))) {
    throw new HttpsError("failed-precondition", "This listing cannot be published.");
  }
  const media = listing.get("media");
  if (!Array.isArray(media) || media.length === 0 || media.length > 8) {
    throw new HttpsError("failed-precondition", "Add at least one verified photo.");
  }
  if (hasProhibitedMarketplaceLanguage(
    String(listing.get("title") ?? ""),
    String(listing.get("description") ?? ""),
  )) {
    throw new HttpsError("failed-precondition", "This item cannot be listed in ReeMove Marketplace.");
  }
  const normalizedMedia = media.map((item) => asRecord(item, "media item")).map((item) => ({
    id: String(item.id ?? ""),
    storagePath: String(item.storagePath ?? ""),
    downloadUrl: String(item.downloadUrl ?? ""),
    contentType: String(item.contentType ?? "image/jpeg"),
    sizeBytes: Number(item.sizeBytes ?? 0),
  }));
  await verifyListingMedia(uid, listingId, normalizedMedia);
  const now = Timestamp.now();
  await database.runTransaction(async (transaction) => {
    const latest = await transaction.get(ref);
    requireOwnedListing(latest, uid);
    if (!["draft", "rejected", "expired"].includes(String(latest.get("status")))) {
      throw new HttpsError("aborted", "The listing changed. Refresh and try again.");
    }
    transaction.update(ref, {
      status: "active",
      moderationState: "active",
      rejectionReason: FieldValue.delete(),
      publishedAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 60 * 24 * 60 * 60 * 1000),
      updatedAt: now,
    });
    transaction.set(database.doc(`users/${uid}/private/marketplace_stats`), {
      activeListingCount: FieldValue.increment(1),
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  });
  await writeAuditEvent({
    actorId: uid,
    action: "marketplace.listing_published",
    targetType: "marketplace_listing",
    targetId: listingId,
  });
  return {ok: true};
});

export const changeMarketplaceListingStatus = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const listingId = safeId(data.listingId, "Listing id");
  const action = String(data.action ?? "");
  if (!listingActions.includes(action as typeof listingActions[number])) {
    throw new HttpsError("invalid-argument", "The listing action is invalid.");
  }
  await consumeRateLimit(uid, {
    key: "marketplace_change_status",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const ref = database.collection(marketplaceListings).doc(listingId);
  const now = Timestamp.now();
  if (action === "activate") {
    const currentListing = await ref.get();
    requireOwnedListing(currentListing, uid);
    if (String(currentListing.get("status")) === "expired") {
      const media = currentListing.get("media");
      if (!Array.isArray(media) || media.length === 0 || media.length > 8) {
        throw new HttpsError("failed-precondition", "Add at least one verified photo.");
      }
      const normalizedMedia = media.map((item) => asRecord(item, "media item")).map((item) => ({
        id: String(item.id ?? ""),
        storagePath: String(item.storagePath ?? ""),
        downloadUrl: String(item.downloadUrl ?? ""),
        contentType: String(item.contentType ?? "image/jpeg"),
        sizeBytes: Number(item.sizeBytes ?? 0),
      }));
      await verifyListingMedia(uid, listingId, normalizedMedia);
    }
  }
  await database.runTransaction(async (transaction) => {
    const listing = await transaction.get(ref);
    requireOwnedListing(listing, uid);
    const current = String(listing.get("status"));
    let next: string;
    if (action === "reserve" && current === "active") next = "reserved";
    else if (action === "sold" && ["active", "reserved"].includes(current)) next = "sold";
    else if (action === "pause" && ["active", "reserved"].includes(current)) next = "paused";
    else if (action === "remove" && ["active", "paused", "reserved", "draft", "rejected", "expired"].includes(current)) next = "removed";
    else if (action === "activate" && ["paused", "reserved", "expired"].includes(current)) next = "active";
    else throw new HttpsError("failed-precondition", "This status change is not allowed.");
    const currentExpiry = listing.get("expiresAt");
    const refreshExpiry = next === "active" && (
      current === "expired" ||
      (current === "paused" && currentExpiry instanceof Timestamp &&
        currentExpiry.toMillis() <= now.toMillis())
    );
    transaction.update(ref, {
      status: next,
      ...(next === "reserved" ? {reservedAt: now} : {}),
      ...(next === "paused" ? {pausedAt: now, reservedAt: FieldValue.delete()} : {}),
      ...(next === "sold" ? {soldAt: now} : {}),
      ...(next === "active" ? {
        reservedAt: FieldValue.delete(),
        pausedAt: FieldValue.delete(),
      } : {}),
      ...(refreshExpiry ? {
        publishedAt: now,
        expiresAt: Timestamp.fromMillis(now.toMillis() + 60 * 24 * 60 * 60 * 1000),
      } : {}),
      updatedAt: now,
    });
    const wasActive = ["active", "reserved"].includes(current);
    const remainsActive = ["active", "reserved"].includes(next);
    const stats: Record<string, unknown> = {
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    };
    if (wasActive !== remainsActive) {
      stats.activeListingCount = FieldValue.increment(remainsActive ? 1 : -1);
    }
    if (next === "sold" && current !== "sold") {
      stats.soldListingCount = FieldValue.increment(1);
    }
    transaction.set(database.doc(`users/${uid}/private/marketplace_stats`), stats, {merge: true});
  });
  await writeAuditEvent({
    actorId: uid,
    action: `marketplace.listing_${action}`,
    targetType: "marketplace_listing",
    targetId: listingId,
  });
  return {ok: true};
});

export const searchMarketplace = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const parsed = parseSearchRequest(request.data);
  await consumeRateLimit(uid, {
    key: "marketplace_search",
    maxAttempts: 240,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  let query = database.collection(marketplaceListings)
    .where("status", "==", "active")
    .where("moderationState", "==", "active")
    .orderBy("publishedAt", "desc")
    .limit(300);
  const [snapshot, blockedSellerIds] = await Promise.all([
    query.get(),
    blockedMarketplaceSellerIds(database, uid),
  ]);
  const now = Timestamp.now();
  const normalizedQuery = normalizeMarketplaceSearchText(parsed.query);
  const candidates = snapshot.docs.map((item) => {
    const point = item.get("location");
    const distance = parsed.latitude !== undefined && parsed.longitude !== undefined &&
      point instanceof GeoPoint ? distanceKm(
        parsed.latitude,
        parsed.longitude,
        point.latitude,
        point.longitude,
      ) : undefined;
    return {snapshot: item, distance};
  }).filter(({snapshot: item, distance}) => {
    if (blockedSellerIds.has(String(item.get("sellerId") ?? ""))) return false;
    const expiresAt = item.get("expiresAt");
    if (expiresAt instanceof Timestamp && expiresAt.toMillis() <= now.toMillis()) return false;
    if (parsed.sportId && item.get("sportId") !== parsed.sportId) return false;
    if (parsed.categoryId && item.get("categoryId") !== parsed.categoryId) return false;
    if (parsed.condition && item.get("condition") !== parsed.condition) return false;
    const priceMap = item.get("price");
    const amount = typeof priceMap === "object" && priceMap !== null ?
      Number((priceMap as Record<string, unknown>).amountMinor ?? 0) : 0;
    if (parsed.minimumPriceMinor !== undefined && amount < parsed.minimumPriceMinor) return false;
    if (parsed.maximumPriceMinor !== undefined && amount > parsed.maximumPriceMinor) return false;
    const delivery = item.get("deliveryOptions");
    if (parsed.deliveryOptions.length > 0 &&
        (!Array.isArray(delivery) || !parsed.deliveryOptions.every((option) => delivery.includes(option)))) {
      return false;
    }
    if (distance !== undefined && distance > parsed.radiusKm) return false;
    if (normalizedQuery) {
      const prefixes = item.get("searchPrefixes");
      const words = normalizedQuery.split(/\s+/)
        .filter((word) => word.length >= 2)
        .map((word) => word.slice(0, 16));
      if (!Array.isArray(prefixes) || !words.every((word) => prefixes.includes(word))) return false;
    }
    return true;
  });
  candidates.sort((a, b) => compareListings(a, b, parsed.sort));
  const page = candidates.slice(parsed.cursor, parsed.cursor + parsed.limit);
  const favorites = await favoriteIdsFor(database, uid, page.map((item) => item.snapshot.id));
  const nextOffset = parsed.cursor + page.length;
  return {
    items: page.map((item) => serializableListing(
      item.snapshot,
      favorites.has(item.snapshot.id),
      item.distance,
    )),
    hasMore: nextOffset < candidates.length,
    ...(nextOffset < candidates.length ? {nextCursor: String(nextOffset)} : {}),
  };
});

async function loadListingsPage(input: {
  uid: string;
  sellerId: string;
  status?: string;
  cursor: number;
  limit: number;
  ownerView: boolean;
}): Promise<Record<string, unknown>> {
  const database = getFirestore();
  if (!input.ownerView && await isBlockedBetween(database, input.uid, input.sellerId)) {
    throw new HttpsError("not-found", "This seller is unavailable.");
  }
  let query = database.collection(marketplaceListings)
    .where("sellerId", "==", input.sellerId)
    .orderBy("updatedAt", "desc")
    .limit(160);
  const snapshot = await query.get();
  const allowedPublic = new Set(["active", "reserved", "sold"]);
  const filtered = snapshot.docs.filter((item) => {
    const status = String(item.get("status"));
    if (input.status && status !== input.status) return false;
    return input.ownerView || (allowedPublic.has(status) && item.get("moderationState") === "active");
  });
  const page = filtered.slice(input.cursor, input.cursor + input.limit);
  const favorites = await favoriteIdsFor(database, input.uid, page.map((item) => item.id));
  const nextOffset = input.cursor + page.length;
  return {
    items: page.map((item) => serializableListing(item, favorites.has(item.id))),
    hasMore: nextOffset < filtered.length,
    ...(nextOffset < filtered.length ? {nextCursor: String(nextOffset)} : {}),
  };
}

function parseListPageRequest(value: unknown): {cursor: number; limit: number; status?: string} {
  const data = asRecord(value);
  const cursor = data.cursor === undefined ? 0 : Number.parseInt(String(data.cursor), 10);
  const limit = data.limit === undefined ? 24 : Number(data.limit);
  const status = data.status === undefined ? undefined : String(data.status);
  if (!Number.isInteger(cursor) || cursor < 0 || !Number.isInteger(limit) || limit < 1 || limit > 40 ||
      (status !== undefined && !listingStatuses.includes(status as typeof listingStatuses[number]))) {
    throw new HttpsError("invalid-argument", "The listing page request is invalid.");
  }
  return {cursor, limit, status};
}

export const loadMarketplaceSellerListings = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const sellerId = safeId(data.sellerId, "Seller id");
  const page = parseListPageRequest(data);
  return loadListingsPage({
    uid,
    sellerId,
    status: page.status,
    cursor: page.cursor,
    limit: page.limit,
    ownerView: sellerId === uid,
  });
});

export const loadMarketplaceFavorites = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const page = parseListPageRequest(request.data);
  const database = getFirestore();
  const favoriteSnapshot = await database.doc(`users/${uid}`).collection("marketplace_favorites")
    .orderBy("createdAt", "desc").limit(200).get();
  const visibleFavorites = favoriteSnapshot.docs.slice(page.cursor, page.cursor + page.limit);
  const [listingSnapshots, blockedSellerIds] = await Promise.all([
    visibleFavorites.length === 0 ? Promise.resolve([]) : database.getAll(
      ...visibleFavorites.map((item) => database.collection(marketplaceListings).doc(item.id)),
    ),
    blockedMarketplaceSellerIds(database, uid),
  ]);
  const items = listingSnapshots
    .filter((item) => listingAvailable(item) &&
      !blockedSellerIds.has(String(item.get("sellerId") ?? "")))
    .map((item) => serializableListing(item, true));
  const nextOffset = page.cursor + visibleFavorites.length;
  return {
    items,
    hasMore: nextOffset < favoriteSnapshot.docs.length,
    ...(nextOffset < favoriteSnapshot.docs.length ? {nextCursor: String(nextOffset)} : {}),
  };
});

export const loadMyMarketplaceListings = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const page = parseListPageRequest(request.data);
  return loadListingsPage({
    uid,
    sellerId: uid,
    status: page.status,
    cursor: page.cursor,
    limit: page.limit,
    ownerView: true,
  });
});

export const getMarketplaceSeller = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const sellerId = safeId(data.sellerId, "Seller id");
  const database = getFirestore();
  const [profile, stats, privacy] = await Promise.all([
    database.collection(collections.users).doc(sellerId).get(),
    database.doc(`users/${sellerId}/private/marketplace_stats`).get(),
    database.doc(`users/${sellerId}/private/profile_settings`).get(),
  ]);
  if (!profile.exists || profile.get("moderationState") !== "active" ||
      profile.get("onboardingCompleted") !== true) {
    throw new HttpsError("not-found", "This seller is unavailable.");
  }
  if (await isBlockedBetween(database, uid, sellerId)) {
    throw new HttpsError("not-found", "This seller is unavailable.");
  }
  const createdAt = profile.get("createdAt");
  return {
    seller: {
      uid: sellerId,
      username: String(profile.get("username") ?? ""),
      displayName: String(profile.get("displayName") ?? "Athlete"),
      ...(profile.get("avatarUrl") ? {avatarUrl: String(profile.get("avatarUrl"))} : {}),
      isVerified: profile.get("isVerified") === true,
      verificationType: String(profile.get("verificationType") ?? "none"),
      ...((uid === sellerId || privacy.get("showLocation") !== false) &&
        profile.get("location") && profile.get("locality") ? {
          locality: String(profile.get("locality")),
        } : {}),
      activeListingCount: Math.max(0, Number(stats.get("activeListingCount") ?? 0)),
      soldListingCount: Math.max(0, Number(stats.get("soldListingCount") ?? 0)),
      memberSince: createdAt instanceof Timestamp ? createdAt.toDate().toISOString() : new Date(0).toISOString(),
    },
  };
});

export const toggleMarketplaceFavorite = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const listingId = safeId(asRecord(request.data).listingId, "Listing id");
  await consumeRateLimit(uid, {
    key: "marketplace_favorite",
    maxAttempts: 240,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const listingRef = database.collection(marketplaceListings).doc(listingId);
  await assertListingVisibleTo(database, await listingRef.get(), uid);
  const favoriteRef = database.doc(`users/${uid}/marketplace_favorites/${listingId}`);
  let isFavorited = false;
  await database.runTransaction(async (transaction) => {
    const [listing, favorite] = await Promise.all([
      transaction.get(listingRef),
      transaction.get(favoriteRef),
    ]);
    if (!listingAvailable(listing)) throw new HttpsError("not-found", "This listing is unavailable.");
    isFavorited = !favorite.exists;
    if (isFavorited) {
      transaction.create(favoriteRef, {
        userId: uid,
        listingId,
        sellerId: listing.get("sellerId"),
        createdAt: Timestamp.now(),
        schemaVersion: currentSchemaVersion,
      });
    } else {
      transaction.delete(favoriteRef);
    }
    const currentFavoriteCount = Math.max(0, Number(listing.get("favoriteCount") ?? 0));
    transaction.update(listingRef, {
      favoriteCount: Math.max(0, currentFavoriteCount + (isFavorited ? 1 : -1)),
      updatedAt: Timestamp.now(),
    });
  });
  return {isFavorited};
});

export const recordMarketplaceView = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const listingId = safeId(asRecord(request.data).listingId, "Listing id");
  const database = getFirestore();
  const listingRef = database.collection(marketplaceListings).doc(listingId);
  await assertListingVisibleTo(database, await listingRef.get(), uid);
  const viewRef = database.collection(marketplaceViews).doc(`${uid}--${listingId}`);
  await database.runTransaction(async (transaction) => {
    const [listing, view] = await Promise.all([
      transaction.get(listingRef),
      transaction.get(viewRef),
    ]);
    if (!listingAvailable(listing)) throw new HttpsError("not-found", "This listing is unavailable.");
    if (view.exists) return;
    transaction.create(viewRef, {
      userId: uid,
      listingId,
      sellerId: listing.get("sellerId"),
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 180 * 24 * 60 * 60 * 1000),
      schemaVersion: currentSchemaVersion,
    });
    transaction.update(listingRef, {
      viewCount: FieldValue.increment(1),
    });
  });
  return {ok: true};
});

export const reportMarketplaceListing = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const data = asRecord(request.data);
  const listingId = safeId(data.listingId, "Listing id");
  const reason = String(data.reason ?? "");
  if (!reportReasons.includes(reason as typeof reportReasons[number])) {
    throw new HttpsError("invalid-argument", "The report reason is invalid.");
  }
  const details = optionalText(data.details, "Report details", 1000) ?? "";
  await consumeRateLimit(uid, {
    key: "marketplace_report",
    maxAttempts: 20,
    windowSeconds: 24 * 60 * 60,
  });
  const database = getFirestore();
  const listing = await database.collection(marketplaceListings).doc(listingId).get();
  if (!listing.exists || listing.get("sellerId") === uid) {
    throw new HttpsError("failed-precondition", "This listing cannot be reported.");
  }
  await assertListingVisibleTo(database, listing, uid);
  const reportId = `${uid}--${listingId}`;
  const reportRef = database.collection(marketplaceReports).doc(reportId);
  const queueRef = database.collection(collections.moderationQueue)
    .doc(`marketplace--${listingId}`);
  const now = Timestamp.now();
  let created = false;
  await database.runTransaction(async (transaction) => {
    const existing = await transaction.get(reportRef);
    if (existing.exists) return;
    created = true;
    transaction.create(reportRef, {
      reporterId: uid,
      listingId,
      sellerId: listing.get("sellerId"),
      reason,
      details,
      status: "open",
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    transaction.set(queueRef, {
      targetType: "marketplace_listing",
      targetId: listingId,
      reportCount: FieldValue.increment(1),
      latestReason: reason,
      status: "open",
      updatedAt: now,
      createdAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  });
  if (created) {
    await writeAuditEvent({
      actorId: uid,
      action: "marketplace.listing_reported",
      targetType: "marketplace_listing",
      targetId: listingId,
      metadata: {reason},
    });
  }
  return {ok: true, alreadyReported: !created};
});

export const reviewMarketplaceListing = onCall(callableOptions, async (request) => {
  const reviewerId = requireUid(request.auth?.uid);
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
  const data = asRecord(request.data);
  const listingId = safeId(data.listingId, "Listing id");
  const decision = String(data.decision ?? "");
  if (!["keep", "remove"].includes(decision)) {
    throw new HttpsError("invalid-argument", "The moderation decision is invalid.");
  }
  const reason = optionalText(data.reason, "Moderation reason", 500) ??
    (decision === "remove" ? "Removed after marketplace review." : "Reviewed and retained.");
  const database = getFirestore();
  const listingRef = database.collection(marketplaceListings).doc(listingId);
  const queueRef = database.collection(collections.moderationQueue)
    .doc(`marketplace--${listingId}`);
  const now = Timestamp.now();
  await database.runTransaction(async (transaction) => {
    const listing = await transaction.get(listingRef);
    if (!listing.exists) throw new HttpsError("not-found", "This listing is unavailable.");
    const currentStatus = String(listing.get("status") ?? "removed");
    if (decision === "remove") {
      transaction.update(listingRef, {
        status: "removed",
        moderationState: "removed",
        rejectionReason: reason,
        updatedAt: now,
      });
      if (["active", "reserved"].includes(currentStatus)) {
        transaction.set(
          database.doc(`users/${String(listing.get("sellerId"))}/private/marketplace_stats`),
          {
            activeListingCount: FieldValue.increment(-1),
            updatedAt: now,
            schemaVersion: currentSchemaVersion,
          },
          {merge: true},
        );
      }
    } else {
      transaction.update(listingRef, {
        moderationState: "active",
        updatedAt: now,
      });
    }
    transaction.set(queueRef, {
      status: "closed",
      decision,
      reason,
      reviewedBy: reviewerId,
      reviewedAt: now,
      updatedAt: now,
    }, {merge: true});
  });
  await writeAuditEvent({
    actorId: reviewerId,
    action: `marketplace.moderation_${decision}`,
    targetType: "marketplace_listing",
    targetId: listingId,
    metadata: {reason},
  });
  return {reviewed: true};
});

function messageMemberData(
  snapshot: Record<string, unknown>,
  now: Timestamp,
): Record<string, unknown> {
  return {
    userId: snapshot.id,
    userSnapshot: snapshot,
    role: "member",
    joinedAt: now,
    lastReadAt: now,
    unreadCount: 0,
    notificationsEnabled: true,
    mutedUntil: null,
    archivedAt: null,
    removedAt: null,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

function marketplaceInboxData(
  conversationId: string,
  target: Record<string, unknown>,
  members: Record<string, unknown>[],
  now: Timestamp,
): Record<string, unknown> {
  return {
    conversationId,
    type: "direct",
    title: String(target.displayName ?? "Athlete"),
    ...(target.avatarUrl ? {avatarUrl: String(target.avatarUrl)} : {}),
    memberSnapshots: members,
    unreadCount: 0,
    notificationsEnabled: true,
    mutedUntil: null,
    archivedAt: null,
    removedAt: null,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  };
}

export const startMarketplaceConversation = onCall(callableOptions, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const listingId = safeId(asRecord(request.data).listingId, "Listing id");
  await consumeRateLimit(uid, {
    key: "marketplace_start_conversation",
    maxAttempts: 80,
    windowSeconds: 60 * 60,
  });
  const database = getFirestore();
  const listingRef = database.collection(marketplaceListings).doc(listingId);
  const listing = await listingRef.get();
  if (!listingAvailable(listing)) throw new HttpsError("not-found", "This listing is unavailable.");
  const sellerId = String(listing.get("sellerId"));
  if (sellerId === uid) throw new HttpsError("failed-precondition", "This is your listing.");
  await assertUsersCanMessage(database, uid, sellerId);
  const [buyer, seller] = await Promise.all([
    activeProfileSnapshot(database, uid),
    activeProfileSnapshot(database, sellerId),
  ]);
  const conversationId = directConversationId(uid, sellerId);
  const conversationRef = database.collection(collections.conversations).doc(conversationId);
  const threadRef = database.collection(marketplaceThreads).doc(`${listingId}--${uid}`);
  const existing = await conversationRef.get();
  const now = Timestamp.now();
  const batch = database.batch();
  if (!existing.exists) {
    const members = [buyer, seller];
    batch.create(conversationRef, {
      type: "direct",
      directKey: [uid, sellerId].sort().join("--"),
      title: "",
      createdBy: uid,
      memberCount: 2,
      moderationState: "active",
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    batch.create(conversationRef.collection("members").doc(uid), messageMemberData(buyer, now));
    batch.create(conversationRef.collection("members").doc(sellerId), messageMemberData(seller, now));
    batch.set(database.doc(`users/${uid}/conversation_inbox/${conversationId}`),
      marketplaceInboxData(conversationId, seller, members, now));
    batch.set(database.doc(`users/${sellerId}/conversation_inbox/${conversationId}`),
      marketplaceInboxData(conversationId, buyer, members, now));
  }
  const thread = await threadRef.get();
  if (!thread.exists) {
    batch.create(threadRef, {
      listingId,
      conversationId,
      buyerId: uid,
      sellerId,
      listingSnapshot: {
        title: String(listing.get("title") ?? "Listing"),
        price: listing.get("price"),
        media: Array.isArray(listing.get("media")) ? listing.get("media").slice(0, 1) : [],
        status: listing.get("status"),
      },
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    batch.update(listingRef, {
      conversationCount: FieldValue.increment(1),
      updatedAt: now,
    });
  }
  await batch.commit();
  await getDatabase().ref(`messaging_acl/${conversationId}`).update({
    [uid]: true,
    [sellerId]: true,
  });
  await writeAuditEvent({
    actorId: uid,
    action: "marketplace.conversation_started",
    targetType: "marketplace_listing",
    targetId: listingId,
    metadata: {conversationId, sellerId},
  });
  return {conversationId, listingId};
});

export const expireMarketplaceListings = onSchedule(
  {
    schedule: "every day 02:35",
    timeZone: "Etc/UTC",
    region: callableOptions.region,
    retryCount: 3,
  },
  async () => {
    const database = getFirestore();
    const now = Timestamp.now();
    const batchSize = 400;
    const maximumPerStatus = 4_000;
    for (const status of ["active", "reserved"]) {
      let processed = 0;
      while (processed < maximumPerStatus) {
        const snapshot = await database.collection(marketplaceListings)
          .where("status", "==", status)
          .where("expiresAt", "<=", now)
          .limit(batchSize)
          .get();
        if (snapshot.empty) break;
        const batch = database.batch();
        for (const listing of snapshot.docs) {
          batch.update(listing.ref, {
            status: "expired",
            reservedAt: FieldValue.delete(),
            updatedAt: now,
          });
          batch.set(database.doc(
            `users/${String(listing.get("sellerId"))}/private/marketplace_stats`,
          ), {
            activeListingCount: FieldValue.increment(-1),
            updatedAt: now,
            schemaVersion: currentSchemaVersion,
          }, {merge: true});
        }
        await batch.commit();
        processed += snapshot.size;
        if (snapshot.size < batchSize) break;
      }
      if (processed >= maximumPerStatus) {
        logger.warn("Marketplace expiry run reached its safety cap.", {status, processed});
      }
    }
  },
);
