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
    required this.maximumDailyProgress,
  });

  factory ChallengeRuleDto.fromMap(FirestoreMap data) => ChallengeRuleDto(
    metric: FirestoreParser.string(data, 'metric'),
    target: FirestoreParser.number(data, 'target'),
    unit: FirestoreParser.string(data, 'unit'),
    verificationMethod: FirestoreParser.string(data, 'verificationMethod'),
    maximumDailyProgress: FirestoreParser.number(
      data,
      'maximumDailyProgress',
      fallback: FirestoreParser.number(data, 'target'),
    ),
  );

  final String metric;
  final double target;
  final String unit;
  final String verificationMethod;
  final double maximumDailyProgress;

  FirestoreMap toMap() => <String, Object?>{
    'metric': metric,
    'target': target,
    'unit': unit,
    'verificationMethod': verificationMethod,
    'maximumDailyProgress': maximumDailyProgress,
  };
}

class ChallengeSafetyPolicyDto {
  const ChallengeSafetyPolicyDto({
    required this.minimumAge,
    required this.requiresRestDays,
    required this.maximumEffortMinutesPerDay,
    required this.prohibitedBehaviors,
    required this.healthDisclaimer,
  });

  factory ChallengeSafetyPolicyDto.fromMap(
    FirestoreMap data,
  ) => ChallengeSafetyPolicyDto(
    minimumAge: FirestoreParser.integer(data, 'minimumAge', fallback: 14),
    requiresRestDays: FirestoreParser.boolean(
      data,
      'requiresRestDays',
      fallback: true,
    ),
    maximumEffortMinutesPerDay: FirestoreParser.integer(
      data,
      'maximumEffortMinutesPerDay',
      fallback: 120,
    ),
    prohibitedBehaviors: FirestoreParser.stringList(
      data,
      'prohibitedBehaviors',
    ),
    healthDisclaimer: FirestoreParser.string(
      data,
      'healthDisclaimer',
      fallback:
          'Stop if you feel pain, dizziness, or unusual discomfort and seek qualified help.',
    ),
  );

  final int minimumAge;
  final bool requiresRestDays;
  final int maximumEffortMinutesPerDay;
  final List<String> prohibitedBehaviors;
  final String healthDisclaimer;

  FirestoreMap toMap() => <String, Object?>{
    'minimumAge': minimumAge,
    'requiresRestDays': requiresRestDays,
    'maximumEffortMinutesPerDay': maximumEffortMinutesPerDay,
    'prohibitedBehaviors': prohibitedBehaviors,
    'healthDisclaimer': healthDisclaimer,
  };
}

