import {HttpsError} from "firebase-functions/v2/https";

export const supportedCommunityTypes = [
  "team",
  "club",
  "trainingGroup",
  "socialGroup",
] as const;
export const supportedJoinPolicies = [
  "open",
  "approvalRequired",
  "inviteOnly",
] as const;
export const supportedEventTypes = [
  "match",
  "meetup",
  "training",
  "classSession",
  "competition",
  "community",
] as const;
export const supportedLevels = [
  "beginner",
  "intermediate",
  "advanced",
  "professional",
] as const;
export const supportedTrainerServiceTypes = [
  "personalTraining",
  "groupSession",
  "program",
  "consultation",
  "clinic",
] as const;
export const supportedDeliveryModes = ["inPerson", "online", "hybrid"] as const;

export type CommunityType = typeof supportedCommunityTypes[number];
export type JoinPolicy = typeof supportedJoinPolicies[number];
export type EventType = typeof supportedEventTypes[number];
export type TrainerServiceType = typeof supportedTrainerServiceTypes[number];
export type DeliveryMode = typeof supportedDeliveryModes[number];

export type CommunityInput = {
  sportId: string;
  name: string;
  description: string;
  type: CommunityType;
  joinPolicy: JoinPolicy;
  capacity: number;
  tags: string[];
  city: string;
  countryCode: string;
  pricingText?: string;
};

export type EventInput = {
  sportId: string;
  type: EventType;
  title: string;
  description: string;
  startAt: Date;
  endAt: Date;
  timezone: string;
  latitude: number;
  longitude: number;
  geohash: string;
  locality?: string;
  administrativeArea?: string;
  countryCode?: string;
  placeId?: string;
  capacity: number;
  minimumLevel: string;
  maximumLevel: string;
  price?: {amountMinor: number; currency: string};
};

export type TrainerServiceInput = {
  serviceId?: string;
  sportId: string;
  title: string;
  description: string;
  type: TrainerServiceType;
  deliveryMode: DeliveryMode;
  durationMinutes: number;
  price: {amountMinor: number; currency: string};
};

export function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "The request body is invalid.");
  }
  return value as Record<string, unknown>;
}

export function requiredString(
  value: unknown,
  label: string,
  maximum: number,
  minimum = 1,
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

function optionalString(
  value: unknown,
  label: string,
  maximum: number,
): string | undefined {
  if (value === undefined || value === null || value === "") return undefined;
  return requiredString(value, label, maximum);
}

function boundedInteger(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
): number {
  if (typeof value !== "number" || !Number.isInteger(value) ||
      value < minimum || value > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

function enumValue<T extends readonly string[]>(
  value: unknown,
  label: string,
  allowed: T,
): T[number] {
  if (typeof value === "string" && allowed.includes(value)) {
    return value as T[number];
  }
  throw new HttpsError("invalid-argument", `${label} is invalid.`);
}

function stringArray(
  value: unknown,
  label: string,
  maximumItems: number,
): string[] {
  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return [...new Set(value.map((item) => requiredString(item, label, 40)))];
}

function isoDate(value: unknown, label: string): Date {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return parsed;
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

function money(value: unknown): {amountMinor: number; currency: string} | undefined {
  if (value === undefined || value === null) return undefined;
  const data = asRecord(value);
  const amountMinor = boundedInteger(
    data.amountMinor,
    "Price",
    1,
    10_000_000,
  );
  const currency = requiredString(data.currency, "Currency", 3, 3).toUpperCase();
  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new HttpsError("invalid-argument", "Currency is invalid.");
  }
  return {amountMinor, currency};
}

export function parseCommunityInput(value: unknown): CommunityInput {
  const data = asRecord(value);
  const countryCode = requiredString(data.countryCode, "Country", 2, 2)
    .toUpperCase();
  if (!/^[A-Z]{2}$/.test(countryCode)) {
    throw new HttpsError("invalid-argument", "Country is invalid.");
  }
  return {
    sportId: requiredString(data.sportId, "Sport", 40),
    name: requiredString(data.name, "Name", 80, 3),
    description: requiredString(data.description, "Description", 800, 10),
    type: enumValue(data.type, "Community type", supportedCommunityTypes),
    joinPolicy: enumValue(
      data.joinPolicy,
      "Join policy",
      supportedJoinPolicies,
    ),
    capacity: boundedInteger(data.capacity, "Capacity", 2, 500),
    tags: stringArray(data.tags ?? [], "Tags", 10),
    city: requiredString(data.city, "City", 80, 2),
    countryCode,
    pricingText: optionalString(data.pricingText, "Pricing", 120),
  };
}

export function parseEventInput(value: unknown): EventInput {
  const data = asRecord(value);
  const startAt = isoDate(data.startAt, "Start time");
  const endAt = isoDate(data.endAt, "End time");
  const now = Date.now();
  if (startAt.getTime() < now - 5 * 60_000) {
    throw new HttpsError("invalid-argument", "The event must start in the future.");
  }
  const duration = endAt.getTime() - startAt.getTime();
  if (duration < 15 * 60_000 || duration > 24 * 60 * 60_000) {
    throw new HttpsError(
      "invalid-argument",
      "Event duration must be between 15 minutes and 24 hours.",
    );
  }
  const minimumLevel = enumValue(data.minimumLevel, "Minimum level", supportedLevels);
  const maximumLevel = enumValue(data.maximumLevel, "Maximum level", supportedLevels);
  if (supportedLevels.indexOf(minimumLevel) > supportedLevels.indexOf(maximumLevel)) {
    throw new HttpsError("invalid-argument", "The level range is invalid.");
  }
  return {
    sportId: requiredString(data.sportId, "Sport", 40),
    type: enumValue(data.type, "Event type", supportedEventTypes),
    title: requiredString(data.title, "Title", 120, 3),
    description: requiredString(data.description, "Description", 1200, 10),
    startAt,
    endAt,
    timezone: requiredString(data.timezone, "Timezone", 80),
    latitude: coordinate(data.latitude, "Latitude", -90, 90),
    longitude: coordinate(data.longitude, "Longitude", -180, 180),
    geohash: requiredString(data.geohash, "Geohash", 12, 4),
    locality: optionalString(data.locality, "Locality", 100),
    administrativeArea: optionalString(
      data.administrativeArea,
      "Administrative area",
      100,
    ),
    countryCode: optionalString(data.countryCode, "Country", 2)?.toUpperCase(),
    placeId: optionalString(data.placeId, "Place", 120),
    capacity: boundedInteger(data.capacity, "Capacity", 2, 1000),
    minimumLevel,
    maximumLevel,
    price: money(data.price),
  };
}

export function parseTrainerServiceInput(value: unknown): TrainerServiceInput {
  const data = asRecord(value);
  const parsedMoney = money(data.price);
  if (!parsedMoney) {
    throw new HttpsError("invalid-argument", "Price is required.");
  }
  return {
    serviceId: optionalString(data.serviceId, "Service", 120),
    sportId: requiredString(data.sportId, "Sport", 40),
    title: requiredString(data.title, "Title", 100, 3),
    description: requiredString(data.description, "Description", 700, 10),
    type: enumValue(
      data.type,
      "Service type",
      supportedTrainerServiceTypes,
    ),
    deliveryMode: enumValue(
      data.deliveryMode,
      "Delivery mode",
      supportedDeliveryModes,
    ),
    durationMinutes: boundedInteger(
      data.durationMinutes,
      "Duration",
      15,
      480,
    ),
    price: parsedMoney,
  };
}
