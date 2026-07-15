import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/sport_trainer.dart';

class SportTrainerCard extends StatelessWidget {
  const SportTrainerCard({
    required this.trainer,
    required this.onTap,
    super.key,
  });

  final SportTrainer trainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(
            displayName: trainer.displayName,
            imageUrl: trainer.avatarUrl,
            radius: 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        trainer.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (trainer.isVerified)
                      Icon(
                        Icons.verified_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                  ],
                ),
                if (trainer.headline case final String headline) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    AppStatusChip(
                      label: trainer.reviewCount == 0
                          ? 'New trainer'
                          : '${trainer.rating.toStringAsFixed(1)} • ${trainer.reviewCount}',
                      icon: Icons.star_rounded,
                      color: scheme.tertiary,
                    ),
                    AppStatusChip(
                      label: '${trainer.yearsExperience} years',
                      icon: Icons.workspace_premium_outlined,
                      color: scheme.secondary,
                    ),
                    if (trainer.minimumPrice != null)
                      AppStatusChip(
                        label:
                            'From ${trainer.minimumPrice!.amountMajor.toStringAsFixed(0)} ${trainer.minimumPrice!.currency}',
                        icon: Icons.payments_outlined,
                        color: scheme.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
