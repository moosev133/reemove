import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../../core/database/firestore_parser.dart';

class SportCommunityDto {
  const SportCommunityDto({
    required this.id,
    required this.sportId,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.type,
    required this.joinPolicy,
    required this.memberCount,
    required this.capacity,
    required this.tags,
    required this.city,
    required this.countryCode,
    required this.isVerified,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    this.avatarUrl,
    this.coverUrl,
    this.pricingText,
  });

  factory SportCommunityDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Community ${snapshot.id} has no data.');
    }
    return SportCommunityDto(
      id: snapshot.id,
      sportId: FirestoreParser.string(data, 'sportId'),
      ownerId: FirestoreParser.string(data, 'ownerId'),
      name: FirestoreParser.string(data, 'name'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      type: FirestoreParser.string(data, 'type', fallback: 'socialGroup'),
      joinPolicy: FirestoreParser.string(data, 'joinPolicy', fallback: 'open'),
      memberCount: FirestoreParser.integer(data, 'memberCount', fallback: 0),
      capacity: FirestoreParser.integer(data, 'capacity', fallback: 0),
      tags: FirestoreParser.stringList(data, 'tags'),
      city: FirestoreParser.string(data, 'city', fallback: ''),
      countryCode: FirestoreParser.string(data, 'countryCode', fallback: ''),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      visibility: FirestoreParser.string(
        data,
        'visibility',
        fallback: 'public',
      ),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      coverUrl: FirestoreParser.nullableString(data, 'coverUrl'),
      pricingText: FirestoreParser.nullableString(data, 'pricingText'),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String sportId;
  final String ownerId;
  final String name;
  final String description;
  final String type;
  final String joinPolicy;
  final int memberCount;
  final int capacity;
  final List<String> tags;
  final String city;
  final String countryCode;
  final bool isVerified;
  final String visibility;
  final String moderationState;
  final String? avatarUrl;
  final String? coverUrl;
  final String? pricingText;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'sportId': sportId,
    'ownerId': ownerId,
    'name': name,
    'description': description,
    'type': type,
    'joinPolicy': joinPolicy,
    'memberCount': memberCount,
    'capacity': capacity,
    'tags': tags,
    'city': city,
    'countryCode': countryCode,
    'isVerified': isVerified,
    'visibility': visibility,
    'moderationState': moderationState,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (pricingText != null) 'pricingText': pricingText,
    ...audit.toMap(),
  };
}

class SportCommunityMemberDto {
  const SportCommunityMemberDto({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.status,
    required this.joinedAt,
    this.avatarUrl,
    this.sportLevel,
  });

  factory SportCommunityMemberDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Community member ${snapshot.id} has no data.');
    }
    final FirestoreMap profile = FirestoreParser.map(data, 'userSnapshot');
    return SportCommunityMemberDto(
      userId: snapshot.id,
      displayName: FirestoreParser.string(
        profile,
        'displayName',
        fallback: 'Athlete',
      ),
      username: FirestoreParser.string(profile, 'username', fallback: ''),
      status: FirestoreParser.string(data, 'role', fallback: 'member'),
      joinedAt: FirestoreParser.dateTime(data, 'joinedAt'),
      avatarUrl: FirestoreParser.nullableString(profile, 'avatarUrl'),
      sportLevel: FirestoreParser.nullableString(data, 'sportLevel'),
    );
  }

  final String userId;
  final String displayName;
  final String username;
  final String status;
  final DateTime joinedAt;
  final String? avatarUrl;
  final String? sportLevel;
}
