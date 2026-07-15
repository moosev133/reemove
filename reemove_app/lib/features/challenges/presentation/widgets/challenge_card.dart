import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/challenge.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    required this.challenge,
    required this.onTap,
    super.key,
  });

  final Challenge challenge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ChallengeRule rule = challenge.primaryRule;
    final int days = challenge.remaining.inDays.clamp(0, 999);
    return PremiumSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(child: Icon(_sportIcon(challenge.sportId))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      challenge.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${challenge.creatorName} · ${challenge.source.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (challenge.isFeatured)
                const Tooltip(
                  message: 'Featured challenge',
                  child: Icon(Icons.auto_awesome_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            challenge.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: 'Goal',
                  value: '${_format(rule.target)} ${rule.unit}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Participants',
                  value: '${challenge.participantCount}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Time left',
                  value: days == 0 ? 'Today' : '$days days',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              Chip(label: Text(challenge.difficulty.name)),
              Chip(label: Text(_verificationLabel(rule.verificationMethod))),
              if (challenge.aiDisclosure != null)
                const Chip(
                  avatar: Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text('AI-assisted'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

String _format(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _verificationLabel(ChallengeVerificationMethod method) =>
    switch (method) {
      ChallengeVerificationMethod.automaticActivity => 'Activity verified',
      ChallengeVerificationMethod.activityAndProof => 'Activity + proof',
      ChallengeVerificationMethod.photoProof => 'Photo proof',
      ChallengeVerificationMethod.organizerReview => 'Organizer review',
    };

IconData _sportIcon(String sportId) => switch (sportId) {
  'football' => Icons.sports_soccer_rounded,
  'gym' => Icons.fitness_center_rounded,
  'running' => Icons.directions_run_rounded,
  _ => Icons.emoji_events_rounded,
};
