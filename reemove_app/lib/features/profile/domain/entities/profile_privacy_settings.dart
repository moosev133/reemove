enum ProfileAudience { everyone, followers, noOne }

enum FollowApprovalPolicy { automatic, approvalRequired }

class ProfilePrivacySettings {
  const ProfilePrivacySettings({
    required this.followApprovalPolicy,
    required this.messageAudience,
    required this.mentionAudience,
    required this.tagAudience,
    required this.showActivityStatus,
    required this.showSportLevels,
    required this.showGoals,
    required this.showLocation,
    required this.showFollowerLists,
    required this.hideLikeCounts,
    required this.discoverableByUsername,
    required this.personalizedSuggestions,
  });

  factory ProfilePrivacySettings.defaults() => const ProfilePrivacySettings(
    followApprovalPolicy: FollowApprovalPolicy.automatic,
    messageAudience: ProfileAudience.everyone,
    mentionAudience: ProfileAudience.everyone,
    tagAudience: ProfileAudience.followers,
    showActivityStatus: true,
    showSportLevels: true,
    showGoals: true,
    showLocation: true,
    showFollowerLists: true,
    hideLikeCounts: false,
    discoverableByUsername: true,
    personalizedSuggestions: true,
  );

  final FollowApprovalPolicy followApprovalPolicy;
  final ProfileAudience messageAudience;
  final ProfileAudience mentionAudience;
  final ProfileAudience tagAudience;
  final bool showActivityStatus;
  final bool showSportLevels;
  final bool showGoals;
  final bool showLocation;
  final bool showFollowerLists;
  final bool hideLikeCounts;
  final bool discoverableByUsername;
  final bool personalizedSuggestions;

  ProfilePrivacySettings copyWith({
    FollowApprovalPolicy? followApprovalPolicy,
    ProfileAudience? messageAudience,
    ProfileAudience? mentionAudience,
    ProfileAudience? tagAudience,
    bool? showActivityStatus,
    bool? showSportLevels,
    bool? showGoals,
    bool? showLocation,
    bool? showFollowerLists,
    bool? hideLikeCounts,
    bool? discoverableByUsername,
    bool? personalizedSuggestions,
  }) {
    return ProfilePrivacySettings(
      followApprovalPolicy: followApprovalPolicy ?? this.followApprovalPolicy,
      messageAudience: messageAudience ?? this.messageAudience,
      mentionAudience: mentionAudience ?? this.mentionAudience,
      tagAudience: tagAudience ?? this.tagAudience,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      showSportLevels: showSportLevels ?? this.showSportLevels,
      showGoals: showGoals ?? this.showGoals,
      showLocation: showLocation ?? this.showLocation,
      showFollowerLists: showFollowerLists ?? this.showFollowerLists,
      hideLikeCounts: hideLikeCounts ?? this.hideLikeCounts,
      discoverableByUsername:
          discoverableByUsername ?? this.discoverableByUsername,
      personalizedSuggestions:
          personalizedSuggestions ?? this.personalizedSuggestions,
    );
  }
}
