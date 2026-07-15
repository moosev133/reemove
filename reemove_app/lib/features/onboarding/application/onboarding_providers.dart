import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/result/result.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../authentication/domain/entities/auth_user.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../../sports/shared/domain/entities/sport_definition.dart';
import '../data/repositories/firebase_avatar_repository.dart';
import '../data/repositories/firebase_onboarding_repository.dart';
import '../data/services/firebase_notification_permission_service.dart';
import '../data/services/platform_avatar_picker_service.dart';
import '../data/services/platform_location_service.dart';
import '../domain/entities/avatar_asset.dart';
import '../domain/entities/onboarding_draft.dart';
import '../domain/entities/onboarding_policy.dart';
import '../domain/onboarding_validators.dart';
import '../domain/repositories/avatar_repository.dart';
import '../domain/repositories/onboarding_repository.dart';
import '../domain/services/avatar_picker_service.dart';
import '../domain/services/location_service.dart';
import '../domain/services/notification_permission_service.dart';
import 'onboarding_view_state.dart';

final Provider<FirebaseStorage>
firebaseStorageProvider = Provider<FirebaseStorage>((Ref ref) {
  final FirebaseBootstrapReport report = ref.watch(
    firebaseBootstrapReportProvider,
  );
  if (!report.isReady) {
    throw StateError(
      'Firebase Storage is unavailable because Firebase failed to initialize.',
    );
  }
  return FirebaseStorage.instance;
});

final Provider<OnboardingRepository> onboardingRepositoryProvider =
    Provider<OnboardingRepository>((Ref ref) {
      return FirebaseOnboardingRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

final Provider<AvatarRepository> avatarRepositoryProvider =
    Provider<AvatarRepository>((Ref ref) {
      return FirebaseAvatarRepository(ref.watch(firebaseStorageProvider));
    });

final Provider<AvatarPickerService> avatarPickerServiceProvider =
    Provider<AvatarPickerService>((Ref ref) {
      return PlatformAvatarPickerService();
    });

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) {
      return const PlatformLocationService();
    });

final Provider<NotificationPermissionService>
notificationPermissionServiceProvider = Provider<NotificationPermissionService>(
  (Ref ref) {
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final FirebaseBootstrapReport report = ref.watch(
      firebaseBootstrapReportProvider,
    );
    if (!report.isReady || environment.useFirebaseEmulators) {
      return const UnavailableNotificationPermissionService();
    }
    return FirebaseNotificationPermissionService(FirebaseMessaging.instance);
  },
);

