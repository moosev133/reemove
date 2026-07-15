import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_leaderboard.dart';
import '../../domain/services/sport_module_registry.dart';
import '../widgets/sport_leaderboard_card.dart';

class SportLeaderboardsScreen extends ConsumerWidget {
  const SportLeaderboardsScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportModuleConfig module = SportModuleRegistry.resolve(sportId);
    final AsyncValue<List<SportLeaderboard>> value = ref.watch(
      sportLeaderboardsProvider(sportId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboards')),
      body: AdaptivePageBody(
        restorationId: 'sport_leaderboards_$sportId',
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: 'Leaderboards',
            subtitle:
                '${module.leaderboardMetric}. Rankings are server-generated and read-only.',
          ),
          const SizedBox(height: AppSpacing.lg),
          value.when(
            data: (List<SportLeaderboard> items) => items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.leaderboard_outlined,
                    title: 'No rankings yet',
                    message:
                        'Verified activity will populate this leaderboard.',
                  )
                : Column(
                    children: items
                        .map(
                          (SportLeaderboard item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SportLeaderboardCard(leaderboard: item),
                          ),
                        )
                        .toList(growable: false),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace _) => Text(error.toString()),
          ),
        ],
      ),
    );
  }
}
