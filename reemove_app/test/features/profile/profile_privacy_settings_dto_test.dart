import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/profile/data/dto/profile_privacy_settings_dto.dart';
import 'package:reemove/features/profile/domain/entities/profile_privacy_settings.dart';

void main() {
  group('ProfilePrivacySettingsDto', () {
    test('maps every audience and visibility preference', () {
      final ProfilePrivacySettings settings =
          ProfilePrivacySettingsDto.fromMap(<String, dynamic>{
            'followApprovalPolicy': 'approvalRequired',
            'messageAudience': 'followers',
            'messageRequestAudience': 'everyone',
            'mentionAudience': 'noOne',
            'tagAudience': 'followers',
            'showActivityStatus': false,
            'showSportLevels': false,
            'showGoals': true,
            'showLocation': false,
            'followerListAudience': 'followers',
            'hideLikeCounts': true,
            'discoverableByUsername': false,
            'personalizedSuggestions': false,
          }).toDomain();

      expect(
        settings.followApprovalPolicy,
        FollowApprovalPolicy.approvalRequired,
      );
      expect(settings.messageAudience, ProfileAudience.followers);
      expect(settings.messageRequestAudience, ProfileAudience.everyone);
      expect(settings.mentionAudience, ProfileAudience.noOne);
      expect(settings.showActivityStatus, isFalse);
      expect(settings.followerListAudience, FollowerListAudience.followers);
      expect(settings.showFollowerLists, isTrue);
      expect(settings.hideLikeCounts, isTrue);
      expect(settings.discoverableByUsername, isFalse);
    });

    test('maps legacy showFollowerLists false to owner-only lists', () {
      final ProfilePrivacySettings settings = ProfilePrivacySettingsDto.fromMap(
        <String, dynamic>{'showFollowerLists': false},
      ).toDomain();

      expect(settings.followerListAudience, FollowerListAudience.owner);
      expect(settings.showFollowerLists, isFalse);
    });

    test('supplies privacy-safe documented defaults for missing fields', () {
      final ProfilePrivacySettings settings = ProfilePrivacySettingsDto.fromMap(
        const <String, dynamic>{},
      ).toDomain();

      expect(settings.followApprovalPolicy, FollowApprovalPolicy.automatic);
      expect(settings.messageAudience, ProfileAudience.everyone);
      expect(settings.messageRequestAudience, ProfileAudience.noOne);
      expect(settings.tagAudience, ProfileAudience.followers);
      expect(settings.showActivityStatus, isTrue);
      expect(settings.followerListAudience, FollowerListAudience.everyone);
      expect(settings.showFollowerLists, isTrue);
      expect(settings.hideLikeCounts, isFalse);
    });
  });
}
