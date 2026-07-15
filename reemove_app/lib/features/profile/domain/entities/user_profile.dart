import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';

enum UserRole { athlete, trainer, business, admin }

enum SportLevel { beginner, intermediate, advanced, professional }

enum VerificationType { none, athlete, trainer, business }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.username,
    required this.usernameNormalized,
    required this.displayName,
    required this.bio,
    required this.role,
    required this.isVerified,
    required this.verificationType,
    required this.favoriteSportIds,
    required this.sportLevels,
    required this.goals,
    required this.discoveryRadiusKm,
    required this.visibility,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.onboardingCompleted,
    required this.moderationState,
    required this.audit,
    this.avatarUrl,
    this.location,
  });

  final String uid;
  final String username;
  final String usernameNormalized;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final UserRole role;
  final bool isVerified;
  final VerificationType verificationType;
  final List<String> favoriteSportIds;
  final Map<String, SportLevel> sportLevels;
  final List<String> goals;
  final GeoLocation? location;
  final double discoveryRadiusKm;
  final Visibility visibility;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool onboardingCompleted;
  final ModerationState moderationState;
  final EntityAudit audit;
}
