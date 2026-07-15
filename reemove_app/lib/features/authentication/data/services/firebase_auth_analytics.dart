import 'package:firebase_analytics/firebase_analytics.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/services/auth_analytics.dart';

class FirebaseAuthAnalytics implements AuthAnalytics {
  const FirebaseAuthAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logLogin(AuthProviderType provider) =>
      _log('auth_login', <String, Object>{'method': provider.name});

  @override
  Future<void> logSignUp(AuthProviderType provider) =>
      _log('auth_sign_up', <String, Object>{'method': provider.name});

  @override
  Future<void> logPasswordResetRequested() =>
      _log('auth_password_reset_requested');

  @override
  Future<void> logEmailVerificationSent() =>
      _log('auth_email_verification_sent');

  @override
  Future<void> logProviderLinked(AuthProviderType provider) =>
      _log('auth_provider_linked', <String, Object>{'provider': provider.name});

  @override
  Future<void> logSessionsRevoked() => _log('auth_sessions_revoked');

  @override
  Future<void> logAccountDeletionRequested() =>
      _log('auth_account_deletion_requested');

  Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } on Object {
      // Analytics is operational telemetry and must never block account access.
    }
  }
}

class NoopAuthAnalytics implements AuthAnalytics {
  const NoopAuthAnalytics();

  @override
  Future<void> logAccountDeletionRequested() async {}

  @override
  Future<void> logEmailVerificationSent() async {}

  @override
  Future<void> logLogin(AuthProviderType provider) async {}

  @override
  Future<void> logPasswordResetRequested() async {}

  @override
  Future<void> logProviderLinked(AuthProviderType provider) async {}

  @override
  Future<void> logSessionsRevoked() async {}

  @override
  Future<void> logSignUp(AuthProviderType provider) async {}
}
