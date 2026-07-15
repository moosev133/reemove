import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mappers/firebase_user_mapper.dart';
import '../services/firebase_auth_failure_mapper.dart';
import '../services/google_identity_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({
    required FirebaseAuth auth,
    required GoogleIdentityService googleIdentity,
  }) : _auth = auth,
       _googleIdentity = googleIdentity;

  final FirebaseAuth _auth;
  final GoogleIdentityService _googleIdentity;

  @override
  AuthUser? get currentUser => _auth.currentUser?.toDomain();

  @override
  Stream<AuthUser?> userChanges() {
    return _auth.userChanges().map((User? user) => user?.toDomain());
  }

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final User? user = credential.user;
      if (user == null) {
        return _missingUserFailure();
      }
      await user.updateDisplayName(displayName.trim());
      await user.reload();
      final User? refreshed = _auth.currentUser;
      if (refreshed == null) {
        return _missingUserFailure();
      }
      return Success<AuthUser>(refreshed.toDomain());
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        return _missingUserFailure();
      }
      return Success<AuthUser>(user.toDomain());
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<AuthUser>> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });
        credential = await _auth.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount googleUser = await _googleIdentity
            .authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final String? idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          return const FailureResult<AuthUser>(
            Failure(
              message: 'Google did not return a valid identity token.',
              code: 'missing-google-id-token',
            ),
          );
        }
        final OAuthCredential oauthCredential = GoogleAuthProvider.credential(
          idToken: idToken,
        );
        credential = await _auth.signInWithCredential(oauthCredential);
      }

      final User? user = credential.user;
      if (user == null) {
        return _missingUserFailure();
      }
      return Success<AuthUser>(user.toDomain());
    } on GoogleSignInException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromGoogleSignInException(error),
      );
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<AuthUser>> signInWithApple() async {
    try {
      final AppleAuthProvider provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final UserCredential credential = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
      final User? user = credential.user;
      if (user == null) {
        return _missingUserFailure();
      }
      return Success<AuthUser>(user.toDomain());
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<AuthUser>> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _missingUserFailure();
      }
      final UserCredential credential = await user.linkWithCredential(
        EmailAuthProvider.credential(email: email.trim(), password: password),
      );
      final User? linkedUser = credential.user;
      if (linkedUser == null) {
        return _missingUserFailure();
      }
      if (!linkedUser.emailVerified) {
        await linkedUser.sendEmailVerification();
      }
      return Success<AuthUser>(linkedUser.toDomain());
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<AuthUser>> linkGoogle() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _missingUserFailure();
      }
      final UserCredential credential;
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });
        credential = await user.linkWithPopup(provider);
      } else {
        final GoogleSignInAccount googleUser = await _googleIdentity
            .authenticate();
        final String? idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          return const FailureResult<AuthUser>(
            Failure(
              message: 'Google did not return a valid identity token.',
              code: 'missing-google-id-token',
            ),
          );
        }
        credential = await user.linkWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      final User? linkedUser = credential.user;
      if (linkedUser == null) {
        return _missingUserFailure();
      }
      return Success<AuthUser>(linkedUser.toDomain());
    } on GoogleSignInException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromGoogleSignInException(error),
      );
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<AuthUser>> linkApple() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _missingUserFailure();
      }
      final AppleAuthProvider provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final UserCredential credential = kIsWeb
          ? await user.linkWithPopup(provider)
          : await user.linkWithProvider(provider);
      final User? linkedUser = credential.user;
      if (linkedUser == null) {
        return _missingUserFailure();
      }
      return Success<AuthUser>(linkedUser.toDomain());
    } on FirebaseAuthException catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<AuthUser>(
        FirebaseAuthFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _signedOutFailure();
      }
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> reloadCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _signedOutFailure();
      }
      await user.reload();
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> reauthenticateWithPassword(String password) async {
    try {
      final User? user = _auth.currentUser;
      final String? email = user?.email;
      if (user == null || email == null) {
        return _signedOutFailure();
      }
      final AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> reauthenticateWithGoogle() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _signedOutFailure();
      }
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });
        await user.reauthenticateWithPopup(provider);
      } else {
        final GoogleSignInAccount googleUser = await _googleIdentity
            .authenticate();
        final String? idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          return const FailureResult<void>(
            Failure(
              message: 'Google did not return a valid identity token.',
              code: 'missing-google-id-token',
            ),
          );
        }
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      return const Success<void>(null);
    } on GoogleSignInException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromGoogleSignInException(error),
      );
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> reauthenticateWithApple() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return _signedOutFailure();
      }
      final AppleAuthProvider provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      try {
        await _googleIdentity.signOut();
      } on Object {
        // Firebase session termination is authoritative. A stale Google SDK
        // selection session must not make local sign-out appear to fail.
      }
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> deleteNewlyCreatedUserForRollback() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
      return const Success<void>(null);
    } on FirebaseAuthException catch (error) {
      return FailureResult<void>(
        FirebaseAuthFailureMapper.fromAuthException(error),
      );
    } catch (error) {
      return FailureResult<void>(FirebaseAuthFailureMapper.unexpected(error));
    }
  }

  FailureResult<AuthUser> _missingUserFailure() {
    return const FailureResult<AuthUser>(
      Failure(
        message: 'Authentication completed without a user account.',
        code: 'missing-auth-user',
      ),
    );
  }

  FailureResult<void> _signedOutFailure() {
    return const FailureResult<void>(
      Failure(message: 'Sign in to continue.', code: 'unauthenticated'),
    );
  }
}
