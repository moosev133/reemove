import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/result/result.dart';
import '../data/repositories/firebase_challenge_repository.dart';
import '../domain/entities/challenge.dart';
import '../domain/entities/challenge_requests.dart';
import '../domain/repositories/challenge_repository.dart';

final Provider<ChallengeRepository> challengeRepositoryProvider =
    Provider<ChallengeRepository>((Ref ref) {
      return FirebaseChallengeRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
        storage: ref.watch(firebaseStorageProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

final challengeProvider = StreamProvider.family<Challenge?, String>((
  Ref ref,
  String challengeId,
) async* {
  await for (final Result<Challenge?> result
      in ref.watch(challengeRepositoryProvider).watchChallenge(challengeId)) {
    yield _value(result);
  }
});

final challengeParticipationProvider =
    StreamProvider.family<ChallengeParticipation?, String>((
      Ref ref,
      String challengeId,
    ) async* {
      await for (final Result<ChallengeParticipation?> result
          in ref
              .watch(challengeRepositoryProvider)
              .watchParticipation(challengeId)) {
        yield _value(result);
      }
    });

final challengeSubmissionsProvider =
    StreamProvider.family<List<ChallengeSubmission>, String>((
      Ref ref,
      String challengeId,
    ) async* {
      await for (final Result<List<ChallengeSubmission>> result
          in ref
              .watch(challengeRepositoryProvider)
              .watchSubmissions(challengeId)) {
        yield _value(result);
      }
    });

final challengeLeaderboardProvider =
    StreamProvider.family<List<ChallengeLeaderboardEntry>, String>((
      Ref ref,
      String challengeId,
    ) async* {
      await for (final Result<List<ChallengeLeaderboardEntry>> result
          in ref
              .watch(challengeRepositoryProvider)
              .watchLeaderboard(challengeId)) {
        yield _value(result);
      }
    });

final myChallengeBadgesProvider = StreamProvider<List<EarnedChallengeBadge>>((
  Ref ref,
) async* {
  await for (final Result<List<EarnedChallengeBadge>> result
      in ref.watch(challengeRepositoryProvider).watchMyBadges()) {
    yield _value(result);
  }
});

final myChallengeRewardClaimsProvider =
    StreamProvider<List<ChallengeRewardClaim>>((Ref ref) async* {
      await for (final Result<List<ChallengeRewardClaim>> result
          in ref.watch(challengeRepositoryProvider).watchMyRewardClaims()) {
        yield _value(result);
      }
    });

final myChallengeHistoryProvider = StreamProvider<List<Challenge>>((
  Ref ref,
) async* {
  await for (final Result<List<Challenge>> result
      in ref.watch(challengeRepositoryProvider).watchMyChallengeHistory()) {
    yield _value(result);
  }
});

final eligibleChallengeActivitiesProvider =
    FutureProvider.family<List<ChallengeActivityOption>, String>((
      Ref ref,
      String challengeId,
    ) async {
      final Result<List<ChallengeActivityOption>> result = await ref
          .watch(challengeRepositoryProvider)
          .loadEligibleActivities(challengeId);
      return _value(result);
    });

final challengeCatalogControllerProvider =
    NotifierProvider<ChallengeCatalogController, ChallengeCatalogState>(
      ChallengeCatalogController.new,
    );

final challengeActionControllerProvider =
    NotifierProvider<ChallengeActionController, AsyncValue<void>>(
      ChallengeActionController.new,
    );

class ChallengeCatalogController extends Notifier<ChallengeCatalogState> {
  @override
  ChallengeCatalogState build() => const ChallengeCatalogState();

  Future<void> initialize({String? sportId}) async {
    if (state.items.isNotEmpty && state.sportId == sportId) {
      return;
    }
    state = state.copyWith(
      sportId: sportId,
      clearItems: true,
      clearCursor: true,
    );
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    final Result<ChallengePage> result = await ref
        .read(challengeRepositoryProvider)
        .loadChallenges(sportId: state.sportId);
    result.when<void>(
      success: (ChallengePage page) {
        state = state.copyWith(
          items: page.items,
          nextCursor: page.nextCursor,
          isLoading: false,
          clearError: true,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final Result<ChallengePage> result = await ref
        .read(challengeRepositoryProvider)
        .loadChallenges(sportId: state.sportId, cursor: state.nextCursor);
    result.when<void>(
      success: (ChallengePage page) {
        state = state.copyWith(
          items: <Challenge>[...state.items, ...page.items],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        );
      },
      failure: (Failure failure) {
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  Future<void> setSport(String? sportId) async {
    state = state.copyWith(
      sportId: sportId,
      clearSport: sportId == null,
      clearItems: true,
      clearCursor: true,
    );
    await refresh();
  }
}

class ChallengeActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<String?> create(CreateChallengeRequest request) async {
    state = const AsyncValue<void>.loading();
    final Result<String> result = await ref
        .read(challengeRepositoryProvider)
        .createChallenge(request);
    return result.when<String?>(
      success: (String id) {
        state = const AsyncValue<void>.data(null);
        ref.invalidate(challengeCatalogControllerProvider);
        return id;
      },
      failure: (Failure failure) {
        state = AsyncValue<void>.error(failure.message, StackTrace.current);
        return null;
      },
    );
  }

  Future<bool> join(String challengeId) => _run(
    () => ref.read(challengeRepositoryProvider).joinChallenge(challengeId),
    challengeId,
  );

  Future<bool> leave(String challengeId) => _run(
    () => ref.read(challengeRepositoryProvider).leaveChallenge(challengeId),
    challengeId,
  );

  Future<bool> submit(SubmitChallengeProgressRequest request) => _run(
    () => ref.read(challengeRepositoryProvider).submitProgress(request),
    request.challengeId,
  );

  Future<bool> setReminder(String challengeId, bool enabled) => _run(
    () => ref
        .read(challengeRepositoryProvider)
        .setReminder(challengeId, enabled: enabled),
    challengeId,
  );

  Future<bool> claim(String challengeId) => _run(
    () => ref.read(challengeRepositoryProvider).claimRewards(challengeId),
    challengeId,
  );

  Future<Result<String>> uploadProof({
    required String challengeId,
    required String localPath,
  }) => ref
      .read(challengeRepositoryProvider)
      .uploadProof(challengeId: challengeId, localPath: localPath);

  Future<bool> reviewSubmission({
    required String challengeId,
    required String submissionId,
    required bool approve,
  }) => _run(
    () => ref
        .read(challengeRepositoryProvider)
        .reviewSubmission(
          challengeId: challengeId,
          submissionId: submissionId,
          approve: approve,
        ),
    challengeId,
  );

  Future<Result<String>> createProofReviewUrl({
    required String challengeId,
    required String submissionId,
  }) => ref
      .read(challengeRepositoryProvider)
      .createProofReviewUrl(
        challengeId: challengeId,
        submissionId: submissionId,
      );

  Future<bool> _run(
    Future<Result<void>> Function() action,
    String challengeId,
  ) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await action();
    return result.when<bool>(
      success: (_) {
        state = const AsyncValue<void>.data(null);
        ref.invalidate(challengeProvider(challengeId));
        ref.invalidate(challengeParticipationProvider(challengeId));
        ref.invalidate(challengeLeaderboardProvider(challengeId));
        ref.invalidate(challengeSubmissionsProvider(challengeId));
        ref.invalidate(myChallengeHistoryProvider);
        ref.invalidate(myChallengeBadgesProvider);
        ref.invalidate(myChallengeRewardClaimsProvider);
        return true;
      },
      failure: (Failure failure) {
        state = AsyncValue<void>.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }
}

class ChallengeCatalogState {
  const ChallengeCatalogState({
    this.items = const <Challenge>[],
    this.sportId,
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<Challenge> items;
  final String? sportId;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  ChallengeCatalogState copyWith({
    List<Challenge>? items,
    String? sportId,
    String? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearSport = false,
    bool clearItems = false,
    bool clearCursor = false,
    bool clearError = false,
  }) {
    return ChallengeCatalogState(
      items: clearItems ? const <Challenge>[] : items ?? this.items,
      sportId: clearSport ? null : sportId ?? this.sportId,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);
