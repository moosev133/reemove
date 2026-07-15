import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/verification_request.dart';
import '../../domain/repositories/verification_repository.dart';
import '../dto/verification_request_dto.dart';
import '../services/profile_failure_mapper.dart';

class FirebaseVerificationRepository implements VerificationRepository {
  const FirebaseVerificationRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _auth = auth,
       _firestore = firestore,
       _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<Result<VerificationRequest?>> watchCurrent() async* {
    final String uid = _requireUid();
    try {
      await for (final DocumentSnapshot<Map<String, dynamic>> snapshot
          in _firestore
              .collection('verification_requests')
              .doc(uid)
              .snapshots()) {
        if (!snapshot.exists) {
          yield const Success<VerificationRequest?>(null);
          continue;
        }
        yield Success<VerificationRequest?>(
          VerificationRequestDto.fromFirestore(snapshot, null).toDomain(),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<VerificationRequest?>(
        ProfileFailureMapper.fromFirestore(error),
      );
    } catch (error) {
      yield FailureResult<VerificationRequest?>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<VerificationRequest>> submit(
    VerificationSubmission submission,
  ) async {
    try {
      await _functions.httpsCallable('submitVerificationRequest').call<dynamic>(
        <String, Object?>{
          'requestedType': submission.requestedType.name,
          'legalName': submission.legalName,
          'summary': submission.summary,
          'evidence': submission.evidence
              .map(
                (VerificationEvidence item) => <String, Object?>{
                  'storagePath': item.storagePath,
                  'label': item.label,
                },
              )
              .toList(growable: false),
        },
      );
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('verification_requests')
          .doc(_requireUid())
          .get();
      if (!snapshot.exists) {
        throw StateError('The verification request could not be loaded.');
      }
      return Success<VerificationRequest>(
        VerificationRequestDto.fromFirestore(snapshot, null).toDomain(),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<VerificationRequest>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } on FirebaseException catch (error) {
      return FailureResult<VerificationRequest>(
        ProfileFailureMapper.fromFirestore(error),
      );
    } catch (error) {
      return FailureResult<VerificationRequest>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> cancel(String requestId) async {
    try {
      await _functions.httpsCallable('cancelVerificationRequest').call<dynamic>(
        <String, Object?>{'requestId': requestId},
      );
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(ProfileFailureMapper.fromFunctions(error));
    } catch (error) {
      return FailureResult<void>(ProfileFailureMapper.unexpected(error));
    }
  }

  String _requireUid() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('A signed-in account is required.');
    }
    return uid;
  }
}
