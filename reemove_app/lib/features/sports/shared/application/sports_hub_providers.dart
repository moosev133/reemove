import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../challenges/domain/entities/challenge.dart';
import '../data/repositories/firebase_sports_hub_repository.dart';
import '../domain/entities/sport_community.dart';
import '../domain/entities/sport_leaderboard.dart';
import '../domain/entities/sport_management_requests.dart';
import '../domain/entities/sport_participation.dart';
import '../domain/entities/sport_place.dart';
import '../domain/entities/sport_trainer.dart';
import '../domain/entities/sports_event.dart';
import '../domain/repositories/sports_hub_repository.dart';

final Provider<SportsHubRepository> sportsHubRepositoryProvider =
    Provider<SportsHubRepository>((Ref ref) {
      return FirebaseSportsHubRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

final sportChallengesProvider = StreamProvider.family<List<Challenge>, String>((
  Ref ref,
  String sportId,
) async* {
  await for (final Result<List<Challenge>> result
      in ref
          .watch(challengeRepositoryProvider)
          .watchActiveForSport(sportId, limit: 8)) {
    yield _value(result);
  }
});

final sportPlaceProvider = StreamProvider.family<SportPlace?, String>((
  Ref ref,
  String placeId,
) async* {
  await for (final Result<SportPlace?> result
      in ref.watch(sportsCatalogRepositoryProvider).watchPlace(placeId)) {
    yield _value(result);
  }
});

final sportEventProvider = StreamProvider.family<SportsEvent?, String>((
  Ref ref,
  String eventId,
) async* {
  await for (final Result<SportsEvent?> result
      in ref.watch(sportsCatalogRepositoryProvider).watchEvent(eventId)) {
    yield _value(result);
  }
});

final sportPlacesProvider = StreamProvider.family<List<SportPlace>, String>((
  Ref ref,
  String sportId,
) async* {
  await for (final Result<List<SportPlace>> result
      in ref
          .watch(sportsCatalogRepositoryProvider)
          .watchPlacesForSport(sportId, limit: 20)) {
    yield _value(result);
  }
});

final sportEventsProvider = StreamProvider.family<List<SportsEvent>, String>((
  Ref ref,
  String sportId,
) async* {
  await for (final Result<List<SportsEvent>> result
      in ref
          .watch(sportsCatalogRepositoryProvider)
          .watchUpcomingEvents(sportId, limit: 30)) {
    yield _value(result);
  }
});

final sportCommunitiesProvider =
    StreamProvider.family<List<SportCommunity>, String>((
      Ref ref,
      String sportId,
    ) async* {
      await for (final Result<List<SportCommunity>> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchCommunities(sportId, limit: 30)) {
        yield _value(result);
      }
    });

final sportTrainersProvider = StreamProvider.family<List<SportTrainer>, String>(
  (Ref ref, String sportId) async* {
    await for (final Result<List<SportTrainer>> result
        in ref
            .watch(sportsHubRepositoryProvider)
            .watchTrainers(sportId, limit: 30)) {
      yield _value(result);
    }
  },
);

final sportLeaderboardsProvider =
    StreamProvider.family<List<SportLeaderboard>, String>((
      Ref ref,
      String sportId,
    ) async* {
      await for (final Result<List<SportLeaderboard>> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchLeaderboards(sportId, limit: 10)) {
        yield _value(result);
      }
    });

final sportCommunityProvider = StreamProvider.family<SportCommunity?, String>((
  Ref ref,
  String communityId,
) async* {
  await for (final Result<SportCommunity?> result
      in ref.watch(sportsHubRepositoryProvider).watchCommunity(communityId)) {
    yield _value(result);
  }
});

final sportCommunityMembersProvider =
    StreamProvider.family<List<SportCommunityMember>, String>((
      Ref ref,
      String communityId,
    ) async* {
      await for (final Result<List<SportCommunityMember>> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchCommunityMembers(communityId)) {
        yield _value(result);
      }
    });

final sportCommunityJoinRequestsProvider =
    StreamProvider.family<List<SportCommunityMember>, String>((
      Ref ref,
      String communityId,
    ) async* {
      await for (final Result<List<SportCommunityMember>> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchCommunityJoinRequests(communityId)) {
        yield _value(result);
      }
    });

final sportCommunityMembershipProvider =
    StreamProvider.family<SportCommunityMembershipStatus, String>((
      Ref ref,
      String communityId,
    ) async* {
      final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
      if (user == null) {
        yield SportCommunityMembershipStatus.none;
        return;
      }
      await for (final Result<SportCommunityMembershipStatus> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchCommunityMembership(
                communityId: communityId,
                userId: user.uid,
              )) {
        yield _value(result);
      }
    });

final sportTrainerProvider = StreamProvider.family<SportTrainer?, String>((
  Ref ref,
  String trainerId,
) async* {
  await for (final Result<SportTrainer?> result
      in ref.watch(sportsHubRepositoryProvider).watchTrainer(trainerId)) {
    yield _value(result);
  }
});

final trainerServicesProvider =
    StreamProvider.family<List<TrainerService>, String>((
      Ref ref,
      String trainerId,
    ) async* {
      await for (final Result<List<TrainerService>> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchTrainerServices(trainerId: trainerId)) {
        yield _value(result);
      }
    });

final sportEventParticipationProvider =
    StreamProvider.family<SportsEventParticipation, String>((
      Ref ref,
      String eventId,
    ) async* {
      final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
      if (user == null) {
        yield SportsEventParticipation(
          eventId: eventId,
          status: SportsEventAttendanceStatus.none,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        return;
      }
      await for (final Result<SportsEventParticipation> result
          in ref
              .watch(sportsHubRepositoryProvider)
              .watchEventParticipation(eventId: eventId, userId: user.uid)) {
        yield _value(result);
      }
    });

final NotifierProvider<SportsHubActionController, AsyncValue<void>>
sportsHubActionControllerProvider =
    NotifierProvider<SportsHubActionController, AsyncValue<void>>(
      SportsHubActionController.new,
    );

class SportsHubActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<String?> createCommunity(CreateSportCommunityRequest request) =>
      _stringAction(
        () => ref.read(sportsHubRepositoryProvider).createCommunity(request),
      );

  Future<bool> joinCommunity(String communityId) => _voidLikeAction(() async {
    final Result<SportCommunityMembershipStatus> result = await ref
        .read(sportsHubRepositoryProvider)
        .joinCommunity(communityId);
    _value(result);
  });

  Future<bool> leaveCommunity(String communityId) => _resultAction(
    () => ref.read(sportsHubRepositoryProvider).leaveCommunity(communityId),
  );

  Future<bool> respondToCommunityJoinRequest({
    required String communityId,
    required String userId,
    required bool approve,
  }) => _resultAction(
    () => ref
        .read(sportsHubRepositoryProvider)
        .respondToCommunityJoinRequest(
          communityId: communityId,
          userId: userId,
          approve: approve,
        ),
  );

  Future<String?> createEvent(CreateSportsEventRequest request) =>
      _stringAction(
        () => ref.read(sportsHubRepositoryProvider).createEvent(request),
      );

  Future<bool> attendEvent(String eventId) => _voidLikeAction(() async {
    final Result<SportsEventAttendanceStatus> result = await ref
        .read(sportsHubRepositoryProvider)
        .attendEvent(eventId);
    _value(result);
  });

  Future<bool> leaveEvent(String eventId) => _resultAction(
    () => ref.read(sportsHubRepositoryProvider).leaveEvent(eventId),
  );

  Future<String?> upsertTrainerService(UpsertTrainerServiceRequest request) =>
      _stringAction(
        () =>
            ref.read(sportsHubRepositoryProvider).upsertTrainerService(request),
      );

  Future<String?> _stringAction(
    Future<Result<String>> Function() action,
  ) async {
    state = const AsyncValue<void>.loading();
    try {
      final String value = _value(await action());
      state = const AsyncValue<void>.data(null);
      return value;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return null;
    }
  }

  Future<bool> _resultAction(Future<Result<void>> Function() action) async {
    state = const AsyncValue<void>.loading();
    try {
      _value(await action());
      state = const AsyncValue<void>.data(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> _voidLikeAction(Future<void> Function() action) async {
    state = const AsyncValue<void>.loading();
    try {
      await action();
      state = const AsyncValue<void>.data(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
  }
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);
