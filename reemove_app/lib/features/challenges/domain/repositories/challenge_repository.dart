import '../../../../core/result/result.dart';
import '../entities/challenge.dart';
import '../entities/challenge_requests.dart';

abstract interface class ChallengeRepository {
  Stream<Result<List<Challenge>>> watchActiveForSport(
    String sportId, {
    int limit = 20,
  });

  Future<Result<ChallengePage>> loadChallenges({
    String? sportId,
    String? cursor,
    int limit = 20,
  });

  Stream<Result<Challenge?>> watchChallenge(String challengeId);
  Future<Result<Challenge?>> getById(String challengeId);
  Stream<Result<ChallengeParticipation?>> watchParticipation(
    String challengeId,
  );
  Stream<Result<List<ChallengeSubmission>>> watchSubmissions(
    String challengeId, {
    int limit = 100,
  });
  Stream<Result<List<ChallengeLeaderboardEntry>>> watchLeaderboard(
    String challengeId, {
    int limit = 50,
  });
  Stream<Result<List<EarnedChallengeBadge>>> watchMyBadges();
  Stream<Result<List<ChallengeRewardClaim>>> watchMyRewardClaims();
  Stream<Result<List<Challenge>>> watchMyChallengeHistory({int limit = 50});
  Future<Result<List<ChallengeActivityOption>>> loadEligibleActivities(
    String challengeId,
  );

  Future<Result<String>> createChallenge(CreateChallengeRequest request);
  Future<Result<void>> joinChallenge(String challengeId);
  Future<Result<void>> leaveChallenge(String challengeId);
  Future<Result<void>> submitProgress(SubmitChallengeProgressRequest request);
  Future<Result<void>> setReminder(String challengeId, {required bool enabled});
  Future<Result<void>> claimRewards(String challengeId);
  Future<Result<void>> reviewSubmission({
    required String challengeId,
    required String submissionId,
    required bool approve,
  });
  Future<Result<String>> createProofReviewUrl({
    required String challengeId,
    required String submissionId,
  });
  Future<Result<String>> uploadProof({
    required String challengeId,
    required String localPath,
  });
}
