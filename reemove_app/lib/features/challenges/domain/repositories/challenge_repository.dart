import '../../../../core/result/result.dart';
import '../entities/challenge.dart';

abstract interface class ChallengeRepository {
  Stream<Result<List<Challenge>>> watchActiveForSport(
    String sportId, {
    int limit = 20,
  });
  Future<Result<Challenge?>> getById(String challengeId);
}
