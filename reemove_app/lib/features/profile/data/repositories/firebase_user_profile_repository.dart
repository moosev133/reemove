import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../dto/user_profile_dto.dart';
import '../mappers/user_profile_mapper.dart';

class FirebaseUserProfileRepository implements UserProfileRepository {
  const FirebaseUserProfileRepository({
    required CollectionReference<UserProfileDto> users,
  }) : _users = users;

  final CollectionReference<UserProfileDto> _users;

  @override
  Future<Result<UserProfile?>> getById(String uid) async {
    try {
      final DocumentSnapshot<UserProfileDto> snapshot = await _users
          .doc(uid)
          .get();
      return Success<UserProfile?>(snapshot.data()?.toDomain());
    } on FirebaseException catch (error) {
      return FailureResult<UserProfile?>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<UserProfile?>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<UserProfile?>(
        FirestoreFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<UserProfile?>> watchById(String uid) async* {
    try {
      await for (final DocumentSnapshot<UserProfileDto> snapshot
          in _users.doc(uid).snapshots()) {
        yield Success<UserProfile?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<UserProfile?>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      yield FailureResult<UserProfile?>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      yield FailureResult<UserProfile?>(
        FirestoreFailureMapper.unexpected(error),
      );
    }
  }
}
