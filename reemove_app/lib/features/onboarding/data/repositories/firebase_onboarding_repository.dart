import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/database/firestore_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/functions_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/entities/onboarding_policy.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../dto/onboarding_draft_dto.dart';

class FirebaseOnboardingRepository implements OnboardingRepository {
  const FirebaseOnboardingRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<OnboardingDraft?>> loadDraft(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .doc('users/$uid/private/onboarding')
          .get();
      final Map<String, dynamic>? data = snapshot.data();
      return Success<OnboardingDraft?>(
        data == null ? null : OnboardingDraftDto.fromMap(data).value,
      );
    } on FirebaseException catch (error) {
      return FailureResult<OnboardingDraft?>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } on FormatException catch (error) {
      return FailureResult<OnboardingDraft?>(
        FirestoreFailureMapper.fromFormatException(error),
      );
    } catch (error) {
      return FailureResult<OnboardingDraft?>(
        FirestoreFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<OnboardingPolicy>> loadPolicy() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .doc('app_config/mobile')
          .get();
      final Map<String, dynamic> data =
          snapshot.data() ?? const <String, dynamic>{};
      return Success<OnboardingPolicy>(
        OnboardingPolicy(
          minimumAge: _integer(data['minimumAge'], 13),
          maximumAge: _integer(data['maximumAge'], 120),
          termsVersion: _string(data['termsVersion'], '1.0'),
          privacyVersion: _string(data['privacyVersion'], '1.0'),
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<OnboardingPolicy>(
        FirestoreFailureMapper.fromFirebaseException(error),
      );
    } catch (error) {
      return FailureResult<OnboardingPolicy>(
        FirestoreFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<OnboardingDraft>> saveProgress(OnboardingDraft draft) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'saveOnboardingProgress',
      );
      final HttpsCallableResult<dynamic> response = await callable
          .call<dynamic>(OnboardingDraftDto(draft).toRequestMap());
      final Object? raw = response.data;
      DateTime? updatedAt;
      if (raw is Map && raw['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(raw['updatedAt'] as String)?.toUtc();
      }
      return Success<OnboardingDraft>(
        draft.copyWith(
          status: OnboardingProgressStatus.inProgress,
          updatedAt: updatedAt ?? DateTime.now().toUtc(),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<OnboardingDraft>(
        FunctionsFailureMapper.fromException(error),
      );
    } catch (error) {
      return FailureResult<OnboardingDraft>(_unexpected(error));
    }
  }

  @override
  Future<Result<void>> complete(OnboardingDraft draft) async {
    try {
      await _functions
          .httpsCallable('completeOnboarding')
          .call<Object?>(OnboardingDraftDto(draft).toRequestMap());
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(FunctionsFailureMapper.fromException(error));
    } catch (error) {
      return FailureResult<void>(_unexpected(error));
    }
  }

  static int _integer(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static String _string(Object? value, String fallback) =>
      value is String ? value : fallback;

  static Failure _unexpected(Object error) => Failure(
    message: 'ReeMove could not update onboarding. Try again.',
    code: 'onboarding/unexpected',
    debugMessage: error.toString(),
    cause: error,
  );
}
