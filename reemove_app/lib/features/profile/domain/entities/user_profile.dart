import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import 'profile_privacy_settings.dart';

enum UserRole { athlete, trainer, business, admin }

enum SportLevel { beginner, intermediate, advanced, professional }

enum VerificationType { none, athlete, trainer, business }

class ProfessionalProfileDetails {
  const ProfessionalProfileDetails({
    this.headline,
    this.organization,
    this.positionOrCategory,
    this.yearsExperience,
    this.specialties = const <String>[],
    this.acceptingClients = false,
  });

  final String? headline;
  final String? organization;
  final String? positionOrCategory;
  final int? yearsExperience;
  final List<String> specialties;
  final bool acceptingClients;

  bool get isEmpty =>
      headline == null &&
      organization == null &&
      positionOrCategory == null &&
      yearsExperience == null &&
      specialties.isEmpty &&
      !acceptingClients;
}

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
    required this.followApprovalPolicy,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.reelsCount,
    required this.onboardingCompleted,
    required this.moderationState,
    required this.audit,
    this.avatarUrl,
    this.coverUrl,
    this.websiteUrl,
    this.primarySportId,
    this.professionalDetails = const ProfessionalProfileDetails(),
    this.location,
  });

  final String uid;
  final String username;
  final String usernameNormalized;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? websiteUrl;
  final String? primarySportId;
  final UserRole role;
  final bool isVerified;
  final VerificationType verificationType;
  final ProfessionalProfileDetails professionalDetails;
  final List<String> favoriteSportIds;
  final Map<String, SportLevel> sportLevels;
  final List<String> goals;
  final GeoLocation? location;
  final double discoveryRadiusKm;
  final Visibility visibility;
  final FollowApprovalPolicy followApprovalPolicy;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int reelsCount;
  final bool onboardingCompleted;
  final ModerationState moderationState;
  final EntityAudit audit;

  String get profileLabel => switch (role) {
    UserRole.athlete => 'Athlete',
    UserRole.trainer => 'Trainer',
    UserRole.business => 'Sports business',
    UserRole.admin => 'ReeMove team',
  };
}
