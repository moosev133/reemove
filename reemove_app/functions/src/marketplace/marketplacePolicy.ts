import {HttpsError} from "firebase-functions/v2/https";

import {encodeGeohash, roundCoordinate} from "../onboarding/geohash";

export const listingConditions = ["newItem", "likeNew", "good", "fair", "poor"] as const;
export const listingStatuses = [
  "draft", "pendingReview", "active", "paused", "reserved", "sold", "expired", "removed", "rejected",
] as const;
export const deliveryOptions = ["pickup", "meetup", "shipping"] as const;
export const listingActions = ["activate", "pause", "reserve", "sold", "remove"] as const;
export const reportReasons = [
  "prohibitedItem", "scam", "counterfeit", "misleading", "harassment", "duplicate", "other",
] as const;
export const marketplaceSorts = ["newest", "priceLowToHigh", "priceHighToLow", "nearest"] as const;

export type ListingCondition = typeof listingConditions[number];
export type DeliveryOption = typeof deliveryOptions[number];
export type ListingAction = typeof listingActions[number];
export type MarketplaceSort = typeof marketplaceSorts[number];

export type ListingMediaInput = {
  id: string;
  storagePath: string;
  downloadUrl: string;
  contentType: string;
  sizeBytes: number;
};

export type ListingInput = {
  listingId?: string;
  title: string;
  description: string;
  categoryId: string;
  sportId: string;
  condition: ListingCondition;
  price: {amountMinor: number; currency: string};
  isNegotiable: boolean;
  deliveryOptions: DeliveryOption[];
  media: ListingMediaInput[];
  location: {latitude: number; longitude: number};
  geohash: string;
  locality?: string;
  administrativeArea?: string;
  countryCode?: string;
};

const prohibitedTerms = [
  // English
  "firearm", "gun", "ammunition", "explosive", "firework", "taser", "switchblade",
  "pepper spray", "poison", "steroid", "prescription", "cannabis", "marijuana", "thc",
  "cbd", "vape", "cigarette", "nicotine", "alcohol", "beer", "wine", "vodka",
  "gambling", "counterfeit", "replica designer", "stolen",
  // Arabic
  "سلاح", "مسدس", "ذخيرة", "متفجرات", "العاب نارية", "صاعق", "سكين كابسة",
  "رذاذ فلفل", "سم", "ستيرويد", "وصفة طبية", "قنب", "ماريجوانا", "حشيش",
  "فيب", "سيجارة", "نيكوتين", "كحول", "بيرة", "نبيذ", "فودكا", "قمار",
  "مقلد", "مسروق",
  // Hebrew
  "נשק", "אקדח", "תחמושת", "חומר נפץ", "זיקוקים", "טייזר", "סכין קפיצית",
  "גז פלפל", "רעל", "סטרואיד", "תרופת מרשם", "קנאביס", "מריחואנה", "חשיש",
  "וייפ", "סיגריה", "ניקוטין", "אלכוהול", "בירה", "יין", "וודקה", "הימורים",
  "זיוף", "גנוב",
];

const supportedCurrencies = ["ILS"] as const;
const maximumListingPriceMinor = 5_000_000_00;

export function asRecord(value: unknown, label = "request"): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `The ${label} is invalid.`);
  }
  return value as Record<string, unknown>;
}

