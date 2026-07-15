# Service and repository catalog

## Platform and infrastructure services

1. `FirebaseBootstrapService`
2. `AppCheckService`
3. `SecureStorageService`
4. `PreferencesService`
5. `ConnectivityService`
6. `NetworkStatusService`
7. `AppLogger`
8. `CrashReportingService`
9. `AnalyticsService`
10. `PerformanceTracingService`
11. `RemoteConfigService`
12. `FeatureFlagService`
13. `DeepLinkService`
14. `PermissionService`
15. `LocationService`
16. `MediaPickerService`
17. `MediaCompressionService`
18. `MediaUploadService`
19. `VideoPlaybackService`
20. `PushNotificationService`
21. `ShareService`
22. `Clock`
23. `IdGenerator`

## Authentication and users

24. `AuthRepository`
25. `UsernameRepository`
26. `UserRepository`
27. `OnboardingRepository`
28. `FollowRepository`
29. `BlockRepository`
30. `VerificationRepository`
31. `AccountLifecycleService`

## Social content

32. `FeedRepository`
33. `PostRepository`
34. `CommentRepository`
35. `StoryRepository`
36. `ReactionRepository`
37. `SaveRepository`
38. `RepostRepository`
39. `ContentModerationRepository`
40. `SearchRepository`

## Messaging and communities

41. `ConversationRepository`
42. `MessageRepository`
43. `MessagingPresenceService`
44. `GroupRepository`
45. `GroupMembershipRepository`

## Sports and nearby

46. `SportCatalogRepository`
47. `SportPlaceRepository`
48. `TeamRepository`
49. `EventRepository`
50. `RouteRepository`
51. `ActivityRepository`
52. `TrainerRepository`
53. `NearbyRepository`
54. `MapsService`
55. `GeohashService`
56. `DistanceService`
57. `ActivityTrackingService`

## Challenges, marketplace, notifications, and AI

58. `ChallengeRepository`
59. `LeaderboardRepository`
60. `BadgeRepository`
61. `RewardRepository`
62. `MarketplaceRepository`
63. `ListingFavoriteRepository`
64. `NotificationRepository`
65. `NotificationPreferenceRepository`
66. `AiGateway`
67. `AiCoachService`
68. `WorkoutGeneratorService`
69. `NutritionPlannerService`
70. `MatchmakerService`
71. `ChallengeGeneratorService`
72. `ContentAssistantService`
73. `TrainerBusinessIntelligenceService`

## Backend Cloud Functions modules

- Username reservation and release
- Counter aggregation
- Feed fan-out/ranking jobs
- Notification fan-out
- Media processing hooks
- Story expiration cleanup
- Challenge scheduling and ranking
- Search index synchronization
- Moderation and report routing
- Account deletion/anonymization
- AI request dispatch, quotas, and audit
- Scheduled maintenance and data migrations

## Phase 2 implemented repository names

The executable Phase 2 data layer currently provides:

- `UserProfileRepository` / `FirebaseUserProfileRepository`
- `SportsCatalogRepository` / `FirebaseSportsCatalogRepository`
- `ChallengeRepository` / `FirebaseChallengeRepository`
- `MarketplaceCatalogRepository` / `FirebaseMarketplaceCatalogRepository`
- `AppConfigurationRepository` / `FirebaseAppConfigurationRepository`
- `ReeMoveFirestore` typed collection registry
- `FirestoreFailureMapper`

The broader catalog above remains the target service inventory for later phases.

## Phase 3 implemented authentication services

- `AuthRepository` / `FirebaseAuthRepository`
- `UsernameRepository` / `FirestoreUsernameRepository`
- `AccountLifecycleRepository` / `FirebaseAccountLifecycleRepository`
- `GoogleIdentityService`
- `FirebaseAuthFailureMapper`
- `AuthAnalytics` / `FirebaseAuthAnalytics` / `NoopAuthAnalytics`
- `FirebaseUserMapper`
- `AuthActionController`
- `currentAuthUserProvider`
- `currentUserProfileProvider`
- `authRoutingStateProvider`
- `provisionAccount` callable Function
- `syncAuthProviders` callable Function
- `revokeSessions` callable Function
- `deleteAccount` callable Function
- `retryAccountDeletions` scheduled Function
- Shared `consumeRateLimit` transaction service
- Shared `writeAuditEvent` privileged telemetry service
- Shared recent-authentication policy
- Emulator-only `seedAuth` and `seedFirestore` tools

`provisionAccount` owns username reservation, profile creation, private metadata, and consent versioning. `syncAuthProviders` derives provider IDs from Firebase Admin. `revokeSessions` owns refresh-token invalidation. `deleteAccount` owns recent-auth validation, identity disable/delete ordering, username release, recursive profile cleanup, and retry state. All privileged mutations use server-side rate limits and audit events.

## Phase 4 implemented onboarding services

- `OnboardingRepository` / `FirebaseOnboardingRepository`
- `AvatarRepository` / `FirebaseAvatarRepository`
- `AvatarPickerService` / `PlatformAvatarPickerService`
- `LocationService` / `PlatformLocationService`
- `NotificationPermissionService` / `FirebaseNotificationPermissionService`
- `UnavailableNotificationPermissionService` for emulator/configuration-safe behavior
- `OnboardingController` Riverpod `AsyncNotifier`
- `OnboardingValidators`
- `GeohashEncoder`
- `saveOnboardingProgress` callable Function
- `completeOnboarding` callable Function
- Shared onboarding request parser, age policy, and geohash policy
- `configure_native_permissions.py` native configuration tool

The callable Functions are the only write path for the private draft and trusted completion transition. Avatar bytes go directly to Storage under owner-scoped rules; completion independently verifies the resulting object metadata.
