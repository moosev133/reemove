import '../../profile/domain/entities/user_profile.dart';
import 'entities/onboarding_draft.dart';
import 'entities/onboarding_policy.dart';

abstract final class OnboardingValidators {
  static String? validateStep(
    OnboardingStep step,
    OnboardingDraft draft,
    OnboardingPolicy policy,
  ) {
    return switch (step) {
      OnboardingStep.profile => null,
      OnboardingStep.birthday => _birthday(draft.dateOfBirth, policy),
      OnboardingStep.sports =>
        draft.favoriteSportIds.isEmpty
            ? 'Choose at least one sport to personalize ReeMove.'
            : null,
      OnboardingStep.levels => _levels(draft),
      OnboardingStep.goals =>
        draft.goals.isEmpty ? 'Choose at least one goal.' : null,
      OnboardingStep.location => null,
      OnboardingStep.discovery => _discovery(draft),
      OnboardingStep.accessibility => null,
      OnboardingStep.notifications => null,
      OnboardingStep.review => validateAll(draft, policy),
    };
  }

  static String? validateAll(OnboardingDraft draft, OnboardingPolicy policy) {
    for (final OnboardingStep step in OnboardingStep.values) {
      if (step == OnboardingStep.review) {
        continue;
      }
      final String? error = validateStep(step, draft, policy);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  static String? _birthday(DateTime? value, OnboardingPolicy policy) {
    if (value == null) {
      return 'Enter your birthday to continue.';
    }
    final DateTime now = DateTime.now().toUtc();
    int age = now.year - value.year;
    if (now.month < value.month ||
        (now.month == value.month && now.day < value.day)) {
      age -= 1;
    }
    if (age < policy.minimumAge) {
      return 'You must be at least ${policy.minimumAge} years old to use ReeMove.';
    }
    if (age > policy.maximumAge) {
      return 'Enter a valid birthday.';
    }
    return null;
  }

  static String? _levels(OnboardingDraft draft) {
    for (final String sportId in draft.favoriteSportIds) {
      if (draft.sportLevels[sportId] == null) {
        return 'Choose your level for every selected sport.';
      }
    }
    return null;
  }

  static String? _discovery(OnboardingDraft draft) {
    if (draft.discovery.radiusKm < 1 || draft.discovery.radiusKm > 200) {
      return 'Discovery radius must be between 1 and 200 km.';
    }
    return null;
  }

  static Map<String, SportLevel> levelsForSelectedSports(
    List<String> selectedSports,
    Map<String, SportLevel> current,
  ) {
    return <String, SportLevel>{
      for (final String sportId in selectedSports)
        if (current[sportId] != null) sportId: current[sportId]!,
    };
  }
}
