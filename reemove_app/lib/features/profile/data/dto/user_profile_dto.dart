import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/dto/geo_location_dto.dart';
import '../../../../core/database/firestore_parser.dart';

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
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.onboardingCompleted,
    required this.moderationState,
    required this.audit,
    this.avatarUrl,
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
      role: FirestoreParser.string(data, 'role', fallback: 'athlete'),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      verificationType: FirestoreParser.string(
        data,
        'verificationType',
        fallback: 'none',
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
  final String role;
  final bool isVerified;
  final String verificationType;
  final List<String> favoriteSportIds;
  final Map<String, String> sportLevels;
  final List<String> goals;
  final GeoLocationDto? location;
  final double discoveryRadiusKm;
  final String visibility;
  final int followersCount;
  final int followingCount;
  final int postsCount;
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
    'role': role,
    'isVerified': isVerified,
    'verificationType': verificationType,
    'favoriteSportIds': favoriteSportIds,
    'sportLevels': sportLevels,
    'goals': goals,
    if (location != null) ...location!.toMap(),
    'discoveryRadiusKm': discoveryRadiusKm,
    'visibility': visibility,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'postsCount': postsCount,
    'onboardingCompleted': onboardingCompleted,
    'moderationState': moderationState,
    ...audit.toMap(),
  };
}
