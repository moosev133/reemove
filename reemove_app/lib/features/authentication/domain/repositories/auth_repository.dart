import '../../../../core/result/result.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> userChanges();

  AuthUser? get currentUser;

  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> signInWithGoogle();

  Future<Result<AuthUser>> signInWithApple();

  Future<Result<AuthUser>> linkEmailPassword({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> linkGoogle();

  Future<Result<AuthUser>> linkApple();

  Future<Result<void>> sendEmailVerification();

  Future<Result<void>> reloadCurrentUser();

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> reauthenticateWithPassword(String password);

  Future<Result<void>> reauthenticateWithGoogle();

  Future<Result<void>> reauthenticateWithApple();

  Future<Result<void>> signOut();

  Future<Result<void>> deleteNewlyCreatedUserForRollback();
}
