import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';
import '../../domain/entities/profile_privacy_settings.dart';

class ProfilePrivacySettingsDto {
  const ProfilePrivacySettingsDto({
    required this.followApprovalPolicy,
    required this.messageAudience,
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

  factory ProfilePrivacySettingsDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) {
    final Map<String, dynamic> data =
        snapshot.data() ?? const <String, dynamic>{};
    return ProfilePrivacySettingsDto.fromMap(data);
  }

  factory ProfilePrivacySettingsDto.fromMap(Map<String, dynamic> data) {
    return ProfilePrivacySettingsDto(
      followApprovalPolicy: FirestoreParser.string(
        data,
        'followApprovalPolicy',
        fallback: 'automatic',
      ),
      messageAudience: FirestoreParser.string(
        data,
        'messageAudience',
        fallback: 'everyone',
      ),
      mentionAudience: FirestoreParser.string(
        data,
        'mentionAudience',
        fallback: 'everyone',
      ),
      tagAudience: FirestoreParser.string(
        data,
        'tagAudience',
        fallback: 'followers',
      ),
      showActivityStatus: FirestoreParser.boolean(
        data,
        'showActivityStatus',
        fallback: true,
      ),
      showSportLevels: FirestoreParser.boolean(
        data,
        'showSportLevels',
        fallback: true,
      ),
      showGoals: FirestoreParser.boolean(data, 'showGoals', fallback: true),
      showLocation: FirestoreParser.boolean(
        data,
        'showLocation',
        fallback: true,
      ),
      followerListAudience: _followerListAudience(data),
      hideLikeCounts: FirestoreParser.boolean(
        data,
        'hideLikeCounts',
        fallback: false,
      ),
      discoverableByUsername: FirestoreParser.boolean(
        data,
        'discoverableByUsername',
        fallback: true,
      ),
      personalizedSuggestions: FirestoreParser.boolean(
        data,
        'personalizedSuggestions',
        fallback: true,
      ),
    );
  }

  static String _followerListAudience(Map<String, dynamic> data) {
    final Object? raw = data['followerListAudience'];
    if (raw == 'everyone' || raw == 'followers' || raw == 'owner') {
      return raw as String;
    }
    final bool showLists = FirestoreParser.boolean(
      data,
      'showFollowerLists',
      fallback: true,
    );
    return showLists ? 'everyone' : 'owner';
  }

  final String followApprovalPolicy;
  final String messageAudience;
  final String mentionAudience;
  final String tagAudience;
  final bool showActivityStatus;
  final bool showSportLevels;
  final bool showGoals;
  final bool showLocation;
  final String followerListAudience;
  final bool hideLikeCounts;
  final bool discoverableByUsername;
  final bool personalizedSuggestions;

  ProfilePrivacySettings toDomain() => ProfilePrivacySettings(
    followApprovalPolicy: FollowApprovalPolicy.values.byName(
      followApprovalPolicy,
    ),
    messageAudience: ProfileAudience.values.byName(messageAudience),
    mentionAudience: ProfileAudience.values.byName(mentionAudience),
    tagAudience: ProfileAudience.values.byName(tagAudience),
    showActivityStatus: showActivityStatus,
    showSportLevels: showSportLevels,
    showGoals: showGoals,
    showLocation: showLocation,
    followerListAudience: FollowerListAudience.values.byName(
      followerListAudience,
    ),
    hideLikeCounts: hideLikeCounts,
    discoverableByUsername: discoverableByUsername,
    personalizedSuggestions: personalizedSuggestions,
  );
}
