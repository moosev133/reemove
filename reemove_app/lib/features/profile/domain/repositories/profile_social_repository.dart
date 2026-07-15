import '../../../../core/result/result.dart';
import '../entities/blocked_profile.dart';
import '../entities/profile_connection.dart';
import '../entities/profile_relationship.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileSocialRepository {
  Future<Result<UserProfile?>> getVisibleProfileByUsername(String username);
  Future<Result<UserProfile?>> getVisibleProfileById(String profileId);
  Future<Result<ProfileRelationship>> getRelationship(String profileId);

  Future<Result<ProfileRelationship>> follow(String profileId);
  Future<Result<ProfileRelationship>> unfollow(String profileId);
  Future<Result<ProfileRelationship>> acceptRequest(String requesterId);
  Future<Result<ProfileRelationship>> declineRequest(String requesterId);
  Future<Result<ProfileRelationship>> cancelRequest(String profileId);
  Future<Result<void>> removeFollower(String followerId);

  Future<Result<ProfileConnectionPage>> listConnections({
    required String profileId,
    required ProfileConnectionType type,
    ProfileConnectionCursor? cursor,
    int limit = 30,
  });

  Future<Result<List<BlockedProfile>>> listBlockedProfiles({int limit = 100});
  Future<Result<void>> block(String profileId);
  Future<Result<void>> unblock(String profileId);
}
