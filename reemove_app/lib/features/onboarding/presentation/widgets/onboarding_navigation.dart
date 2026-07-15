import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/onboarding_draft.dart';

class OnboardingNavigation extends StatelessWidget {
  const OnboardingNavigation({
    required this.step,
    required this.busy,
    required this.onBack,
    required this.onContinue,
    super.key,
  });

  final OnboardingStep step;
  final bool busy;
  final VoidCallback? onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool finish = step == OnboardingStep.review;
    return Row(
      children: <Widget>[
        if (step.previous != null)
          OutlinedButton.icon(
            onPressed: busy ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
          )
        else
          const SizedBox.shrink(),
        const Spacer(),
        FilledButton.icon(
          onPressed: busy ? null : onContinue,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Icon(
                  finish ? Icons.check_rounded : Icons.arrow_forward_rounded,
                ),
          label: Text(finish ? 'Finish setup' : 'Continue'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}
