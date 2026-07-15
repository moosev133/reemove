import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/services/notification_permission_service.dart';

class FirebaseNotificationPermissionService
    implements NotificationPermissionService {
  const FirebaseNotificationPermissionService(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<Result<NotificationPermissionDecision>> requestPermission() async {
    try {
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return Success<NotificationPermissionDecision>(
        switch (settings.authorizationStatus) {
          AuthorizationStatus.authorized =>
            NotificationPermissionDecision.authorized,
          AuthorizationStatus.provisional =>
            NotificationPermissionDecision.provisional,
          AuthorizationStatus.denied => NotificationPermissionDecision.denied,
          AuthorizationStatus.notDetermined =>
            NotificationPermissionDecision.notAsked,
        },
      );
    } catch (error) {
      return FailureResult<NotificationPermissionDecision>(
        Failure(
          message: 'Notification permission could not be requested.',
          code: 'notifications/permission-failed',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }
}

class UnavailableNotificationPermissionService
    implements NotificationPermissionService {
  const UnavailableNotificationPermissionService();

  @override
  Future<Result<NotificationPermissionDecision>> requestPermission() async {
    return const Success<NotificationPermissionDecision>(
      NotificationPermissionDecision.unavailable,
    );
  }
}
