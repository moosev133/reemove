import '../../../../core/result/result.dart';
import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<Result<UserProfile?>> getById(String uid);
  Stream<Result<UserProfile?>> watchById(String uid);
  Future<Result<List<UserProfile>>> getByIds(List<String> uids);
}
