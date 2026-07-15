import 'challenge.dart';

class CreateChallengeRequest {
  const CreateChallengeRequest({
    required this.sportId,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.startsAt,
    required this.endsAt,
    required this.metric,
    required this.target,
    required this.unit,
    required this.verificationMethod,
    required this.maximumDailyProgress,
    required this.minimumAge,
    required this.requiresRestDays,
    required this.maximumEffortMinutesPerDay,
    this.communityId,
  });

  final String sportId;
  final String title;
  final String description;
  final ChallengeDifficulty difficulty;
  final DateTime startsAt;
  final DateTime endsAt;
  final ChallengeMetric metric;
  final double target;
  final String unit;
  final ChallengeVerificationMethod verificationMethod;
  final double maximumDailyProgress;
  final int minimumAge;
  final bool requiresRestDays;
  final int maximumEffortMinutesPerDay;
  final String? communityId;
}

class SubmitChallengeProgressRequest {
  const SubmitChallengeProgressRequest({
    required this.challengeId,
    required this.progressDelta,
    this.activityId,
    this.proofStoragePath,
    this.note,
  });

  final String challengeId;
  final double progressDelta;
  final String? activityId;
  final String? proofStoragePath;
  final String? note;
}

class ChallengePage {
  const ChallengePage({required this.items, required this.nextCursor});

  final List<Challenge> items;
  final String? nextCursor;
}
