import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:reemove/features/onboarding/domain/entities/onboarding_policy.dart';
import 'package:reemove/features/onboarding/domain/onboarding_validators.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';

void main() {
  const OnboardingPolicy policy = OnboardingPolicy(
    minimumAge: 13,
    maximumAge: 120,
  );

  group('OnboardingValidators', () {
    test('requires birthday, sports, levels, and goals', () {
      final OnboardingDraft initial = OnboardingDraft.initial();
      expect(
        OnboardingValidators.validateStep(
          OnboardingStep.birthday,
          initial,
          policy,
        ),
        isNotNull,
      );
      expect(
        OnboardingValidators.validateStep(
          OnboardingStep.sports,
          initial,
          policy,
        ),
        isNotNull,
      );
    });

    test('accepts a complete valid draft', () {
      final DateTime now = DateTime.now().toUtc();
      final OnboardingDraft draft = OnboardingDraft.initial().copyWith(
        dateOfBirth: DateTime.utc(now.year - 18, now.month, now.day),
        favoriteSportIds: const <String>['football'],
        sportLevels: const <String, SportLevel>{
          'football': SportLevel.intermediate,
        },
        goals: const <String>['stay_active'],
      );

      expect(OnboardingValidators.validateAll(draft, policy), isNull);
    });

    test('rejects a user below the configured minimum age', () {
      final DateTime now = DateTime.now().toUtc();
      final OnboardingDraft draft = OnboardingDraft.initial().copyWith(
        dateOfBirth: DateTime.utc(now.year - 12, now.month, now.day),
      );

      expect(
        OnboardingValidators.validateStep(
          OnboardingStep.birthday,
          draft,
          policy,
        ),
        contains('at least 13'),
      );
    });

    test('removes levels for deselected sports', () {
      final Map<String, SportLevel> result =
          OnboardingValidators.levelsForSelectedSports(
            const <String>['running'],
            const <String, SportLevel>{
              'football': SportLevel.advanced,
              'running': SportLevel.beginner,
            },
          );

      expect(result, const <String, SportLevel>{
        'running': SportLevel.beginner,
      });
    });
  });
}
