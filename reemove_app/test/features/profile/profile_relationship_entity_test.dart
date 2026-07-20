import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/profile/domain/entities/profile_relationship.dart';
import 'package:reemove/features/profile/domain/entities/profile_surface.dart';

void main() {
  test('ProfileRelationship defaults canViewProfile to true', () {
    const ProfileRelationship relationship = ProfileRelationship(
      viewerId: 'viewer',
      profileId: 'profile',
      state: FollowRelationshipState.none,
      canMessage: false,
      canViewFollowers: false,
    );

    expect(relationship.canViewProfile, isTrue);
  });

  test('ProfileSurface exposes preview state', () {
    const ProfileSurface surface = ProfileSurface(
      access: ProfileAccessLevel.preview,
      relationship: ProfileRelationship(
        viewerId: 'viewer',
        profileId: 'profile',
        state: FollowRelationshipState.requestSent,
        canMessage: false,
        canViewFollowers: false,
        canViewProfile: false,
      ),
    );

    expect(surface.isPreview, isTrue);
  });
}
