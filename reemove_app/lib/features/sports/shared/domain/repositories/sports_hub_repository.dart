import '../../../../../core/result/result.dart';
import '../entities/sport_community.dart';
import '../entities/sport_leaderboard.dart';
import '../entities/sport_management_requests.dart';
import '../entities/sport_participation.dart';
import '../entities/sport_trainer.dart';

abstract interface class SportsHubRepository {
  Stream<Result<List<SportCommunity>>> watchCommunities(
    String sportId, {
    int limit = 30,
  });

  Stream<Result<SportCommunity?>> watchCommunity(String communityId);

  Stream<Result<List<SportCommunityMember>>> watchCommunityMembers(
    String communityId, {
    int limit = 50,
  });

  Stream<Result<SportCommunityMembershipStatus>> watchCommunityMembership({
    required String communityId,
    required String userId,
  });

  Stream<Result<List<SportCommunityMember>>> watchCommunityJoinRequests(
    String communityId, {
    int limit = 50,
  });

  Stream<Result<List<SportTrainer>>> watchTrainers(
    String sportId, {
    int limit = 30,
  });

  Stream<Result<SportTrainer?>> watchTrainer(String trainerId);

  Stream<Result<List<TrainerService>>> watchTrainerServices({
    required String trainerId,
    String? sportId,
    int limit = 30,
  });

  Stream<Result<List<SportLeaderboard>>> watchLeaderboards(
    String sportId, {
    int limit = 10,
  });

  Stream<Result<SportsEventParticipation>> watchEventParticipation({
    required String eventId,
    required String userId,
  });

  Future<Result<String>> createCommunity(CreateSportCommunityRequest request);
  Future<Result<SportCommunityMembershipStatus>> joinCommunity(
    String communityId,
  );
  Future<Result<void>> leaveCommunity(String communityId);
  Future<Result<void>> respondToCommunityJoinRequest({
    required String communityId,
    required String userId,
    required bool approve,
  });

  Future<Result<String>> createEvent(CreateSportsEventRequest request);
  Future<Result<SportsEventAttendanceStatus>> attendEvent(String eventId);
  Future<Result<void>> leaveEvent(String eventId);

  Future<Result<String>> upsertTrainerService(
    UpsertTrainerServiceRequest request,
  );
}
