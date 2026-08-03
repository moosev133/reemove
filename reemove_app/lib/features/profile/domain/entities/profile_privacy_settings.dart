enum ProfileAudience { everyone, followers, noOne }

enum FollowApprovalPolicy { automatic, approvalRequired }

/// Who may open this profile's followers and following lists.
///
/// Default for existing accounts without an explicit value is [everyone],
/// derived from legacy `showFollowerLists: true`.
enum FollowerListAudience { everyone, followers, owner }

class ProfilePrivacySettings {
  const ProfilePrivacySettings({
    required this.followApprovalPolicy,
    required this.messageAudience,
    required this.messageRequestAudience,
    required this.mentionAudience,
    required this.tagAudience,
    required this.showActivityStatus,
    required this.showSportLevels,
    required this.showGoals,
    required this.showLocation,
    required this.followerListAudience,
    required this.hideLikeCounts,
    required this.discoverableByUsername,
    required this.personalizedSuggestions,
  });

  factory ProfilePrivacySettings.defaults() => const ProfilePrivacySettings(
    followApprovalPolicy: FollowApprovalPolicy.automatic,
    messageAudience: ProfileAudience.everyone,
    messageRequestAudience: ProfileAudience.noOne,
    mentionAudience: ProfileAudience.everyone,
    tagAudience: ProfileAudience.followers,
    showActivityStatus: true,
    showSportLevels: true,
    showGoals: true,
    showLocation: true,
    followerListAudience: FollowerListAudience.everyone,
    hideLikeCounts: false,
    discoverableByUsername: true,
    personalizedSuggestions: true,
  );

  final FollowApprovalPolicy followApprovalPolicy;
  final ProfileAudience messageAudience;
  final ProfileAudience messageRequestAudience;
  final ProfileAudience mentionAudience;
  final ProfileAudience tagAudience;
  final bool showActivityStatus;
  final bool showSportLevels;
  final bool showGoals;
  final bool showLocation;
  final FollowerListAudience followerListAudience;
  final bool hideLikeCounts;
  final bool discoverableByUsername;
  final bool personalizedSuggestions;

  bool get showFollowerLists =>
      followerListAudience != FollowerListAudience.owner;

  ProfilePrivacySettings copyWith({
    FollowApprovalPolicy? followApprovalPolicy,
    ProfileAudience? messageAudience,
    ProfileAudience? messageRequestAudience,
    ProfileAudience? mentionAudience,
    ProfileAudience? tagAudience,
    bool? showActivityStatus,
    bool? showSportLevels,
    bool? showGoals,
    bool? showLocation,
    FollowerListAudience? followerListAudience,
    bool? hideLikeCounts,
    bool? discoverableByUsername,
    bool? personalizedSuggestions,
  }) {
    return ProfilePrivacySettings(
      followApprovalPolicy: followApprovalPolicy ?? this.followApprovalPolicy,
      messageAudience: messageAudience ?? this.messageAudience,
      messageRequestAudience:
          messageRequestAudience ?? this.messageRequestAudience,
      mentionAudience: mentionAudience ?? this.mentionAudience,
      tagAudience: tagAudience ?? this.tagAudience,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      showSportLevels: showSportLevels ?? this.showSportLevels,
      showGoals: showGoals ?? this.showGoals,
      showLocation: showLocation ?? this.showLocation,
      followerListAudience: followerListAudience ?? this.followerListAudience,
      hideLikeCounts: hideLikeCounts ?? this.hideLikeCounts,
      discoverableByUsername:
          discoverableByUsername ?? this.discoverableByUsername,
      personalizedSuggestions:
          personalizedSuggestions ?? this.personalizedSuggestions,
    );
  }
}
