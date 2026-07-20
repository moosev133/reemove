import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/router/app_routes.dart';
import 'package:reemove/core/firebase/firebase_bootstrap.dart';
import 'package:reemove/core/providers/core_providers.dart';
import 'package:reemove/core/result/result.dart';
import 'package:reemove/features/authentication/application/authentication_providers.dart';
import 'package:reemove/features/authentication/domain/entities/auth_routing_state.dart';
import 'package:reemove/features/authentication/domain/entities/auth_user.dart';
import 'package:reemove/features/authentication/domain/repositories/auth_repository.dart';
import 'package:reemove/features/feed/application/feed_providers.dart';
import 'package:reemove/features/feed/domain/entities/content_draft.dart';
import 'package:reemove/features/feed/domain/repositories/content_draft_repository.dart';

void main() {
  group('logout session cleanup', () {
    test('signOut clears local drafts and invokes repository signOut', () async {
      final _RecordingAuthRepository authRepository = _RecordingAuthRepository();
      final _RecordingContentDraftRepository draftRepository =
          _RecordingContentDraftRepository();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          contentDraftRepositoryProvider.overrideWithValue(draftRepository),
        ],
      );
      addTearDown(container.dispose);

      final bool signedOut = await container
          .read(authActionControllerProvider.notifier)
          .signOut();

      expect(signedOut, isTrue);
      expect(authRepository.signOutCalls, 1);
      expect(
        draftRepository.clearedKinds,
        containsAll(DraftKind.values),
      );
    });
  });

  group('logout routing', () {
    test('signed-out auth state routes members to auth welcome', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          firebaseBootstrapReportProvider.overrideWithValue(
            const FirebaseBootstrapReport(
              status: FirebaseBootstrapStatus.ready,
              appCheckEnabled: false,
              emulatorsEnabled: false,
            ),
          ),
          currentAuthUserProvider.overrideWith(
            (Ref ref) async* {
              yield null;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<AuthRoutingState>> subscription =
          container.listen(authRoutingStateProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      subscription.close();

      expect(
        container.read(authRoutingStateProvider).value?.destination,
        AuthDestination.signedOut,
      );
    });

    test('auth welcome is not treated as an authenticated shell location', () {
      expect(AppRoutes.isAuthenticatedLocation(AppRoutes.authWelcome), isFalse);
      expect(AppRoutes.isShellLocation(AppRoutes.home), isTrue);
    });
  });
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({Stream<AuthUser?>? userStream})
    : _userStream = userStream ?? const Stream<AuthUser?>.empty();

  final Stream<AuthUser?> _userStream;
  int signOutCalls = 0;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> userChanges() => _userStream;

  @override
  Future<Result<void>> signOut() async {
    signOutCalls += 1;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deleteNewlyCreatedUserForRollback() async =>
      const Success<void>(null);

  @override
  Future<Result<AuthUser>> linkApple() =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> linkEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> linkGoogle() => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> reauthenticateWithApple() => throw UnimplementedError();

  @override
  Future<Result<void>> reauthenticateWithGoogle() => throw UnimplementedError();

  @override
  Future<Result<void>> reauthenticateWithPassword(String password) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> reloadCurrentUser() => throw UnimplementedError();

  @override
  Future<Result<void>> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> signInWithApple() => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> signInWithGoogle() => throw UnimplementedError();
}

class _RecordingContentDraftRepository implements ContentDraftRepository {
  final List<DraftKind> clearedKinds = <DraftKind>[];

  @override
  Future<Result<void>> clear(DraftKind kind) async {
    clearedKinds.add(kind);
    return const Success<void>(null);
  }

  @override
  Future<Result<ContentDraft?>> load(DraftKind kind) async =>
      const Success<ContentDraft?>(null);

  @override
  Future<Result<void>> save(ContentDraft draft) async =>
      const Success<void>(null);
}
