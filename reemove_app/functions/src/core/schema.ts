export const currentSchemaVersion = 1;
export const seedDatasetVersion = "2026-07-13.phase2.v1";

export const collections = {
  users: "users",
  usernames: "usernames",
  sports: "sports",
  places: "places",
  events: "events",
  challenges: "challenges",
  marketplaceListings: "marketplace_listings",
  appConfig: "app_config",
  featureFlags: "feature_flags",
  dataMigrations: "data_migrations",
} as const;
