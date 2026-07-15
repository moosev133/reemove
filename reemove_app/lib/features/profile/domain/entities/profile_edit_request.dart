import 'profile_privacy_settings.dart';

class ProfessionalProfileInput {
  const ProfessionalProfileInput({
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

  Map<String, Object?> toJson() => <String, Object?>{
    'headline': headline,
    'organization': organization,
    'positionOrCategory': positionOrCategory,
    'yearsExperience': yearsExperience,
    'specialties': specialties,
    'acceptingClients': acceptingClients,
  };
}

class ProfileEditRequest {
  const ProfileEditRequest({
    required this.displayName,
    required this.bio,
    required this.favoriteSportIds,
    required this.goals,
    required this.visibility,
    required this.privacy,
    this.username,
    this.avatarUrl,
    this.avatarStoragePath,
    this.coverUrl,
    this.coverStoragePath,
    this.websiteUrl,
    this.primarySportId,
    this.professional,
  });

  final String displayName;
  final String? username;
  final String bio;
  final String? avatarUrl;
  final String? avatarStoragePath;
  final String? coverUrl;
  final String? coverStoragePath;
  final String? websiteUrl;
  final String? primarySportId;
  final List<String> favoriteSportIds;
  final List<String> goals;
  final String visibility;
  final ProfessionalProfileInput? professional;
  final ProfilePrivacySettings privacy;
}
