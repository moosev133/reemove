import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/value_objects/content_policy.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/result/result.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../data/repositories/firebase_account_lifecycle_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/firestore_username_repository.dart';
import '../data/services/firebase_auth_analytics.dart';
import '../data/services/google_identity_service.dart';
import '../domain/entities/account_provisioning_request.dart';
import '../domain/entities/auth_routing_state.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/account_lifecycle_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/username_repository.dart';
import '../domain/services/auth_analytics.dart';

export '../../../core/firebase/firebase_providers.dart'
    show firebaseAuthProvider, firebaseFunctionsProvider;

final Provider<AuthAnalytics> authAnalyticsProvider = Provider<AuthAnalytics>((
  Ref ref,
) {
  final FirebaseBootstrapReport report = ref.watch(
    firebaseBootstrapReportProvider,
  );
  final AppEnvironment environment = ref.watch(appEnvironmentProvider);
  if (!report.isReady ||
      !environment.enableAnalytics ||
      environment.useFirebaseEmulators) {
    return const NoopAuthAnalytics();
  }
  return FirebaseAuthAnalytics(FirebaseAnalytics.instance);
});

final Provider<GoogleIdentityService> googleIdentityServiceProvider =
    Provider<GoogleIdentityService>((Ref ref) {
      final AppEnvironment environment = ref.watch(appEnvironmentProvider);
      return GoogleIdentityService(
        serverClientId: environment.googleServerClientId,
      );
    });

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return FirebaseAuthRepository(
        auth: ref.watch(firebaseAuthProvider),
        googleIdentity: ref.watch(googleIdentityServiceProvider),
      );
    });

final Provider<UsernameRepository> usernameRepositoryProvider =
    Provider<UsernameRepository>((Ref ref) {
      final FirebaseFirestore firestore = ref.watch(firebaseFirestoreProvider);
      return FirestoreUsernameRepository(
        firestore.collection(FirestoreCollections.usernames),
      );
    });

final Provider<AccountLifecycleRepository> accountLifecycleRepositoryProvider =
    Provider<AccountLifecycleRepository>((Ref ref) {
      return FirebaseAccountLifecycleRepository(
        ref.watch(firebaseFunctionsProvider),
      );
    });

final StreamProvider<AuthUser?> currentAuthUserProvider =
    StreamProvider<AuthUser?>((Ref ref) {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      if (!report.isReady) {
        return Stream<AuthUser?>.value(null);
      }
      return ref.watch(authRepositoryProvider).userChanges();
    });

final StreamProvider<UserProfile?> currentUserProfileProvider =
    StreamProvider<UserProfile?>((Ref ref) async* {
      final AuthUser? user = ref.watch(currentAuthUserProvider).value;
      if (user == null) {
        yield null;
        return;
      }

      await for (final Result<UserProfile?> result
          in ref.watch(userProfileRepositoryProvider).watchById(user.uid)) {
        yield result.when<UserProfile?>(
          success: (UserProfile? profile) => profile,
          failure: (failure) => throw StateError(failure.message),
        );
      }
    });

