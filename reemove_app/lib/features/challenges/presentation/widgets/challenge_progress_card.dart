import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/challenge.dart';

class ChallengeProgressCard extends StatelessWidget {
  const ChallengeProgressCard({
    required this.challenge,
    required this.participation,
    required this.onSubmit,
    required this.onReminderChanged,
    this.onClaim,
    super.key,
  });

  final Challenge challenge;
  final ChallengeParticipation participation;
  final VoidCallback onSubmit;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final ChallengeRule rule = challenge.primaryRule;
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Your progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (participation.rank != null)
                Chip(label: Text('Rank #${participation.rank}')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: (participation.progressPercent / 100).clamp(0, 1),
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_format(participation.progress)} / ${_format(rule.target)} ${rule.unit} '
            '(${participation.progressPercent.clamp(0, 100).toStringAsFixed(0)}%)',
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: participation.reminderEnabled,
            onChanged:
                participation.status == ChallengeParticipationStatus.active
                ? onReminderChanged
                : null,
            title: const Text('Challenge reminders'),
            subtitle: const Text(
              'Only send reminders during your allowed notification hours.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  participation.status == ChallengeParticipationStatus.active
                  ? onSubmit
                  : null,
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text('Add verified progress'),
            ),
          ),
          if (participation.status == ChallengeParticipationStatus.completed &&
              onClaim != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onClaim,
                icon: const Icon(Icons.redeem_rounded),
                label: const Text('Claim badge and rewards'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _format(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
