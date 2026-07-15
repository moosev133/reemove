import '../../../core/errors/failure.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../../sports/shared/domain/entities/sport_definition.dart';
import '../domain/entities/onboarding_draft.dart';
import '../domain/entities/onboarding_policy.dart';

class OnboardingViewState {
  const OnboardingViewState({
    required this.profile,
    required this.draft,
    required this.policy,
    required this.sports,
    this.isSaving = false,
    this.isUploadingAvatar = false,
    this.isRequestingLocation = false,
    this.isRequestingNotifications = false,
    this.failure,
  });

  final UserProfile profile;
  final OnboardingDraft draft;
  final OnboardingPolicy policy;
  final List<SportDefinition> sports;
  final bool isSaving;
  final bool isUploadingAvatar;
  final bool isRequestingLocation;
  final bool isRequestingNotifications;
  final Failure? failure;

  bool get isBusy =>
      isSaving ||
      isUploadingAvatar ||
      isRequestingLocation ||
      isRequestingNotifications;

  OnboardingViewState copyWith({
    UserProfile? profile,
    OnboardingDraft? draft,
    OnboardingPolicy? policy,
    List<SportDefinition>? sports,
    bool? isSaving,
    bool? isUploadingAvatar,
    bool? isRequestingLocation,
    bool? isRequestingNotifications,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return OnboardingViewState(
      profile: profile ?? this.profile,
      draft: draft ?? this.draft,
      policy: policy ?? this.policy,
      sports: sports ?? this.sports,
      isSaving: isSaving ?? this.isSaving,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      isRequestingLocation: isRequestingLocation ?? this.isRequestingLocation,
      isRequestingNotifications:
          isRequestingNotifications ?? this.isRequestingNotifications,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
