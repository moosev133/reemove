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
