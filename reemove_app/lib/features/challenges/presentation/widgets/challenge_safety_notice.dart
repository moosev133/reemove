import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/challenge.dart';

class ChallengeSafetyNotice extends StatelessWidget {
  const ChallengeSafetyNotice({required this.policy, super.key});

  final ChallengeSafetyPolicy policy;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.health_and_safety_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Safety rules',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(policy.healthDisclaimer),
          const SizedBox(height: AppSpacing.sm),
          Text('Minimum age: ${policy.minimumAge}'),
          Text(
            'Daily effort cap: ${policy.maximumEffortMinutesPerDay} minutes',
          ),
          if (policy.requiresRestDays) const Text('Rest days are required.'),
          if (policy.prohibitedBehaviors.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Not allowed: ${policy.prohibitedBehaviors.join(', ')}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
