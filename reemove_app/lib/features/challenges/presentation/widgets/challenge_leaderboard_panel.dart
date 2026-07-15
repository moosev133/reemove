import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/challenge.dart';

class ChallengeLeaderboardPanel extends StatelessWidget {
  const ChallengeLeaderboardPanel({required this.entries, super.key});

  final List<ChallengeLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.leaderboard_outlined,
        title: 'No verified rankings yet',
        message: 'Rankings appear after progress is verified.',
      );
    }
    return PremiumSurface(
      child: Column(
        children: entries
            .take(20)
            .map((ChallengeLeaderboardEntry entry) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    entry.rank <= 3 ? _medal(entry.rank) : '${entry.rank}',
                  ),
                ),
                title: Text(entry.displayName),
                subtitle: Text('@${entry.username}'),
                trailing: Text(
                  '${entry.progressPercent.clamp(0, 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

String _medal(int rank) => switch (rank) {
  1 => '🥇',
  2 => '🥈',
  3 => '🥉',
  _ => '$rank',
};
