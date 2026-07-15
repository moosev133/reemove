import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/sport_leaderboard.dart';

class SportLeaderboardCard extends StatelessWidget {
  const SportLeaderboardCard({required this.leaderboard, super.key});

  final SportLeaderboard leaderboard;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            leaderboard.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${leaderboard.period.name} • ${leaderboard.metric}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...leaderboard.entries
              .take(5)
              .map(
                (SportLeaderboardEntry entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#${entry.rank}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      AppAvatar(
                        displayName: entry.displayName,
                        imageUrl: entry.avatarUrl,
                        radius: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.displayName),
                            Text(
                              '@${entry.username}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        entry.formattedValue,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        entry.trend > 0
                            ? Icons.trending_up_rounded
                            : entry.trend < 0
                            ? Icons.trending_down_rounded
                            : Icons.remove_rounded,
                        size: 18,
                        color: entry.trend > 0
                            ? Colors.green
                            : entry.trend < 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
