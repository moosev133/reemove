import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/features/profile/data/dto/user_profile_dto.dart';
import 'package:reemove/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:reemove/features/profile/domain/entities/profile_privacy_settings.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';

void main() {
  test('maps the complete public profile document to the domain model', () {
    final DateTime now = DateTime.utc(2026, 7, 13, 12);
    final UserProfileDto dto = UserProfileDto.fromMap(<String, dynamic>{
      'uid': 'trainer-1',
      'username': 'Coach Move',
      'usernameNormalized': 'coach_move',
      'displayName': 'Coach Move',
      'bio': 'Strength coach and runner.',
      'avatarUrl': 'https://cdn.reemove.app/avatar.jpg',
      'coverUrl': 'https://cdn.reemove.app/cover.jpg',
      'websiteUrl': 'https://coach.example',
      'primarySportId': 'gym',
      'role': 'trainer',
      'isVerified': true,
      'verificationType': 'trainer',
      'professionalDetails': <String, dynamic>{
        'headline': 'Certified strength coach',
        'organization': 'ReeMove Performance',
        'positionOrCategory': 'Personal trainer',
        'yearsExperience': 7,
        'specialties': <String>['strength', 'mobility'],
        'acceptingClients': true,
      },
      'favoriteSportIds': <String>['gym', 'running'],
      'sportLevels': <String, String>{
        'gym': 'professional',
        'running': 'advanced',
      },
      'goals': <String>['community', 'performance'],
      'location': const GeoPoint(32.8, 35),
      'geohash': 'sv8x',
      'locality': 'Haifa',
      'countryCode': 'IL',
      'discoveryRadiusKm': 25,
      'visibility': 'followers',
      'followApprovalPolicy': 'approvalRequired',
      'followersCount': 1200,
      'followingCount': 82,
      'postsCount': 34,
      'reelsCount': 11,
      'onboardingCompleted': true,
      'moderationState': 'active',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'schemaVersion': 2,
    }, documentId: 'trainer-1');

    final UserProfile profile = dto.toDomain();

    expect(profile.uid, 'trainer-1');
    expect(profile.role, UserRole.trainer);
    expect(profile.verificationType, VerificationType.trainer);
    expect(profile.isVerified, isTrue);
    expect(profile.primarySportId, 'gym');
    expect(profile.professionalDetails.headline, 'Certified strength coach');
    expect(profile.professionalDetails.yearsExperience, 7);
    expect(profile.professionalDetails.acceptingClients, isTrue);
    expect(profile.sportLevels['gym'], SportLevel.professional);
    expect(profile.visibility, Visibility.followers);
    expect(profile.followApprovalPolicy, FollowApprovalPolicy.approvalRequired);
    expect(profile.location?.locality, 'Haifa');
    expect(profile.reelsCount, 11);
    expect(profile.audit.createdAt, now);
    expect(profile.audit.schemaVersion, 2);
  });

  test('parses sparse private-preview payload from getPublicProfile', () {
    final UserProfile profile = UserProfileDto.fromMap(<String, dynamic>{
      'uid': 'private-1',
      'username': 'mustafaabualhija',
      'displayName': 'Mustafa',
      'bio': 'Private athlete',
      'avatarUrl': 'https://cdn.reemove.app/a.jpg',
      'visibility': 'followers',
      'accountPrivacy': 'private',
      'isVerified': false,
      'verificationType': 'none',
      'followersCount': 3,
      'followingCount': 1,
      'postsCount': 9,
      'reelsCount': 2,
    }, documentId: 'private-1').toDomain();

    expect(profile.usernameNormalized, 'mustafaabualhija');
    expect(profile.displayName, 'Mustafa');
    expect(profile.bio, 'Private athlete');
    expect(profile.avatarUrl, 'https://cdn.reemove.app/a.jpg');
    expect(profile.followersCount, 3);
    expect(profile.followingCount, 1);
    expect(profile.postsCount, 9);
    expect(profile.reelsCount, 2);
    expect(profile.websiteUrl, isNull);
    expect(profile.location, isNull);
  });

  test('uses backward-compatible defaults for older profile documents', () {
    final DateTime now = DateTime.utc(2026, 7, 13, 12);
    final UserProfile profile = UserProfileDto.fromMap(<String, dynamic>{
      'uid': 'athlete-legacy',
      'username': 'legacy',
      'usernameNormalized': 'legacy',
      'displayName': 'Legacy Athlete',
      'favoriteSportIds': <String>[],
      'sportLevels': <String, String>{},
      'goals': <String>[],
      'visibility': 'public',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, documentId: 'athlete-legacy').toDomain();

    expect(profile.role, UserRole.athlete);
    expect(profile.verificationType, VerificationType.none);
    expect(profile.followApprovalPolicy, FollowApprovalPolicy.automatic);
    expect(profile.reelsCount, 0);
    expect(profile.professionalDetails.isEmpty, isTrue);
  });
}
