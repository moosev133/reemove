import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/challenge.dart';
import '../dto/challenge_dto.dart';

extension ChallengeDtoMapper on ChallengeDto {
  Challenge toDomain() => Challenge(
    id: id,
    creatorId: creatorId,
    sportId: sportId,
    title: title,
    description: description,
    source: ChallengeSource.values.byName(source),
    status: ChallengeStatus.values.byName(status),
    startsAt: startsAt,
    endsAt: endsAt,
    rules: rules
        .map(
          (ChallengeRuleDto item) => ChallengeRule(
            metric: item.metric,
            target: item.target,
            unit: item.unit,
            verificationMethod: item.verificationMethod,
          ),
        )
        .toList(growable: false),
    media: media.map((item) => item.toDomain()).toList(growable: false),
    participantCount: participantCount,
    badgeId: badgeId,
    rewardIds: rewardIds,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
  );
}
