import '../entities/auth_user.dart';

abstract interface class AuthAnalytics {
  Future<void> logLogin(AuthProviderType provider);

  Future<void> logSignUp(AuthProviderType provider);

  Future<void> logPasswordResetRequested();

  Future<void> logEmailVerificationSent();

  Future<void> logProviderLinked(AuthProviderType provider);

  Future<void> logSessionsRevoked();

  Future<void> logAccountDeletionRequested();
}
