import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/result/result.dart';
import '../../domain/entities/account_provisioning_request.dart';
import '../../domain/repositories/account_lifecycle_repository.dart';
import '../services/firebase_auth_failure_mapper.dart';

class FirebaseAccountLifecycleRepository implements AccountLifecycleRepository {
  const FirebaseAccountLifecycleRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Result<AccountProvisioningResult>> provisionAccount(
    AccountProvisioningRequest request,
  ) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'provisionAccount',
      );
      final HttpsCallableResult<dynamic> response = await callable
          .call<dynamic>(<String, Object?>{
            'username': request.username,
            'displayName': request.displayName,
            'acceptedTerms': request.acceptedTerms,
            'acceptedPrivacy': request.acceptedPrivacy,
            'ageConfirmed': request.ageConfirmed,
          });
      final Object? raw = response.data;
      if (raw is! Map) {
        throw const FormatException('Invalid account provisioning response.');
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      final Object? uid = data['uid'];
      final Object? username = data['username'];
      final Object? created = data['created'];
      if (uid is! String || username is! String || created is! bool) {
        throw const FormatException(
          'Incomplete account provisioning response.',
        );
      }
      return Success<AccountProvisioningResult>(
        AccountProvisioningResult(
          uid: uid,
          username: username,
          created: created,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<AccountProvisioningResult>(
        FirebaseAuthFailureMapper.fromFunctionsException(error),
      );
    } catch (error) {
      return FailureResult<AccountProvisioningResult>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> syncAuthProviders() => _invokeVoid('syncAuthProviders');

  @override
  Future<Result<void>> revokeSessions() => _invokeVoid('revokeSessions');

  @override
  Future<Result<void>> requestAccountDeletion() => _invokeVoid('deleteAccount');

  Future<Result<void>> _invokeVoid(String functionName) async {
    try {
      await _functions.httpsCallable(functionName).call<Object?>();
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromFunctionsException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }
}
