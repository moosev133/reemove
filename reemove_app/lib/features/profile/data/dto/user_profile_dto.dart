import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/dto/geo_location_dto.dart';
import '../../../../core/database/firestore_parser.dart';

class ProfessionalProfileDetailsDto {
  const ProfessionalProfileDetailsDto({
    this.headline,
    this.organization,
    this.positionOrCategory,
    this.yearsExperience,
    this.specialties = const <String>[],
    this.acceptingClients = false,
  });

  factory ProfessionalProfileDetailsDto.fromMap(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const ProfessionalProfileDetailsDto();
    }
    return ProfessionalProfileDetailsDto(
      headline: value['headline'] is String
          ? value['headline'] as String
          : null,
      organization: value['organization'] is String
          ? value['organization'] as String
          : null,
      positionOrCategory: value['positionOrCategory'] is String
          ? value['positionOrCategory'] as String
          : null,
      yearsExperience: value['yearsExperience'] is num
          ? (value['yearsExperience'] as num).toInt()
          : null,
      specialties: value['specialties'] is List
          ? (value['specialties'] as List<dynamic>).whereType<String>().toList(
              growable: false,
            )
          : const <String>[],
      acceptingClients: value['acceptingClients'] == true,
    );
  }

  final String? headline;
  final String? organization;
  final String? positionOrCategory;
  final int? yearsExperience;
  final List<String> specialties;
  final bool acceptingClients;

  FirestoreMap toMap() => <String, dynamic>{
    if (headline != null) 'headline': headline,
    if (organization != null) 'organization': organization,
    if (positionOrCategory != null) 'positionOrCategory': positionOrCategory,
    if (yearsExperience != null) 'yearsExperience': yearsExperience,
    'specialties': specialties,
    'acceptingClients': acceptingClients,
  };
}

class UserProfileDto {
  const UserProfileDto({
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
    required this.professionalDetails,
    this.avatarUrl,
    this.coverUrl,
    this.websiteUrl,
    this.primarySportId,
    this.location,
  });

  factory UserProfileDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('User document ${snapshot.id} has no data.');
    }
    return UserProfileDto.fromMap(data, documentId: snapshot.id);
  }

  factory UserProfileDto.fromMap(
    FirestoreMap data, {
    required String documentId,
  }) {
    final Object? locationValue = data['location'];
    return UserProfileDto(
      uid: FirestoreParser.string(data, 'uid', fallback: documentId),
      username: FirestoreParser.string(data, 'username'),
      usernameNormalized: FirestoreParser.string(data, 'usernameNormalized'),
      displayName: FirestoreParser.string(data, 'displayName'),
      bio: FirestoreParser.string(data, 'bio', fallback: ''),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      coverUrl: FirestoreParser.nullableString(data, 'coverUrl'),
      websiteUrl: FirestoreParser.nullableString(data, 'websiteUrl'),
      primarySportId: FirestoreParser.nullableString(data, 'primarySportId'),
      role: FirestoreParser.string(data, 'role', fallback: 'athlete'),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      verificationType: FirestoreParser.string(
        data,
        'verificationType',
        fallback: 'none',
      ),
      professionalDetails: ProfessionalProfileDetailsDto.fromMap(
        data['professionalDetails'],
      ),
      favoriteSportIds: FirestoreParser.stringList(data, 'favoriteSportIds'),
      sportLevels: FirestoreParser.stringMap(data, 'sportLevels'),
      goals: FirestoreParser.stringList(data, 'goals'),
      location: locationValue == null ? null : GeoLocationDto.fromMap(data),
      discoveryRadiusKm: FirestoreParser.number(
        data,
        'discoveryRadiusKm',
        fallback: 25,
      ),
      visibility: FirestoreParser.string(
        data,
        'visibility',
        fallback: 'public',
      ),
      followApprovalPolicy: FirestoreParser.string(
        data,
        'followApprovalPolicy',
        fallback: data['visibility'] == 'public'
            ? 'automatic'
            : 'approvalRequired',
      ),
      followersCount: FirestoreParser.integer(
        data,
        'followersCount',
        fallback: 0,
      ),
      followingCount: FirestoreParser.integer(
        data,
        'followingCount',
        fallback: 0,
      ),
      postsCount: FirestoreParser.integer(data, 'postsCount', fallback: 0),
      reelsCount: FirestoreParser.integer(data, 'reelsCount', fallback: 0),
      onboardingCompleted: FirestoreParser.boolean(
        data,
        'onboardingCompleted',
        fallback: false,
      ),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String uid;
  final String username;
  final String usernameNormalized;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? websiteUrl;
  final String? primarySportId;
  final String role;
  final bool isVerified;
  final String verificationType;
  final ProfessionalProfileDetailsDto professionalDetails;
  final List<String> favoriteSportIds;
  final Map<String, String> sportLevels;
  final List<String> goals;
  final GeoLocationDto? location;
  final double discoveryRadiusKm;
  final String visibility;
  final String followApprovalPolicy;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int reelsCount;
  final bool onboardingCompleted;
  final String moderationState;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'uid': uid,
    'username': username,
    'usernameNormalized': usernameNormalized,
    'displayName': displayName,
    'bio': bio,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (websiteUrl != null) 'websiteUrl': websiteUrl,
    if (primarySportId != null) 'primarySportId': primarySportId,
    'role': role,
    'isVerified': isVerified,
    'verificationType': verificationType,
    'professionalDetails': professionalDetails.toMap(),
    'favoriteSportIds': favoriteSportIds,
    'sportLevels': sportLevels,
    'goals': goals,
    if (location != null) ...location!.toMap(),
    'discoveryRadiusKm': discoveryRadiusKm,
    'visibility': visibility,
    'followApprovalPolicy': followApprovalPolicy,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'postsCount': postsCount,
    'reelsCount': reelsCount,
    'onboardingCompleted': onboardingCompleted,
    'moderationState': moderationState,
    ...audit.toMap(),
  };
}
