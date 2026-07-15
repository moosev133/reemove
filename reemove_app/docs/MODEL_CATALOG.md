# Model catalog

## Core value objects and shared models

1. `AppUserId`
2. `Username`
3. `EmailAddress`
4. `MediaAsset`
5. `GeoLocation`
6. `Money`
7. `DateRange`
8. `PaginationCursor`
9. `Visibility`
10. `ModerationState`
11. `VerificationStatus`
12. `SportLevel`
13. `UserRole`
14. `EntityAudit`

## User and social graph

15. `UserProfile`
16. `PrivateUserProfile`
17. `UserPreferences`
18. `SportPreference`
19. `FollowRelation`
20. `BlockRelation`
21. `VerificationRequest`

## Content

22. `Post`
23. `PostAuthorSnapshot`
24. `PostMedia`
25. `Comment`
26. `Story`
27. `StoryView`
28. `ContentReaction`
29. `Repost`
30. `ContentReport`

## Messaging and groups

31. `Conversation`
32. `ConversationMember`
33. `Message`
34. `MessageAttachment`
35. `MessageReaction`
36. `Group`
37. `GroupMember`

## Sports domain

38. `SportDefinition`
39. `SportModuleConfig`
40. `SportPlace`
41. `Team`
42. `TeamMember`
43. `SportsEvent`
44. `EventAttendee`
45. `SportRoute`
46. `ActivitySession`
47. `ActivityMetric`
48. `TrainerProfile`
49. `TrainerService`

## Challenges, leaderboards, and rewards

50. `Challenge`
51. `ChallengeRule`
52. `ChallengeParticipant`
53. `ChallengeProgress`
54. `ChallengeSubmission`
55. `LeaderboardEntry`
56. `Badge`
57. `UserBadge`
58. `Reward`
59. `RewardClaim`

## Marketplace

60. `MarketplaceListing`
61. `ListingMedia`
62. `ListingFilter`
63. `ListingFavorite`
64. `SellerSnapshot`

## Notifications and AI

65. `AppNotification`
66. `NotificationPreference`
67. `DeviceToken`
68. `AiRequest`
69. `AiArtifact`
70. `WorkoutPlan`
71. `WorkoutSession`
72. `ExercisePrescription`
73. `NutritionPlan`
74. `MatchRecommendation`
75. `GeneratedChallenge`
76. `ContentSuggestion`
77. `TrainerBusinessInsight`

## Operations

78. `FeatureFlag`
79. `AppConfiguration`
80. `AuditLogEntry`
81. `DataMigration`

DTOs remain in the data layer and map into these domain models. Firestore `Timestamp`, `DocumentReference`, and `GeoPoint` types must never leak into domain entities.

## Phase 3 implemented authentication models

82. `AuthUser` — provider-neutral Firebase identity snapshot
83. `AuthProviderType` — password/Google/Apple provider category
84. `UsernameAvailability` — normalized availability state and message
85. `AccountProvisioningRequest` — username/display-name/legal confirmation command
86. `AccountProvisioningResult` — idempotent account bootstrap response
87. `AuthRoutingState` — typed destination and optional reason
88. `AuthDestination` — configuration, signed-out, profile, verification, onboarding, ready, blocked

Authentication-specific Firebase objects remain in data mappers and repositories. No `User`, `AuthCredential`, `FirebaseAuthException`, or `HttpsCallableResult` enters the domain layer.
