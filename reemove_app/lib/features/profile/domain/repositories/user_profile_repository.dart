import '../../../../core/result/result.dart';
import '../entities/user_profile.dart';

/// Owner-scoped profile document access.
///
/// Public/cross-user profile reads must go through [ProfileSocialRepository]
/// and trusted callable Functions — Firestore denies non-owner client gets.
abstract interface class UserProfileRepository {
  Future<Result<UserProfile?>> getById(String uid);
  Stream<Result<UserProfile?>> watchById(String uid);
}