class ChallengeDto {
  const ChallengeDto({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.sportId,
    required this.title,
    required this.description,
    required this.source,
    required this.status,
    required this.difficulty,
    required this.startsAt,
    required this.endsAt,
    required this.rules,
    required this.safetyPolicy,
    required this.media,
    required this.participantCount,
    required this.completionCount,
    required this.rewardIds,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    required this.isFeatured,
    this.badgeId,
    this.communityId,
    this.aiDisclosure,
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
      creatorName: FirestoreParser.string(
        data,
        'creatorName',
        fallback: 'ReeMove',
      ),
      sportId: FirestoreParser.string(data, 'sportId'),
      title: FirestoreParser.string(data, 'title'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      source: FirestoreParser.string(data, 'source'),
      status: FirestoreParser.string(data, 'status'),
      difficulty: FirestoreParser.string(
        data,
        'difficulty',
        fallback: 'beginner',
      ),
      startsAt: FirestoreParser.dateTime(data, 'startsAt'),
      endsAt: FirestoreParser.dateTime(data, 'endsAt'),
      rules: FirestoreParser.mapList(
        data,
        'rules',
      ).map(ChallengeRuleDto.fromMap).toList(growable: false),
      safetyPolicy: ChallengeSafetyPolicyDto.fromMap(
        FirestoreParser.map(data, 'safetyPolicy'),
      ),
      media: FirestoreParser.mapList(
        data,
        'media',
      ).map(MediaAssetDto.fromMap).toList(growable: false),
      participantCount: FirestoreParser.integer(
        data,
        'participantCount',
        fallback: 0,
      ),
      completionCount: FirestoreParser.integer(
        data,
        'completionCount',
        fallback: 0,
      ),
      badgeId: FirestoreParser.nullableString(data, 'badgeId'),
      rewardIds: FirestoreParser.stringList(data, 'rewardIds'),
      communityId: FirestoreParser.nullableString(data, 'communityId'),
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
      isFeatured: FirestoreParser.boolean(data, 'isFeatured', fallback: false),
      aiDisclosure: FirestoreParser.nullableString(data, 'aiDisclosure'),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String creatorId;
  final String creatorName;
  final String sportId;
  final String title;
  final String description;
  final String source;
  final String status;
  final String difficulty;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<ChallengeRuleDto> rules;
  final ChallengeSafetyPolicyDto safetyPolicy;
  final List<MediaAssetDto> media;
  final int participantCount;
  final int completionCount;
  final String? badgeId;
  final List<String> rewardIds;
  final String? communityId;
  final String visibility;
  final String moderationState;
  final bool isFeatured;
  final String? aiDisclosure;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'creatorId': creatorId,
    'creatorName': creatorName,
    'sportId': sportId,
    'title': title,
    'description': description,
    'source': source,
    'status': status,
    'difficulty': difficulty,
    'startsAt': Timestamp.fromDate(startsAt.toUtc()),
    'endsAt': Timestamp.fromDate(endsAt.toUtc()),
    'rules': rules.map((ChallengeRuleDto item) => item.toMap()).toList(),
    'safetyPolicy': safetyPolicy.toMap(),
    'media': media.map((MediaAssetDto item) => item.toMap()).toList(),
    'participantCount': participantCount,
    'completionCount': completionCount,
    if (badgeId != null) 'badgeId': badgeId,
    'rewardIds': rewardIds,
    if (communityId != null) 'communityId': communityId,
    'visibility': visibility,
    'moderationState': moderationState,
    'isFeatured': isFeatured,
    if (aiDisclosure != null) 'aiDisclosure': aiDisclosure,
    ...audit.toMap(),
  };
}

class ChallengeParticipationDto {
  const ChallengeParticipationDto({
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.progress,
    required this.progressPercent,
    required this.joinedAt,
    required this.updatedAt,
    required this.reminderEnabled,
    this.rank,
    this.completedAt,
    this.lastSubmissionAt,
  });

  factory ChallengeParticipationDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? <String, Object?>{};
    return ChallengeParticipationDto(
      challengeId: FirestoreParser.string(data, 'challengeId'),
      userId: FirestoreParser.string(data, 'userId'),
      status: FirestoreParser.string(data, 'status', fallback: 'active'),
      progress: FirestoreParser.number(data, 'progress', fallback: 0),
      progressPercent: FirestoreParser.number(
        data,
        'progressPercent',
        fallback: 0,
      ),
      rank: FirestoreParser.nullableInteger(data, 'rank'),
      joinedAt: FirestoreParser.dateTime(data, 'joinedAt'),
      updatedAt: FirestoreParser.dateTime(data, 'updatedAt'),
      completedAt: FirestoreParser.nullableDateTime(data, 'completedAt'),
      reminderEnabled: FirestoreParser.boolean(
        data,
        'reminderEnabled',
        fallback: true,
      ),
      lastSubmissionAt: FirestoreParser.nullableDateTime(
        data,
        'lastSubmissionAt',
      ),
    );
  }

  final String challengeId;
  final String userId;
  final String status;
  final double progress;
  final double progressPercent;
  final int? rank;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool reminderEnabled;
  final DateTime? lastSubmissionAt;
}

class ChallengeLeaderboardEntryDto {
  const ChallengeLeaderboardEntryDto({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.progress,
    required this.progressPercent,
    required this.rank,
    this.avatarUrl,
    this.verifiedAt,
  });

  factory ChallengeLeaderboardEntryDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? <String, Object?>{};
    return ChallengeLeaderboardEntryDto(
      userId: FirestoreParser.string(data, 'userId'),
      displayName: FirestoreParser.string(data, 'displayName'),
      username: FirestoreParser.string(data, 'username'),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      progress: FirestoreParser.number(data, 'progress', fallback: 0),
      progressPercent: FirestoreParser.number(
        data,
        'progressPercent',
        fallback: 0,
      ),
      rank: FirestoreParser.integer(data, 'rank', fallback: 0),
      verifiedAt: FirestoreParser.nullableDateTime(data, 'verifiedAt'),
    );
  }

  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final double progress;
  final double progressPercent;
  final int rank;
  final DateTime? verifiedAt;
}

class ChallengeBadgeDto {
  const ChallengeBadgeDto({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    this.iconUrl,
    this.sportId,
  });

  factory ChallengeBadgeDto.fromMap(FirestoreMap data, String id) =>
      ChallengeBadgeDto(
        id: id,
        name: FirestoreParser.string(data, 'name'),
        description: FirestoreParser.string(data, 'description'),
        iconUrl: FirestoreParser.nullableString(data, 'iconUrl'),
        rarity: FirestoreParser.string(data, 'rarity', fallback: 'common'),
        sportId: FirestoreParser.nullableString(data, 'sportId'),
      );

  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final String rarity;
  final String? sportId;
}