final AsyncNotifierProvider<OnboardingController, OnboardingViewState>
onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingViewState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingViewState> {
  @override
  Future<OnboardingViewState> build() async {
    final AuthUser? authUser = await ref.watch(currentAuthUserProvider.future);
    final UserProfile? profile = await ref.watch(
      currentUserProfileProvider.future,
    );
    if (authUser == null || profile == null) {
      throw StateError('A signed-in profile is required for onboarding.');
    }

    final Future<Result<OnboardingDraft?>> draftFuture = ref
        .read(onboardingRepositoryProvider)
        .loadDraft(authUser.uid);
    final Future<Result<OnboardingPolicy>> policyFuture = ref
        .read(onboardingRepositoryProvider)
        .loadPolicy();
    final Future<Result<List<SportDefinition>>> sportsFuture = ref
        .read(sportsCatalogRepositoryProvider)
        .watchEnabledSports()
        .first;

    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      draftFuture,
      policyFuture,
      sportsFuture,
    ]);
    final Result<OnboardingDraft?> draftResult =
        values[0] as Result<OnboardingDraft?>;
    final Result<OnboardingPolicy> policyResult =
        values[1] as Result<OnboardingPolicy>;
    final Result<List<SportDefinition>> sportsResult =
        values[2] as Result<List<SportDefinition>>;

    final OnboardingDraft? savedDraft = draftResult.when<OnboardingDraft?>(
      success: (OnboardingDraft? value) => value,
      failure: (failure) => throw StateError(failure.message),
    );
    final OnboardingPolicy policy = policyResult.when<OnboardingPolicy>(
      success: (OnboardingPolicy value) => value,
      failure: (failure) => throw StateError(failure.message),
    );
    final List<SportDefinition> sports = sportsResult
        .when<List<SportDefinition>>(
          success: (List<SportDefinition> value) => value,
          failure: (failure) => throw StateError(failure.message),
        );

    return OnboardingViewState(
      profile: profile,
      draft:
          savedDraft ?? OnboardingDraft.initial(avatarUrl: profile.avatarUrl),
      policy: policy,
      sports: sports,
    );
  }

  void clearFailure() {
    final OnboardingViewState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(clearFailure: true),
    );
  }

  void setBirthday(DateTime value) => _updateDraft(
    (OnboardingDraft draft) => draft.copyWith(
      dateOfBirth: DateTime.utc(value.year, value.month, value.day),
    ),
  );

  void toggleSport(String sportId) {
    _updateDraft((OnboardingDraft draft) {
      final List<String> selected = List<String>.from(draft.favoriteSportIds);
      if (selected.contains(sportId)) {
        selected.remove(sportId);
      } else if (selected.length < 8) {
        selected.add(sportId);
      }
      return draft.copyWith(
        favoriteSportIds: selected,
        sportLevels: OnboardingValidators.levelsForSelectedSports(
          selected,
          draft.sportLevels,
        ),
      );
    });
  }

  void setSportLevel(String sportId, SportLevel level) {
    _updateDraft((OnboardingDraft draft) {
      final Map<String, SportLevel> levels = Map<String, SportLevel>.from(
        draft.sportLevels,
      );
      levels[sportId] = level;
      return draft.copyWith(sportLevels: levels);
    });
  }

  void toggleGoal(String goalId) {
    _updateDraft((OnboardingDraft draft) {
      final List<String> goals = List<String>.from(draft.goals);
      if (goals.contains(goalId)) {
        goals.remove(goalId);
      } else if (goals.length < 8) {
        goals.add(goalId);
      }
      return draft.copyWith(goals: goals);
    });
  }

  void setDiscovery(DiscoveryPreferences value) =>
      _updateDraft((OnboardingDraft draft) => draft.copyWith(discovery: value));

  void setAccessibility(AccessibilityPreferences value) => _updateDraft(
    (OnboardingDraft draft) => draft.copyWith(accessibility: value),
  );

  void setNotifications(NotificationPreferences value) => _updateDraft(
    (OnboardingDraft draft) => draft.copyWith(notifications: value),
  );

  Future<void> recoverLostAvatar() async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return;
    }
    final Result<AvatarUploadSource?> result = await ref
        .read(avatarPickerServiceProvider)
        .recoverLostSelection();
    await result.when<Future<void>>(
      success: (AvatarUploadSource? source) async {
        if (source != null) {
          await _uploadAvatar(source);
        }
      },
      failure: (failure) async => _setFailure(failure),
    );
  }

  Future<void> chooseAvatar({required bool camera}) async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return;
    }
    clearFailure();
    final AvatarPickerService picker = ref.read(avatarPickerServiceProvider);
    final Result<AvatarUploadSource?> result = camera
        ? await picker.pickFromCamera()
        : await picker.pickFromGallery();
    await result.when<Future<void>>(
      success: (AvatarUploadSource? source) async {
        if (source != null) {
          await _uploadAvatar(source);
        }
      },
      failure: (failure) async => _setFailure(failure),
    );
  }

  Future<void> requestLocation() async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return;
    }
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(isRequestingLocation: true, clearFailure: true),
    );
    final Result<LocationCapture> result = await ref
        .read(locationServiceProvider)
        .requestCurrentLocation();
    result.when<void>(
      success: (LocationCapture capture) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(
            isRequestingLocation: false,
            draft: latest.draft.copyWith(
              location: capture.location,
              clearLocation: capture.location == null,
              locationPermission: capture.permission,
            ),
          ),
        );
      },
      failure: (failure) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(isRequestingLocation: false, failure: failure),
        );
      },
    );
  }

  Future<void> openApplicationSettings() async {
    await ref.read(locationServiceProvider).openApplicationSettings();
  }

  Future<void> openDeviceLocationSettings() async {
    await ref.read(locationServiceProvider).openDeviceLocationSettings();
  }

  Future<void> requestNotificationPermission() async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return;
    }
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(isRequestingNotifications: true, clearFailure: true),
    );
    final Result<NotificationPermissionDecision> result = await ref
        .read(notificationPermissionServiceProvider)
        .requestPermission();
    result.when<void>(
      success: (NotificationPermissionDecision decision) {
        final OnboardingViewState latest = state.requireValue;
        final bool enabled =
            decision == NotificationPermissionDecision.authorized ||
            decision == NotificationPermissionDecision.provisional;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(
            isRequestingNotifications: false,
            draft: latest.draft.copyWith(
              notifications: latest.draft.notifications.copyWith(
                masterEnabled: enabled,
                permissionStatus: decision,
              ),
            ),
          ),
        );
      },
      failure: (failure) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(isRequestingNotifications: false, failure: failure),
        );
      },
    );
  }

  Future<bool> continueToNextStep() async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return false;
    }
    final String? error = OnboardingValidators.validateStep(
      current.draft.currentStep,
      current.draft,
      current.policy,
    );
    if (error != null) {
      _setFailureMessage(error, 'onboarding/validation');
      return false;
    }
    final OnboardingStep? next = current.draft.currentStep.next;
    if (next == null) {
      return complete();
    }
    return _save(current.draft.copyWith(currentStep: next));
  }

  Future<bool> goBack() async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return false;
    }
    final OnboardingStep? previous = current.draft.currentStep.previous;
    if (previous == null) {
      return false;
    }
    return _save(current.draft.copyWith(currentStep: previous));
  }

  Future<bool> complete() async {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return false;
    }
    final String? error = OnboardingValidators.validateAll(
      current.draft,
      current.policy,
    );
    if (error != null) {
      _setFailureMessage(error, 'onboarding/validation');
      return false;
    }

    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(isSaving: true, clearFailure: true),
    );
    final Result<void> result = await ref
        .read(onboardingRepositoryProvider)
        .complete(current.draft);
    return result.when<bool>(
      success: (_) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(isSaving: false),
        );
        ref.invalidate(currentUserProfileProvider);
        return true;
      },
      failure: (failure) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(isSaving: false, failure: failure),
        );
        return false;
      },
    );
  }

  Future<bool> _save(OnboardingDraft draft) async {
    final OnboardingViewState current = state.requireValue;
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(draft: draft, isSaving: true, clearFailure: true),
    );
    final Result<OnboardingDraft> result = await ref
        .read(onboardingRepositoryProvider)
        .saveProgress(draft);
    return result.when<bool>(
      success: (OnboardingDraft saved) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(draft: saved, isSaving: false),
        );
        return true;
      },
      failure: (failure) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(isSaving: false, failure: failure),
        );
        return false;
      },
    );
  }

  Future<void> _uploadAvatar(AvatarUploadSource source) async {
    final OnboardingViewState current = state.requireValue;
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(isUploadingAvatar: true, clearFailure: true),
    );
    final Result<AvatarAsset> result = await ref
        .read(avatarRepositoryProvider)
        .upload(
          uid: current.profile.uid,
          source: source,
          previousStoragePath: current.draft.avatarStoragePath,
        );
    result.when<void>(
      success: (AvatarAsset asset) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(
            isUploadingAvatar: false,
            draft: latest.draft.copyWith(
              avatarUrl: asset.downloadUrl,
              avatarStoragePath: asset.storagePath,
            ),
          ),
        );
      },
      failure: (failure) {
        final OnboardingViewState latest = state.requireValue;
        state = AsyncValue<OnboardingViewState>.data(
          latest.copyWith(isUploadingAvatar: false, failure: failure),
        );
      },
    );
  }

  void _updateDraft(OnboardingDraft Function(OnboardingDraft draft) update) {
    final OnboardingViewState? current = state.value;
    if (current == null || current.isBusy) {
      return;
    }
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(draft: update(current.draft), clearFailure: true),
    );
  }

  void _setFailure(Failure failure) {
    final OnboardingViewState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue<OnboardingViewState>.data(
      current.copyWith(failure: failure),
    );
  }

  void _setFailureMessage(String message, String code) {
    _setFailure(Failure(message: message, code: code));
  }
}
