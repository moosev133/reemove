import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/media_asset.dart';

enum ChallengeSource { community, trainer, ai, official }

enum ChallengeStatus { draft, scheduled, active, completed, cancelled }

class ChallengeRule {
  const ChallengeRule({
    required this.metric,
    required this.target,
    required this.unit,
    required this.verificationMethod,
  });

  final String metric;
  final double target;
  final String unit;
  final String verificationMethod;
}

class Challenge {
  const Challenge({
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
    required this.badgeId,
    required this.rewardIds,
    required this.visibility,
    required this.moderationState,
    required this.audit,
  });

  final String id;
  final String creatorId;
  final String sportId;
  final String title;
  final String description;
  final ChallengeSource source;
  final ChallengeStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<ChallengeRule> rules;
  final List<MediaAsset> media;
  final int participantCount;
  final String? badgeId;
  final List<String> rewardIds;
  final Visibility visibility;
  final ModerationState moderationState;
  final EntityAudit audit;
}