final Provider<AsyncValue<AuthRoutingState>>
authRoutingStateProvider = Provider<AsyncValue<AuthRoutingState>>((Ref ref) {
  final FirebaseBootstrapReport report = ref.watch(
    firebaseBootstrapReportProvider,
  );
  if (!report.isReady) {
    return AsyncValue<AuthRoutingState>.data(
      AuthRoutingState(
        destination: AuthDestination.configurationRequired,
        reason: report.details,
      ),
    );
  }

  final AsyncValue<AuthUser?> auth = ref.watch(currentAuthUserProvider);
  return auth.when(
    loading: () => const AsyncValue<AuthRoutingState>.loading(),
    error: (Object error, StackTrace stackTrace) =>
        AsyncValue<AuthRoutingState>.error(error, stackTrace),
    data: (AuthUser? user) {
      if (user == null) {
        return const AsyncValue<AuthRoutingState>.data(
          AuthRoutingState(destination: AuthDestination.signedOut),
        );
      }

      final AsyncValue<UserProfile?> profile = ref.watch(
        currentUserProfileProvider,
      );
      return profile.when(
        loading: () => const AsyncValue<AuthRoutingState>.loading(),
        error: (Object error, StackTrace stackTrace) =>
            AsyncValue<AuthRoutingState>.error(error, stackTrace),
        data: (UserProfile? value) {
          if (value == null) {
            final bool accountActionInProgress = ref
                .watch(authActionControllerProvider)
                .isLoading;
            if (accountActionInProgress) {
              return const AsyncValue<AuthRoutingState>.loading();
            }
            return const AsyncValue<AuthRoutingState>.data(
              AuthRoutingState(destination: AuthDestination.profileRequired),
            );
          }
          if (value.moderationState != ModerationState.active) {
            return const AsyncValue<AuthRoutingState>.data(
              AuthRoutingState(
                destination: AuthDestination.blocked,
                reason: 'This account is not currently active.',
              ),
            );
          }
          if (!user.emailVerified && user.usesPassword) {
            return const AsyncValue<AuthRoutingState>.data(
              AuthRoutingState(
                destination: AuthDestination.emailVerificationRequired,
              ),
            );
          }
          if (!value.onboardingCompleted) {
            return const AsyncValue<AuthRoutingState>.data(
              AuthRoutingState(destination: AuthDestination.onboardingRequired),
            );
          }
          return const AsyncValue<AuthRoutingState>.data(
            AuthRoutingState(destination: AuthDestination.ready),
          );
        },
      );
    },
  );
});

final NotifierProvider<AuthActionController, AsyncValue<void>>
authActionControllerProvider =
    NotifierProvider<AuthActionController, AsyncValue<void>>(
      AuthActionController.new,
    );

class AuthActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password),
      onSuccess: (_) => _afterSignIn(AuthProviderType.password),
    );
  }

  Future<bool> signInWithGoogle() => _run(
    () => ref.read(authRepositoryProvider).signInWithGoogle(),
    onSuccess: (_) => _afterSignIn(AuthProviderType.google),
  );

  Future<bool> signInWithApple() => _run(
    () => ref.read(authRepositoryProvider).signInWithApple(),
    onSuccess: (_) => _afterSignIn(AuthProviderType.apple),
  );

  Future<bool> registerAndProvision({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
    required bool ageConfirmed,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<AuthUser> authResult = await ref
        .read(authRepositoryProvider)
        .registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
    final bool authSucceeded = await authResult.when<Future<bool>>(
      success: (_) async => true,
      failure: (failure) async {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
    if (!authSucceeded) {
      return false;
    }
    final Result<AccountProvisioningResult> provisionResult = await ref
        .read(accountLifecycleRepositoryProvider)
        .provisionAccount(
          AccountProvisioningRequest(
            username: username,
            displayName: displayName,
            acceptedTerms: acceptedTerms,
            acceptedPrivacy: acceptedPrivacy,
            ageConfirmed: ageConfirmed,
          ),
        );
    return provisionResult.when<Future<bool>>(
      success: (_) async {
        await ref.read(authRepositoryProvider).sendEmailVerification();
        await ref
            .read(authAnalyticsProvider)
            .logSignUp(AuthProviderType.password);
        await ref.read(authAnalyticsProvider).logEmailVerificationSent();
        state = const AsyncValue<void>.data(null);
        return true;
      },
      failure: (failure) async {
        await ref
            .read(authRepositoryProvider)
            .deleteNewlyCreatedUserForRollback();
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> provisionSocialAccount({
    required String username,
    required String displayName,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
    required bool ageConfirmed,
  }) {
    return _run(
      () => ref
          .read(accountLifecycleRepositoryProvider)
          .provisionAccount(
            AccountProvisioningRequest(
              username: username,
              displayName: displayName,
              acceptedTerms: acceptedTerms,
              acceptedPrivacy: acceptedPrivacy,
              ageConfirmed: ageConfirmed,
            ),
          ),
      onSuccess: (_) async {
        final AuthProviderType provider = _currentPrimaryProvider();
        await ref.read(authAnalyticsProvider).logSignUp(provider);
        await _syncAuthProvidersBestEffort();
      },
    );
  }

  Future<bool> sendEmailVerification() => _run(
    () => ref.read(authRepositoryProvider).sendEmailVerification(),
    onSuccess: (_) =>
        ref.read(authAnalyticsProvider).logEmailVerificationSent(),
  );

  Future<bool> reloadCurrentUser() =>
      _run(() => ref.read(authRepositoryProvider).reloadCurrentUser());

  Future<bool> sendPasswordResetEmail(String email) => _run(
    () => ref.read(authRepositoryProvider).sendPasswordResetEmail(email),
    onSuccess: (_) =>
        ref.read(authAnalyticsProvider).logPasswordResetRequested(),
  );

  Future<bool> linkEmailPassword({
    required String email,
    required String password,
  }) {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .linkEmailPassword(email: email, password: password),
      onSuccess: (_) => _afterProviderLinked(AuthProviderType.password),
    );
  }

  Future<bool> linkGoogle() => _run(
    () => ref.read(authRepositoryProvider).linkGoogle(),
    onSuccess: (_) => _afterProviderLinked(AuthProviderType.google),
  );

  Future<bool> linkApple() => _run(
    () => ref.read(authRepositoryProvider).linkApple(),
    onSuccess: (_) => _afterProviderLinked(AuthProviderType.apple),
  );

  Future<bool> reauthenticateWithPassword(String password) => _run(
    () => ref.read(authRepositoryProvider).reauthenticateWithPassword(password),
  );

  Future<bool> reauthenticateWithGoogle() =>
      _run(() => ref.read(authRepositoryProvider).reauthenticateWithGoogle());

  Future<bool> reauthenticateWithApple() =>
      _run(() => ref.read(authRepositoryProvider).reauthenticateWithApple());

  Future<bool> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  Future<bool> revokeSessions() async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await ref
        .read(accountLifecycleRepositoryProvider)
        .revokeSessions();
    return result.when<Future<bool>>(
      success: (_) async {
        await ref.read(authAnalyticsProvider).logSessionsRevoked();
        return _signOutAfterServerAction();
      },
      failure: (failure) async {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> deleteAccount() async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await ref
        .read(accountLifecycleRepositoryProvider)
        .requestAccountDeletion();
    return result.when<Future<bool>>(
      success: (_) async {
        await ref.read(authAnalyticsProvider).logAccountDeletionRequested();
        return _signOutAfterServerAction();
      },
      failure: (failure) async {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  void clearError() {
    state = const AsyncValue<void>.data(null);
  }

  Future<void> _afterSignIn(AuthProviderType provider) async {
    await ref.read(authAnalyticsProvider).logLogin(provider);
    await _syncAuthProvidersBestEffort();
  }

  Future<void> _afterProviderLinked(AuthProviderType provider) async {
    await _syncAuthProvidersBestEffort();
    await ref.read(authAnalyticsProvider).logProviderLinked(provider);
    if (provider == AuthProviderType.password) {
      await ref.read(authAnalyticsProvider).logEmailVerificationSent();
    }
  }

  Future<void> _syncAuthProvidersBestEffort() async {
    await ref.read(accountLifecycleRepositoryProvider).syncAuthProviders();
  }

  AuthProviderType _currentPrimaryProvider() {
    final AuthUser? user = ref.read(authRepositoryProvider).currentUser;
    if (user?.usesGoogle ?? false) {
      return AuthProviderType.google;
    }
    if (user?.usesApple ?? false) {
      return AuthProviderType.apple;
    }
    if (user?.usesPassword ?? false) {
      return AuthProviderType.password;
    }
    return AuthProviderType.unknown;
  }

  Future<bool> _signOutAfterServerAction() async {
    final Result<void> signOutResult = await ref
        .read(authRepositoryProvider)
        .signOut();
    return signOutResult.when<bool>(
      success: (_) {
        state = const AsyncValue<void>.data(null);
        return true;
      },
      failure: (failure) {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> _run<T>(
    Future<Result<T>> Function() action, {
    Future<void> Function(T value)? onSuccess,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<T> result = await action();
    return result.when<Future<bool>>(
      success: (T value) async {
        if (onSuccess != null) {
          await onSuccess(value);
        }
        state = const AsyncValue<void>.data(null);
        return true;
      },
      failure: (failure) async {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }
}
