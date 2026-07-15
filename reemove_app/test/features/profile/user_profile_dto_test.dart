import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/features/profile/data/dto/user_profile_dto.dart';
import 'package:reemove/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';

void main() {
  test(
    'maps a Firestore user document to the provider-neutral domain model',
    () {
      final DateTime now = DateTime.utc(2026, 7, 13, 12);
      final UserProfileDto dto = UserProfileDto.fromMap(<String, dynamic>{
        'uid': 'athlete-1',
        'username': 'athlete_1',
        'usernameNormalized': 'athlete_1',
        'displayName': 'Athlete One',
        'bio': 'Runner and football player',
        'role': 'athlete',
        'isVerified': false,
        'verificationType': 'none',
        'favoriteSportIds': <String>['football', 'running'],
        'sportLevels': <String, String>{
          'football': 'intermediate',
          'running': 'advanced',
        },
        'goals': <String>['community'],
        'location': const GeoPoint(32.8, 35),
        'geohash': 'sv8x',
        'discoveryRadiusKm': 25,
        'visibility': 'public',
        'followersCount': 10,
        'followingCount': 5,
        'postsCount': 3,
        'onboardingCompleted': true,
        'moderationState': 'active',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'schemaVersion': 1,
      }, documentId: 'athlete-1');

      final UserProfile profile = dto.toDomain();

      expect(profile.uid, 'athlete-1');
      expect(profile.role, UserRole.athlete);
      expect(profile.sportLevels['running'], SportLevel.advanced);
      expect(profile.visibility, Visibility.public);
      expect(profile.location?.latitude, 32.8);
      expect(profile.audit.createdAt, now);
    },
  );
}
