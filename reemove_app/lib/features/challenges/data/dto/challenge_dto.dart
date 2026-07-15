import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/dto/media_asset_dto.dart';
import '../../../../core/database/firestore_parser.dart';

class ChallengeRuleDto {
  const ChallengeRuleDto({
    required this.metric,
    required this.target,
    required this.unit,
    required this.verificationMethod,
  });

  factory ChallengeRuleDto.fromMap(FirestoreMap data) => ChallengeRuleDto(
    metric: FirestoreParser.string(data, 'metric'),
    target: FirestoreParser.number(data, 'target'),
    unit: FirestoreParser.string(data, 'unit'),
    verificationMethod: FirestoreParser.string(data, 'verificationMethod'),
  );

  final String metric;
  final double target;
  final String unit;
  final String verificationMethod;

  FirestoreMap toMap() => <String, Object?>{
    'metric': metric,
    'target': target,
    'unit': unit,
    'verificationMethod': verificationMethod,
  };
}

class ChallengeDto {
  const ChallengeDto({
    required this.id,
    required this.creatorId,
    required this.sportId,
    required this.title,
    required this.description,
    required this.source,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.rules,
    required this.media,
    required this.participantCount,
    required this.rewardIds,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    this.badgeId,
  });

  factory ChallengeDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Challenge ${snapshot.id} has no data.');
    }
    return ChallengeDto(
      id: snapshot.id,
      creatorId: FirestoreParser.string(data, 'creatorId'),
      sportId: FirestoreParser.string(data, 'sportId'),
      title: FirestoreParser.string(data, 'title'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      source: FirestoreParser.string(data, 'source'),
      status: FirestoreParser.string(data, 'status'),
      startsAt: FirestoreParser.dateTime(data, 'startsAt'),
      endsAt: FirestoreParser.dateTime(data, 'endsAt'),
      rules: FirestoreParser.mapList(
        data,
        'rules',
      ).map(ChallengeRuleDto.fromMap).toList(growable: false),
      media: FirestoreParser.mapList(
        data,
        'media',
      ).map(MediaAssetDto.fromMap).toList(growable: false),
      participantCount: FirestoreParser.integer(
        data,
        'participantCount',
        fallback: 0,
      ),
      badgeId: FirestoreParser.nullableString(data, 'badgeId'),
      rewardIds: FirestoreParser.stringList(data, 'rewardIds'),
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
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String creatorId;
  final String sportId;
  final String title;
  final String description;
  final String source;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<ChallengeRuleDto> rules;
  final List<MediaAssetDto> media;
  final int participantCount;
  final String? badgeId;
  final List<String> rewardIds;
  final String visibility;
  final String moderationState;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'creatorId': creatorId,
    'sportId': sportId,
    'title': title,
    'description': description,
    'source': source,
    'status': status,
    'startsAt': Timestamp.fromDate(startsAt.toUtc()),
    'endsAt': Timestamp.fromDate(endsAt.toUtc()),
    'rules': rules.map((ChallengeRuleDto item) => item.toMap()).toList(),
    'media': media.map((MediaAssetDto item) => item.toMap()).toList(),
    'participantCount': participantCount,
    if (badgeId != null) 'badgeId': badgeId,
    'rewardIds': rewardIds,
    'visibility': visibility,
    'moderationState': moderationState,
    ...audit.toMap(),
  };
}
