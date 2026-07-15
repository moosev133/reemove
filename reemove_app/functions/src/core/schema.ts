export const currentSchemaVersion = 1;
export const seedDatasetVersion = "2026-07-13.phase6.v1";

export const collections = {
  users: "users",
  usernames: "usernames",
  sports: "sports",
  places: "places",
  events: "events",
  challenges: "challenges",
  marketplaceListings: "marketplace_listings",
  posts: "posts",
  stories: "stories",
  feedEntries: "feed_entries",
  contentReactions: "content_reactions",
  reposts: "reposts",
  commentReactions: "comment_reactions",
  storyViews: "story_views",
  postViews: "post_views",
  mediaAssets: "media_assets",
  mediaJobs: "media_jobs",
  appConfig: "app_config",
  featureFlags: "feature_flags",
  dataMigrations: "data_migrations",
  accountDeletions: "account_deletions",
  auditLogs: "audit_logs",
  rateLimits: "rate_limits",
} as const;
