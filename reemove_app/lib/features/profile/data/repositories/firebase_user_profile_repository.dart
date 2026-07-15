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
    required CollectionReference<Map<String, dynamic>> usernames,
  }) : _users = users,
       _usernames = usernames;

  final CollectionReference<UserProfileDto> _users;
  final CollectionReference<Map<String, dynamic>> _usernames;

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
  Future<Result<UserProfile?>> getByUsername(String username) async {
    final String normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const Success<UserProfile?>(null);
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> reservation =
          await _usernames.doc(normalized).get();
      final Object? uidValue = reservation.data()?['uid'];
      if (uidValue is! String || uidValue.trim().isEmpty) {
        return const Success<UserProfile?>(null);
      }
      return getById(uidValue.trim());
    } on FirebaseException catch (error) {
      return FailureResult<UserProfile?>(
        FirestoreFailureMapper.fromFirebaseException(error),
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

  @override
  Future<Result<List<UserProfile>>> getByIds(List<String> uids) async {
    if (uids.isEmpty) {
      return const Success<List<UserProfile>>(<UserProfile>[]);
    }
    if (uids.length > 30) {
      return FailureResult<List<UserProfile>>(
        FirestoreFailureMapper.unexpected(
          ArgumentError('getByIds accepts at most 30 IDs per Firestore query.'),
        ),
      );
    }

    try {
      final QuerySnapshot<UserProfileDto> snapshot = await _users
          .where(FieldPath.documentId, whereIn: uids)
          .where('visibility', isEqualTo: 'public')
          .where('moderationState', isEqualTo: 'active')
          .limit(uids.length)
          .get();
      final List<UserProfile> profiles = snapshot.docs
          .map(
            (QueryDocumentSnapshot<UserProfileDto> doc) =>
                doc.data().toDomain(),
          )
          .toList(growable: false);
      return Success<List<UserProfile>>(profiles);
    } on FirebaseException catch (error) {
      return FailureResult<List<UserProfile>>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<List<UserProfile>>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<List<UserProfile>>(
        FirestoreFailureMapper.unexpected(error),
      );
    }
  }
}
