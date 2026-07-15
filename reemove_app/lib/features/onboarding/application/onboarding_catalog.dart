import 'package:flutter/material.dart';

import '../domain/entities/onboarding_draft.dart';

class OnboardingGoalOption {
  const OnboardingGoalOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

abstract final class OnboardingCatalog {
  static const List<OnboardingGoalOption> goals = <OnboardingGoalOption>[
    OnboardingGoalOption(
      id: 'stay_active',
      label: 'Stay active',
      description: 'Build movement into your everyday routine.',
      icon: Icons.directions_run_rounded,
    ),
    OnboardingGoalOption(
      id: 'build_strength',
      label: 'Build strength',
      description: 'Progress safely with consistent strength work.',
      icon: Icons.fitness_center_rounded,
    ),
    OnboardingGoalOption(
      id: 'improve_endurance',
      label: 'Improve endurance',
      description: 'Go farther and recover better over time.',
      icon: Icons.monitor_heart_outlined,
    ),
    OnboardingGoalOption(
      id: 'lose_weight_safely',
      label: 'Support a healthy weight',
      description: 'Focus on sustainable activity and wellbeing.',
      icon: Icons.balance_rounded,
    ),
    OnboardingGoalOption(
      id: 'gain_muscle',
      label: 'Gain muscle',
      description: 'Train consistently and track your progress.',
      icon: Icons.trending_up_rounded,
    ),
    OnboardingGoalOption(
      id: 'learn_a_sport',
      label: 'Learn a sport',
      description: 'Find beginner-friendly sessions and people.',
      icon: Icons.school_outlined,
    ),
    OnboardingGoalOption(
      id: 'find_training_partners',
      label: 'Find training partners',
      description: 'Meet people who move at your pace.',
      icon: Icons.group_add_outlined,
    ),
    OnboardingGoalOption(
      id: 'join_matches',
      label: 'Join matches',
      description: 'Discover nearby games that need players.',
      icon: Icons.sports_soccer_rounded,
    ),
    OnboardingGoalOption(
      id: 'prepare_for_competition',
      label: 'Prepare to compete',
      description: 'Work toward events and performance goals.',
      icon: Icons.emoji_events_outlined,
    ),
    OnboardingGoalOption(
      id: 'improve_wellbeing',
      label: 'Improve wellbeing',
      description: 'Use movement to support energy and mood.',
      icon: Icons.self_improvement_rounded,
    ),
  ];

  static String stepTitle(OnboardingStep step) => switch (step) {
    OnboardingStep.profile => 'Make it yours',
    OnboardingStep.birthday => 'Your age, kept private',
    OnboardingStep.sports => 'What moves you?',
    OnboardingStep.levels => 'Meet you at your level',
    OnboardingStep.goals => 'What are you working toward?',
    OnboardingStep.location => 'Move near you',
    OnboardingStep.discovery => 'Shape your discovery',
    OnboardingStep.accessibility => 'Make ReeMove comfortable',
    OnboardingStep.notifications => 'Stay in the loop',
    OnboardingStep.review => 'Ready to move',
  };

  static String stepSubtitle(OnboardingStep step) => switch (step) {
    OnboardingStep.profile =>
      'Add a photo so teammates and training partners recognize you.',
    OnboardingStep.birthday =>
      'We use your birthday for age-appropriate safety and never show it publicly.',
    OnboardingStep.sports =>
      'Choose up to eight. Football, gym, and running are fully supported first.',
    OnboardingStep.levels =>
      'Your level helps ReeMove suggest better people, sessions, and challenges.',
    OnboardingStep.goals =>
      'Pick the outcomes you care about. You can change them later.',
    OnboardingStep.location =>
      'Location unlocks nearby courts, gyms, routes, events, and players.',
    OnboardingStep.discovery =>
      'Choose how far to explore and how visible your profile should be.',
    OnboardingStep.accessibility =>
      'Set preferences that make the interface easier to use.',
    OnboardingStep.notifications =>
      'Choose what deserves your attention. Marketing stays off by default.',
    OnboardingStep.review =>
      'Review your choices. ReeMove will use them to personalize your experience.',
  };
}
