import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/database/firestore_parser.dart';
import 'package:reemove/features/profile/data/dto/user_profile_dto.dart';
import 'package:reemove/features/profile/data/mappers/user_profile_mapper.dart';
import 'package:reemove/features/profile/domain/entities/profile_relationship.dart';
import 'package:reemove/features/profile/domain/entities/profile_surface.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';

/// Exact wire shape observed from staging getPublicProfile preview for
/// @mustafaabualhija when Timestamps ride the HTTPS callable JSON channel.
Map<String, dynamic> stagingPrivatePreviewWireShape() => <String, dynamic>{
  'uid': 'rAVFw0NRryd4nYjXMUU2qjIDUAy1',
  'username': 'mustafaabualhija',
  'usernameNormalized': 'mustafaabualhija',
  'displayName': 'Mostafa Abo alheja',
  'bio': 'a gym rat!',
  'avatarUrl':
      'https://lh3.googleusercontent.com/a/ACg8ocIeW1W-oHy_yTl5tAsfyByAvwSPbrVxIjiWOnyNsgtbACge0rGz=s96-c',
  'visibility': 'followers',
  'accountPrivacy': 'private',
  'isVerified': false,
  'verificationType': 'none',
  'followersCount': 0,
  'followingCount': 0,
  'postsCount': 1,
  'reelsCount': 0,
  'moderationState': 'active',
  'followApprovalPolicy': 'approvalRequired',
  'schemaVersion': 1,
  // Pre-fix callable payload: raw Timestamp objects become these maps.
  'createdAt': <String, dynamic>{
    '_seconds': 1752944939,
    '_nanoseconds': 660000000,
  },
  'updatedAt': <String, dynamic>{
    '_seconds': 1753111279,
    '_nanoseconds': 205000000,
  },
};

Map<String, dynamic> stagingPrivatePreviewIsoShape() {
  final Map<String, dynamic> map = stagingPrivatePreviewWireShape();
  map['createdAt'] = '2025-07-19T17:08:59.660Z';
  map['updatedAt'] = '2025-07-21T15:21:19.205Z';
  return map;
}

void main() {
  group('callable timestamp decoding', () {
    test('parses Firestore Timestamp map wire format', () {
      final DateTime? created = FirestoreParser.nullableDateTime(
        stagingPrivatePreviewWireShape(),
        'createdAt',
      );
      expect(created, isNotNull);
      expect(created!.isUtc, isTrue);
    });

    test('parses ISO strings from normalized callable preview', () {
      final DateTime? created = FirestoreParser.nullableDateTime(
        stagingPrivatePreviewIsoShape(),
        'createdAt',
      );
      expect(created, DateTime.parse('2025-07-19T17:08:59.660Z').toUtc());
    });
  });

  group('staging getPublicProfile preview wire shape', () {
    test(
      'parses the exact map-timestamp payload that caused Couldn’t load profile',
      () {
        final UserProfile profile = UserProfileDto.fromMap(
          stagingPrivatePreviewWireShape(),
          documentId: 'rAVFw0NRryd4nYjXMUU2qjIDUAy1',
        ).toDomain();

        expect(profile.uid, 'rAVFw0NRryd4nYjXMUU2qjIDUAy1');
        expect(profile.username, 'mustafaabualhija');
        expect(profile.usernameNormalized, 'mustafaabualhija');
        expect(profile.displayName, 'Mostafa Abo alheja');
        expect(profile.bio, 'a gym rat!');
        expect(profile.avatarUrl, isNotNull);
        expect(profile.followersCount, 0);
        expect(profile.followingCount, 0);
        expect(profile.postsCount, 1);
        expect(profile.isVerified, isFalse);
        expect(profile.websiteUrl, isNull);
        expect(profile.location, isNull);
        expect(profile.audit.createdAt, isNotNull);
      },
    );

    test('parses normalized ISO preview payload from deployed callable', () {
      final UserProfile profile = UserProfileDto.fromMap(
        stagingPrivatePreviewIsoShape(),
        documentId: 'rAVFw0NRryd4nYjXMUU2qjIDUAy1',
      ).toDomain();
      expect(profile.displayName, 'Mostafa Abo alheja');
      expect(profile.bio, 'a gym rat!');
    });

    test('builds a private preview surface for a stranger relationship', () {
      final UserProfile profile = UserProfileDto.fromMap(
        stagingPrivatePreviewWireShape(),
        documentId: 'rAVFw0NRryd4nYjXMUU2qjIDUAy1',
      ).toDomain();
      final ProfileSurface surface = ProfileSurface(
        access: ProfileAccessLevel.preview,
        profile: profile,
        relationship: const ProfileRelationship(
          viewerId: 'SXYHRzqwvnawTyxgEEdpfwNqRnG2',
          profileId: 'rAVFw0NRryd4nYjXMUU2qjIDUAy1',
          state: FollowRelationshipState.none,
          canMessage: false,
          canViewFollowers: true,
          canViewProfile: false,
        ),
      );
      expect(surface.isPreview, isTrue);
      expect(surface.profile?.username, 'mustafaabualhija');
      expect(surface.relationship.canViewProfile, isFalse);
    });
  });
}
