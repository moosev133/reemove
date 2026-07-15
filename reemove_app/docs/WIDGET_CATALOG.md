# Reusable widget catalog

## Foundation

1. `ReeMoveLogo`
2. `ReeMoveWordmark`
3. `AdaptivePageScaffold`
4. `PremiumSurface`
5. `GradientMeshBackground`
6. `AppTopBar`
7. `AppBottomNavigation`
8. `AppNavigationRail`
9. `ResponsiveContentConstraint`
10. `AppDivider`
11. `AppSectionHeader`
12. `AppStatusChip`

## Inputs and actions

13. `AppButton`
14. `AppIconButton`
15. `AppTextField`
16. `AppSearchField`
17. `AppDropdownField`
18. `AppSegmentedControl`
19. `AppChoiceChip`
20. `AppDateTimeField`
21. `AppLocationField`
22. `AppMediaPicker`
23. `AppFormError`

## Feedback and states

24. `AppLoadingIndicator`
25. `AppSkeleton`
26. `AppEmptyState`
27. `AppErrorView`
28. `OfflineBanner`
29. `UploadProgressOverlay`
30. `PermissionRationaleSheet`
31. `ConfirmationSheet`
32. `ReportSheet`

## Social content

33. `UserAvatar`
34. `UserIdentityRow`
35. `FollowButton`
36. `PostCard`
37. `PostMediaCarousel`
38. `PostActionBar`
39. `CommentTile`
40. `StoryAvatar`
41. `StoryRail`
42. `ReelActionRail`
43. `HashtagText`
44. `VisibilityBadge`

## Sports and location

45. `SportIcon`
46. `SportCard`
47. `SportLevelBadge`
48. `PlaceCard`
49. `EventCard`
50. `TeamCard`
51. `TrainerCard`
52. `ChallengeCard`
53. `LeaderboardRow`
54. `ActivityMetricTile`
55. `DistanceFilterSheet`
56. `MapListToggle`
57. `MapMarkerCluster`

## Messaging and marketplace

58. `ConversationTile`
59. `MessageBubble`
60. `TypingIndicator`
61. `MessageComposer`
62. `ListingCard`
63. `PriceLabel`
64. `SellerIdentityCard`
65. `ListingFilterSheet`

All reusable widgets must support light/dark mode, text scaling, RTL, semantic labels, loading/error states, and minimum touch targets.

## Phase 3 implemented authentication components

66. `AuthScaffold` — adaptive branded auth layout with safe-area and keyboard handling
67. `AuthCard` — constrained premium form surface
68. `AuthTextField` — shared accessible auth input
69. `AuthPrimaryButton` — loading-aware primary action
70. `AuthSocialButton` — Google/Apple action surface
71. `AuthErrorBanner` — user-safe typed failure feedback
72. `UsernameField` — validation, debounce, stale-request protection, availability status
73. `LegalConsentFields` — explicit terms, privacy, and minimum-age confirmations

These components use the shared design system and support light/dark mode, keyboard navigation, autofill, text scaling, and semantic labels.

## Phase 4 implemented onboarding components

74. `OnboardingScaffold` — responsive branded shell, progress, title, and privacy context
75. `OnboardingNavigation` — loading-aware Back/Continue/Finish actions
76. `OnboardingStepContent` — typed renderer for all ten onboarding steps
77. `AvatarSelector` — network/initials state, upload progress, and accessible action
78. `SelectableOptionCard` — reusable selected/unselected sports and goals surface
79. `PreferenceSwitchTile` — accessible preference row with supporting copy
80. `SportIcon` — catalog icon-key mapping with safe fallback

The flow also includes reusable privacy cards, review tiles, permission recovery actions, responsive sport grids, skill-level inputs, and discovery controls. All permission requests originate from an explicit user tap.

## Phase 5 implemented navigation components

81. `AppShell` — adaptive host for the stateful navigation shell
82. `AppBottomNavigation` — compact six-destination Material 3 navigation
83. `AppNavigationRail` — medium/expanded rail with theme control and badges
84. `AdaptivePageBody` — centered responsive scroll body for branch pages
85. `AppPageHeader` — consistent page title, eyebrow, subtitle, and trailing action
86. `AppAvatar` — network image/initials avatar fallback
87. `AppEmptyState` — accessible production empty/unavailable surface
88. `AppSectionHeader` — reusable section title and action row

The six branch screens use these components rather than embedding navigation chrome or responsive thresholds inside feature widgets.

## Phase 6 implemented social-content components

89. `FeedPostCard` — identity, caption, media, counters, audience, and actions
90. `PostMediaGallery` — image/video carousel with page indicators
91. `NetworkMediaImage` — cached image, loading, and failure states
92. `InlineVideoPlayer` — lifecycle-aware network playback and controls
93. `StoryRail` — unseen-first grouped story entry
94. `CommentsBottomSheet` — pagination, optimistic comment likes, and composer
95. `ContentActionsSheet` — report and reciprocal block flow
96. `FeedLoadingSkeleton` — feed loading state
97. `RelativeTime` — bounded human-readable timestamps

`ContentComposerScreen`, `ReelsScreen`, and `StoryViewerScreen` are feature screens rather than reusable widgets. Media surfaces have explicit loading, processing, error, and empty states.
