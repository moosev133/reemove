import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/profile_privacy_settings.dart';
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
    coverUrl: coverUrl,
    websiteUrl: websiteUrl,
    primarySportId: primarySportId,
    role: UserRole.values.byName(role),
    isVerified: isVerified,
    verificationType: VerificationType.values.byName(verificationType),
    professionalDetails: ProfessionalProfileDetails(
      headline: professionalDetails.headline,
      organization: professionalDetails.organization,
      positionOrCategory: professionalDetails.positionOrCategory,
      yearsExperience: professionalDetails.yearsExperience,
      specialties: professionalDetails.specialties,
      acceptingClients: professionalDetails.acceptingClients,
    ),
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
    followApprovalPolicy: FollowApprovalPolicy.values.byName(
      followApprovalPolicy,
    ),
    followersCount: followersCount,
    followingCount: followingCount,
    postsCount: postsCount,
    reelsCount: reelsCount,
    onboardingCompleted: onboardingCompleted,
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
  );
}
