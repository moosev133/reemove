import '../../../../core/domain/entities/entity_audit.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/media_asset.dart';

enum ChallengeSource { community, trainer, ai, official }

enum ChallengeStatus { draft, scheduled, active, completed, cancelled }

enum ChallengeDifficulty { beginner, intermediate, advanced }

enum ChallengeMetric {
  distance,
  duration,
  sessions,
  repetitions,
  volume,
  attendance,
  points,
}

enum ChallengeVerificationMethod {
  automaticActivity,
  activityAndProof,
  photoProof,
  organizerReview,
}

enum ChallengeParticipationStatus { active, completed, withdrawn, disqualified }

enum ChallengeSubmissionStatus { pending, verified, rejected, flagged }

class ChallengeRule {
  const ChallengeRule({
    required this.metric,
    required this.target,
    required this.unit,
    required this.verificationMethod,
    required this.maximumDailyProgress,
  });

  final ChallengeMetric metric;
  final double target;
  final String unit;
  final ChallengeVerificationMethod verificationMethod;
  final double maximumDailyProgress;
}

class ChallengeSafetyPolicy {
  const ChallengeSafetyPolicy({
    required this.minimumAge,
    required this.requiresRestDays,
    required this.maximumEffortMinutesPerDay,
    required this.prohibitedBehaviors,
    required this.healthDisclaimer,
  });

  final int minimumAge;
  final bool requiresRestDays;
  final int maximumEffortMinutesPerDay;
  final List<String> prohibitedBehaviors;
  final String healthDisclaimer;
}

class Challenge {
  const Challenge({
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
    required this.badgeId,
    required this.rewardIds,
    required this.communityId,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    required this.isFeatured,
    required this.aiDisclosure,
  });

  final String id;
  final String creatorId;
  final String creatorName;
  final String sportId;
  final String title;
  final String description;
  final ChallengeSource source;
  final ChallengeStatus status;
  final ChallengeDifficulty difficulty;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<ChallengeRule> rules;
  final ChallengeSafetyPolicy safetyPolicy;
  final List<MediaAsset> media;
  final int participantCount;
  final int completionCount;
  final String? badgeId;
  final List<String> rewardIds;
  final String? communityId;
  final Visibility visibility;
  final ModerationState moderationState;
  final EntityAudit audit;
  final bool isFeatured;
  final String? aiDisclosure;

  Duration get remaining => endsAt.difference(DateTime.now());
  bool get isJoinable {
    final DateTime now = DateTime.now();
    return moderationState == ModerationState.active &&
        status == ChallengeStatus.active &&
        !startsAt.isAfter(now) &&
        endsAt.isAfter(now);
  }

  ChallengeRule get primaryRule => rules.first;
}

class ChallengeParticipation {
  const ChallengeParticipation({
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.progress,
    required this.progressPercent,
    required this.rank,
    required this.joinedAt,
    required this.updatedAt,
    required this.completedAt,
    required this.reminderEnabled,
    required this.lastSubmissionAt,
  });

  final String challengeId;
  final String userId;
  final ChallengeParticipationStatus status;
  final double progress;
  final double progressPercent;
  final int? rank;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool reminderEnabled;
  final DateTime? lastSubmissionAt;
}

class ChallengeLeaderboardEntry {
  const ChallengeLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.progress,
    required this.progressPercent,
    required this.rank,
    required this.verifiedAt,
  });

  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final double progress;
  final double progressPercent;
  final int rank;
  final DateTime? verifiedAt;
}

class ChallengeSubmission {
  const ChallengeSubmission({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.progressDelta,
    required this.activityId,
    required this.proofStoragePath,
    required this.note,
    required this.status,
    required this.riskScore,
    required this.riskReasons,
    required this.createdAt,
    required this.reviewedAt,
  });

  final String id;
  final String challengeId;
  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final double progressDelta;
  final String? activityId;
  final String? proofStoragePath;
  final String? note;
  final ChallengeSubmissionStatus status;
  final double riskScore;
  final List<String> riskReasons;
  final DateTime createdAt;
  final DateTime? reviewedAt;
}

class ChallengeBadge {
  const ChallengeBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.rarity,
    required this.sportId,
  });

  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final String rarity;
  final String? sportId;
}

class EarnedChallengeBadge {
  const EarnedChallengeBadge({
    required this.badge,
    required this.challengeId,
    required this.earnedAt,
  });

  final ChallengeBadge badge;
  final String challengeId;
  final DateTime earnedAt;
}

class ChallengeReward {
  const ChallengeReward({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.valueText,
    required this.expiresAt,
    required this.sponsorName,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String valueText;
  final DateTime? expiresAt;
  final String? sponsorName;
}

class ChallengeRewardClaim {
  const ChallengeRewardClaim({
    required this.id,
    required this.reward,
    required this.challengeId,
    required this.status,
    required this.claimedAt,
  });

  final String id;
  final ChallengeReward reward;
  final String challengeId;
  final String status;
  final DateTime claimedAt;
}

class ChallengeActivityOption {
  const ChallengeActivityOption({
    required this.id,
    required this.sportId,
    required this.occurredAt,
    required this.metrics,
  });

  final String id;
  final String sportId;
  final DateTime occurredAt;
  final Map<String, double> metrics;
}
