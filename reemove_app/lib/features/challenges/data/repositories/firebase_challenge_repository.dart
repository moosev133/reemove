import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../dto/challenge_dto.dart';
import '../mappers/challenge_mapper.dart';

class FirebaseChallengeRepository implements ChallengeRepository {
  const FirebaseChallengeRepository(this._challenges);

  final CollectionReference<ChallengeDto> _challenges;

  @override
  Stream<Result<List<Challenge>>> watchActiveForSport(
    String sportId, {
    int limit = 20,
  }) async* {
    try {
      final Query<ChallengeDto> query = _challenges
          .where('sportId', isEqualTo: sportId)
          .where('status', isEqualTo: 'active')
          .where('moderationState', isEqualTo: 'active')
          .orderBy('endsAt')
          .limit(limit);
      await for (final QuerySnapshot<ChallengeDto> snapshot
          in query.snapshots()) {
        yield Success<List<Challenge>>(
          snapshot.docs
              .map((doc) => doc.data().toDomain())
              .toList(growable: false),
        );
      }
    } catch (error) {
      yield FailureResult<List<Challenge>>(_mapError(error));
    }
  }

  @override
  Future<Result<Challenge?>> getById(String challengeId) async {
    try {
      final DocumentSnapshot<ChallengeDto> snapshot = await _challenges
          .doc(challengeId)
          .get();
      return Success<Challenge?>(snapshot.data()?.toDomain());
    } catch (error) {
      return FailureResult<Challenge?>(_mapError(error));
    }
  }

  static Failure _mapError(Object error) {
    return FirestoreFailureMapper.fromUnknown(error);
  }
}
