import 'profile_relationship.dart';
import 'user_profile.dart';

enum ProfileAccessLevel { full, preview, unavailable }

class ProfileSurface {
  const ProfileSurface({
    required this.access,
    this.profile,
    required this.relationship,
  });

  final ProfileAccessLevel access;
  final UserProfile? profile;
  final ProfileRelationship relationship;

  bool get isPreview => access == ProfileAccessLevel.preview;
}
