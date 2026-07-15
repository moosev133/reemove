import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/errors/failure.dart';

abstract final class FirebaseAuthFailureMapper {
  static Failure fromAuthException(FirebaseAuthException exception) {
    final String message = switch (exception.code) {
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account is currently unavailable.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'The email or password is incorrect.',
      'email-already-in-use' =>
        'An account already exists for this email address.',
      'weak-password' => 'Choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'operation-not-allowed' =>
        'This sign-in method has not been enabled yet.',
      'account-exists-with-different-credential' =>
        'This email is already connected to another sign-in method.',
      'credential-already-in-use' =>
        'This sign-in credential is already connected to another account.',
      'provider-already-linked' =>
        'This sign-in method is already connected to your account.',
      'requires-recent-login' =>
        'For security, sign in again before completing this action.',
      'popup-closed-by-user' ||
      'web-context-cancelled' => 'Sign-in was cancelled.',
      _ => 'Authentication could not be completed. Try again.',
    };

    return Failure(
      message: message,
      code: exception.code,
      debugMessage: exception.message,
      cause: exception,
    );
  }

  static Failure fromGoogleSignInException(GoogleSignInException exception) {
    final String message = switch (exception.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => 'Sign-in was cancelled.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is temporarily unavailable on this device.',
      _ => 'Google sign-in could not be completed. Try again.',
    };

    return Failure(
      message: message,
      code: 'google-${exception.code.name}',
      debugMessage: exception.description,
      cause: exception,
    );
  }

  static Failure fromFunctionsException(FirebaseFunctionsException exception) {
    final String message = switch (exception.code) {
      'already-exists' => 'That username is already taken.',
      'invalid-argument' =>
        exception.message ?? 'Check the information entered.',
      'failed-precondition' =>
        exception.message ?? 'This action cannot be completed yet.',
      'unauthenticated' => 'Sign in again to continue.',
      'permission-denied' => 'You do not have permission to do that.',
      'resource-exhausted' => 'Too many attempts. Try again shortly.',
      'unavailable' => 'The service is temporarily unavailable.',
      _ =>
        exception.message ??
            'The account service could not complete the request.',
    };

    return Failure(
      message: message,
      code: exception.code,
      debugMessage: exception.details?.toString(),
      cause: exception,
    );
  }

  static Failure unexpected(Object error) => Failure(
    message: 'An unexpected authentication error occurred.',
    code: 'unexpected-auth-error',
    debugMessage: error.toString(),
    cause: error,
  );
}
