import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/group_notification_preferences.dart';
import '../../domain/repositories/group_notification_repository.dart';
import '../services/notification_failure_mapper.dart';

class FirebaseGroupNotificationRepository implements GroupNotificationRepository {
  const FirebaseGroupNotificationRepository({
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _functions = functions,
       _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String get _uid {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to update group notification settings.');
    }
    return uid;
  }

  @override
  Future<Result<GroupNotificationPreferences>> getGroupNotificationPreferences({
    required String groupId,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'getGroupNotificationPreferences',
      );
      final HttpsCallableResult<Map<String, dynamic>> response =
        await callable.call<Map<String, dynamic>>(<String, dynamic>{
          'groupId': groupId,
        });
      final Map<String, dynamic> responseData = response.data;
      final Object? preferencesRaw = responseData['preferences'];
      if (preferencesRaw is Map<String, dynamic>) {
        return Success<GroupNotificationPreferences>(
          GroupNotificationPreferences.fromCallableJson(preferencesRaw),
        );
      }
      return FailureResult<GroupNotificationPreferences>(
        Failure(
          message: 'Invalid group notification preferences response.',
          code: 'notifications/invalid_response',
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<GroupNotificationPreferences>(
        NotificationFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<GroupNotificationPreferences>(
        NotificationFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> updateGroupNotificationPreferences({
    required String groupId,
    required GroupNotificationPreferences preferences,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'updateGroupNotificationPreferences',
      );
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'groupId': groupId,
        'preferences': preferences.toCallableJson(),
      });
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(
        NotificationFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<void>(
        NotificationFailureMapper.unexpected(error),
      );
    }
  }
}


