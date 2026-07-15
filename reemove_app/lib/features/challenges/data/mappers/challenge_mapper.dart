import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/challenge.dart';
import '../dto/challenge_dto.dart';

extension ChallengeDtoMapper on ChallengeDto {
  Challenge toDomain() => Challenge(
    id: id,
    creatorId: creatorId,
    creatorName: creatorName,
    sportId: sportId,
    title: title,
    description: description,
    source: ChallengeSource.values.byName(source),
    status: ChallengeStatus.values.byName(status),
    difficulty: ChallengeDifficulty.values.byName(difficulty),
    startsAt: startsAt,
    endsAt: endsAt,
    rules: rules
        .map(
          (ChallengeRuleDto item) => ChallengeRule(
            metric: ChallengeMetric.values.byName(item.metric),
            target: item.target,
            unit: item.unit,
            verificationMethod: ChallengeVerificationMethod.values.byName(
              item.verificationMethod,
            ),
            maximumDailyProgress: item.maximumDailyProgress,
          ),
        )
        .toList(growable: false),
    safetyPolicy: ChallengeSafetyPolicy(
      minimumAge: safetyPolicy.minimumAge,
      requiresRestDays: safetyPolicy.requiresRestDays,
      maximumEffortMinutesPerDay: safetyPolicy.maximumEffortMinutesPerDay,
      prohibitedBehaviors: safetyPolicy.prohibitedBehaviors,
      healthDisclaimer: safetyPolicy.healthDisclaimer,
    ),
    media: media.map((item) => item.toDomain()).toList(growable: false),
    participantCount: participantCount,
    completionCount: completionCount,
    badgeId: badgeId,
    rewardIds: rewardIds,
    communityId: communityId,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
    isFeatured: isFeatured,
    aiDisclosure: aiDisclosure,
  );
}

extension ChallengeParticipationDtoMapper on ChallengeParticipationDto {
  ChallengeParticipation toDomain() => ChallengeParticipation(
    challengeId: challengeId,
    userId: userId,
    status: ChallengeParticipationStatus.values.byName(status),
    progress: progress,
    progressPercent: progressPercent,
    rank: rank,
    joinedAt: joinedAt,
    updatedAt: updatedAt,
    completedAt: completedAt,
    reminderEnabled: reminderEnabled,
    lastSubmissionAt: lastSubmissionAt,
  );
}

extension ChallengeLeaderboardEntryDtoMapper on ChallengeLeaderboardEntryDto {
  ChallengeLeaderboardEntry toDomain() => ChallengeLeaderboardEntry(
    userId: userId,
    displayName: displayName,
    username: username,
    avatarUrl: avatarUrl,
    progress: progress,
    progressPercent: progressPercent,
    rank: rank,
    verifiedAt: verifiedAt,
  );
}

extension ChallengeBadgeDtoMapper on ChallengeBadgeDto {
  ChallengeBadge toDomain() => ChallengeBadge(
    id: id,
    name: name,
    description: description,
    iconUrl: iconUrl,
    rarity: rarity,
    sportId: sportId,
  );
}
