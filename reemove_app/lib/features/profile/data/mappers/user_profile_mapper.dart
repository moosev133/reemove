import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/user_profile.dart';
import '../dto/user_profile_dto.dart';

extension UserProfileDtoMapper on UserProfileDto {
  UserProfile toDomain() => UserProfile(
    uid: uid,
    username: username,
    usernameNormalized: usernameNormalized,
    displayName: displayName,
    bio: bio,
    avatarUrl: avatarUrl,
    role: UserRole.values.byName(role),
    isVerified: isVerified,
    verificationType: VerificationType.values.byName(verificationType),
    favoriteSportIds: favoriteSportIds,
    sportLevels: sportLevels.map(
      (String sportId, String level) => MapEntry<String, SportLevel>(
        sportId,
        SportLevel.values.byName(level),
      ),
    ),
    goals: goals,
    location: location?.toDomain(),
    discoveryRadiusKm: discoveryRadiusKm,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    followersCount: followersCount,
    followingCount: followingCount,
    postsCount: postsCount,
    onboardingCompleted: onboardingCompleted,
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
  );
}
