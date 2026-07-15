import {HttpsError} from "firebase-functions/v2/https";

export const nearbyEntityTypes = ["place", "person", "event", "route"] as const;
export type NearbyEntityType = typeof nearbyEntityTypes[number];

export type NearbySearchInput = {
  latitude: number;
  longitude: number;
  radiusKm: number;
  types: NearbyEntityType[];
  sportIds: string[];
  limit: number;
};

export type DiscoveryLocationInput = {
  latitude: number;
  longitude: number;
  locality?: string;
  administrativeArea?: string;
  countryCode?: string;
};

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  return value as Record<string, unknown>;
}

function coordinate(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value) ||
      value < minimum || value > maximum) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return value;
}

function boundedNumber(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
  fallback: number,
): number {
  if (value === undefined || value === null) return fallback;
  if (typeof value !== "number" || !Number.isFinite(value) ||
      value < minimum || value > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

function stringArray(
  value: unknown,
  label: string,
  maximumItems: number,
  maximumLength: number,
): string[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const normalized = value.map((item) => {
    if (typeof item !== "string") {
      throw new HttpsError("invalid-argument", `${label} is invalid.`);
    }
    const text = item.trim().toLowerCase();
    if (text.length < 1 || text.length > maximumLength) {
      throw new HttpsError("invalid-argument", `${label} is invalid.`);
    }
    return text;
  });
  return [...new Set(normalized)];
}

function optionalText(
  value: unknown,
  label: string,
  maximumLength: number,
): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length > maximumLength) {
    throw new HttpsError("invalid-argument", `${label} is too long.`);
  }
  return normalized || undefined;
}

export function parseNearbySearchInput(value: unknown): NearbySearchInput {
  const data = record(value);
  const rawTypes = stringArray(data.types, "Nearby types", 4, 20);
  const types = (rawTypes.length === 0 ? [...nearbyEntityTypes] : rawTypes)
    .filter((item): item is NearbyEntityType =>
      nearbyEntityTypes.includes(item as NearbyEntityType));
  if (types.length === 0 || types.length !== (rawTypes.length || nearbyEntityTypes.length)) {
    throw new HttpsError("invalid-argument", "A nearby type is invalid.");
  }
  const rawLimit = boundedNumber(data.limit, "Result limit", 10, 100, 50);
  return {
    latitude: coordinate(data.latitude, "Latitude", -90, 90),
    longitude: coordinate(data.longitude, "Longitude", -180, 180),
    radiusKm: boundedNumber(data.radiusKm, "Radius", 1, 100, 25),
    types,
    sportIds: stringArray(data.sportIds, "Sports", 8, 40),
    limit: Math.floor(rawLimit),
  };
}

export function parseDiscoveryLocation(value: unknown): DiscoveryLocationInput {
  const data = record(value);
  const countryCode = optionalText(data.countryCode, "Country", 2)?.toUpperCase();
  if (countryCode && !/^[A-Z]{2}$/.test(countryCode)) {
    throw new HttpsError("invalid-argument", "Country is invalid.");
  }
  return {
    latitude: coordinate(data.latitude, "Latitude", -90, 90),
    longitude: coordinate(data.longitude, "Longitude", -180, 180),
    locality: optionalText(data.locality, "Locality", 100),
    administrativeArea: optionalText(
      data.administrativeArea,
      "Administrative area",
      100,
    ),
    countryCode,
  };
}

export function distanceLabel(distanceKm: number, approximate: boolean): string {
  if (approximate) {
    const rounded = Math.max(1, Math.round(distanceKm));
    return `About ${rounded} km away`;
  }
  if (distanceKm < 1) return `${Math.max(50, Math.round(distanceKm * 1000 / 50) * 50)} m away`;
  return `${distanceKm.toFixed(distanceKm < 10 ? 1 : 0)} km away`;
}
