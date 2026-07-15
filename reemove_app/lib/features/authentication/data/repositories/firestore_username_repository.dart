import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/repositories/username_repository.dart';
import '../../domain/value_objects/auth_validators.dart';

class FirestoreUsernameRepository implements UsernameRepository {
  const FirestoreUsernameRepository(this._usernames);

  final CollectionReference<Map<String, dynamic>> _usernames;

  @override
  Future<Result<UsernameAvailability>> checkAvailability(
    String username,
  ) async {
    final String normalized = AuthValidators.normalizeUsername(username);
    final String? validationError = AuthValidators.username(normalized);
    if (validationError != null) {
      return Success<UsernameAvailability>(
        UsernameAvailability(
          state: UsernameAvailabilityState.invalid,
          normalizedUsername: normalized,
          message: validationError,
        ),
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _usernames
          .doc(normalized)
          .get();
      return Success<UsernameAvailability>(
        UsernameAvailability(
          state: snapshot.exists
              ? UsernameAvailabilityState.taken
              : UsernameAvailabilityState.available,
          normalizedUsername: normalized,
          message: snapshot.exists ? 'That username is already taken.' : null,
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<UsernameAvailability>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } catch (error) {
      return FailureResult<UsernameAvailability>(
        FirestoreFailureMapper.unexpected(error),
      );
    }
  }
}