export function requiredText(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be between ${minimum} and ${maximum} characters.`,
    );
  }
  return normalized;
}

export function optionalText(value: unknown, label: string, maximum: number): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  return requiredText(value, label, 1, maximum);
}

export function safeId(value: unknown, label: string): string {
  const id = requiredText(value, label, 1, 120);
  if (!/^[a-zA-Z0-9_-]+$/.test(id)) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return id;
}

function enumValue<T extends readonly string[]>(
  value: unknown,
  label: string,
  options: T,
): T[number] {
  if (typeof value === "string" && options.includes(value)) return value as T[number];
  throw new HttpsError("invalid-argument", `${label} is invalid.`);
}

function finiteNumber(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return value;
}

export function normalizeMarketplaceSearchText(value: string): string {
  return value
    .toLowerCase()
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function hasProhibitedMarketplaceLanguage(...values: string[]): boolean {
  const combined = normalizeMarketplaceSearchText(values.join(" "));
  return prohibitedTerms.some((term) =>
    combined.includes(normalizeMarketplaceSearchText(term)),
  );
}

function parseMedia(value: unknown): ListingMediaInput[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > 8) {
    throw new HttpsError("invalid-argument", "Listings support up to eight photos.");
  }
  const unique = new Set<string>();
  return value.map((raw) => {
    const item = asRecord(raw, "media item");
    const id = safeId(item.id, "Media id");
    if (unique.has(id)) throw new HttpsError("invalid-argument", "Duplicate media item.");
    unique.add(id);
    const storagePath = requiredText(item.storagePath, "Storage path", 5, 500);
    const downloadUrl = requiredText(item.downloadUrl, "Download URL", 8, 2000);
    const contentType = requiredText(item.contentType, "Content type", 5, 100).toLowerCase();
    const sizeBytes = finiteNumber(item.sizeBytes, "Media size");
    if (!contentType.startsWith("image/") || sizeBytes <= 0 || sizeBytes > 15 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "Marketplace photos must be valid images under 15 MB.");
    }
    return {id, storagePath, downloadUrl, contentType, sizeBytes};
  });
}

function parseLocation(value: unknown): {
  location: {latitude: number; longitude: number};
  geohash: string;
} {
  const item = asRecord(value, "location");
  const latitude = finiteNumber(item.latitude, "Latitude");
  const longitude = finiteNumber(item.longitude, "Longitude");
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new HttpsError("invalid-argument", "The marketplace location is invalid.");
  }
  // Marketplace listings expose only an approximate pickup area.
  const publicLatitude = roundCoordinate(latitude, 3);
  const publicLongitude = roundCoordinate(longitude, 3);
  return {
    location: {latitude: publicLatitude, longitude: publicLongitude},
    geohash: encodeGeohash(publicLatitude, publicLongitude, 8),
  };
}

export function parseListingInput(value: unknown): ListingInput {
  const data = asRecord(value, "listing");
  const title = requiredText(data.title, "Title", 4, 100);
  const description = requiredText(data.description, "Description", 12, 2000);
  const price = asRecord(data.price, "price");
  const amountMinor = finiteNumber(price.amountMinor, "Price");
  const currency = requiredText(price.currency, "Currency", 3, 3).toUpperCase();
  if (!Number.isInteger(amountMinor) || amountMinor < 0 || amountMinor > maximumListingPriceMinor) {
    throw new HttpsError("invalid-argument", "The price is outside the supported range.");
  }
  if (!supportedCurrencies.includes(currency as typeof supportedCurrencies[number])) {
    throw new HttpsError("invalid-argument", "This currency is not supported.");
  }
  const rawDelivery = data.deliveryOptions;
  if (!Array.isArray(rawDelivery) || rawDelivery.length === 0 || rawDelivery.length > 3) {
    throw new HttpsError("invalid-argument", "Choose at least one delivery option.");
  }
  const parsedDelivery = [...new Set(rawDelivery.map((item) =>
    enumValue(item, "Delivery option", deliveryOptions),
  ))];
  const location = parseLocation(data.location);
  if (hasProhibitedMarketplaceLanguage(title, description)) {
    throw new HttpsError(
      "failed-precondition",
      "This item cannot be listed in ReeMove Marketplace.",
    );
  }
  return {
    listingId: data.listingId === undefined ? undefined : safeId(data.listingId, "Listing id"),
    title,
    description,
    categoryId: safeId(data.categoryId, "Category"),
    sportId: safeId(data.sportId, "Sport"),
    condition: enumValue(data.condition, "Condition", listingConditions),
    price: {amountMinor, currency},
    isNegotiable: data.isNegotiable === true,
    deliveryOptions: parsedDelivery,
    media: parseMedia(data.media),
    location: location.location,
    geohash: location.geohash,
    locality: optionalText(data.locality, "Locality", 100),
    administrativeArea: optionalText(data.administrativeArea, "Area", 100),
    countryCode: optionalText(data.countryCode, "Country", 2)?.toUpperCase(),
  };
}

export function searchPrefixes(title: string, description: string): string[] {
  const words = normalizeMarketplaceSearchText(`${title} ${description}`)
    .split(/\s+/)
    .filter((item) => item.length >= 2)
    .slice(0, 24);
  const values = new Set<string>();
  for (const word of words) {
    const maximum = Math.min(word.length, 16);
    for (let index = 2; index <= maximum; index += 1) values.add(word.slice(0, index));
  }
  return [...values].slice(0, 120);
}

export function parseSearchRequest(value: unknown): {
  query: string;
  sportId?: string;
  categoryId?: string;
  condition?: ListingCondition;
  minimumPriceMinor?: number;
  maximumPriceMinor?: number;
  deliveryOptions: DeliveryOption[];
  sort: MarketplaceSort;
  latitude?: number;
  longitude?: number;
  radiusKm: number;
  cursor: number;
  limit: number;
} {
  const data = asRecord(value, "search request");
  const query = typeof data.query === "string" ? data.query.trim().toLowerCase().slice(0, 80) : "";
  const minimumPriceMinor = data.minimumPriceMinor === undefined ? undefined : finiteNumber(data.minimumPriceMinor, "Minimum price");
  const maximumPriceMinor = data.maximumPriceMinor === undefined ? undefined : finiteNumber(data.maximumPriceMinor, "Maximum price");
  if ((minimumPriceMinor !== undefined &&
        (!Number.isInteger(minimumPriceMinor) || minimumPriceMinor < 0 ||
          minimumPriceMinor > maximumListingPriceMinor)) ||
      (maximumPriceMinor !== undefined &&
        (!Number.isInteger(maximumPriceMinor) || maximumPriceMinor < 0 ||
          maximumPriceMinor > maximumListingPriceMinor)) ||
      (minimumPriceMinor !== undefined && maximumPriceMinor !== undefined &&
        minimumPriceMinor > maximumPriceMinor)) {
    throw new HttpsError("invalid-argument", "The price range is invalid.");
  }
  const rawDelivery = Array.isArray(data.deliveryOptions) ? data.deliveryOptions : [];
  const latitude = data.latitude === undefined ? undefined : finiteNumber(data.latitude, "Latitude");
  const longitude = data.longitude === undefined ? undefined : finiteNumber(data.longitude, "Longitude");
  if ((latitude === undefined) !== (longitude === undefined)) {
    throw new HttpsError("invalid-argument", "Both coordinates are required.");
  }
  if ((latitude !== undefined && (latitude < -90 || latitude > 90)) ||
      (longitude !== undefined && (longitude < -180 || longitude > 180))) {
    throw new HttpsError("invalid-argument", "The search coordinates are invalid.");
  }
  const sort = data.sort === undefined ? "newest" :
    enumValue(data.sort, "Sort", marketplaceSorts);
  if (sort === "nearest" && (latitude === undefined || longitude === undefined)) {
    throw new HttpsError("invalid-argument", "Location is required for nearest sorting.");
  }
  const radiusKm = data.radiusKm === undefined ? 50 : finiteNumber(data.radiusKm, "Radius");
  if (radiusKm < 1 || radiusKm > 100) {
    throw new HttpsError("invalid-argument", "The radius must be between 1 and 100 kilometres.");
  }
  const cursor = data.cursor === undefined ? 0 : Number.parseInt(String(data.cursor), 10);
  const limit = data.limit === undefined ? 24 : Number(data.limit);
  if (!Number.isInteger(cursor) || cursor < 0 || cursor > 10_000 ||
      !Number.isInteger(limit) || limit < 1 || limit > 40) {
    throw new HttpsError("invalid-argument", "The page request is invalid.");
  }
  return {
    query,
    sportId: data.sportId === undefined ? undefined : safeId(data.sportId, "Sport"),
    categoryId: data.categoryId === undefined ? undefined : safeId(data.categoryId, "Category"),
    condition: data.condition === undefined ? undefined : enumValue(data.condition, "Condition", listingConditions),
    minimumPriceMinor,
    maximumPriceMinor,
    deliveryOptions: rawDelivery.map((item) => enumValue(item, "Delivery option", deliveryOptions)),
    sort,
    latitude,
    longitude,
    radiusKm,
    cursor,
    limit,
  };
}

export function distanceKm(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const earthRadiusKm = 6371;
  const dLatitude = radians(latitudeB - latitudeA);
  const dLongitude = radians(longitudeB - longitudeA);
  const a = Math.sin(dLatitude / 2) ** 2 +
    Math.cos(radians(latitudeA)) * Math.cos(radians(latitudeB)) *
    Math.sin(dLongitude / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
