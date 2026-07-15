import 'dart:async';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_section_header.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../../../challenges/domain/entities/challenge.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_community.dart';
import '../../domain/entities/sport_leaderboard.dart';
import '../../domain/entities/sport_place.dart';
import '../../domain/entities/sport_trainer.dart';
import '../../domain/entities/sports_event.dart';
import '../../domain/services/sport_module_registry.dart';
import '../widgets/sport_community_card.dart';
import '../widgets/sport_event_card.dart';
import '../widgets/sport_leaderboard_card.dart';
import '../widgets/sport_place_card.dart';
import '../widgets/sport_trainer_card.dart';

class SportHubScreen extends ConsumerWidget {
  const SportHubScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportModuleConfig module = SportModuleRegistry.resolve(sportId);
    final AsyncValue<List<SportPlace>> places = ref.watch(
      sportPlacesProvider(sportId),
    );
    final AsyncValue<List<SportCommunity>> communities = ref.watch(
      sportCommunitiesProvider(sportId),
    );
    final AsyncValue<List<SportsEvent>> events = ref.watch(
      sportEventsProvider(sportId),
    );
    final AsyncValue<List<SportTrainer>> trainers = ref.watch(
      sportTrainersProvider(sportId),
    );
    final AsyncValue<List<SportLeaderboard>> leaderboards = ref.watch(
      sportLeaderboardsProvider(sportId),
    );
    final AsyncValue<List<Challenge>> challenges = ref.watch(
      sportChallengesProvider(sportId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(module.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create in ${module.title}',
            onPressed: () => _showCreateMenu(context, module),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sportPlacesProvider(sportId));
          ref.invalidate(sportCommunitiesProvider(sportId));
          ref.invalidate(sportEventsProvider(sportId));
          ref.invalidate(sportTrainersProvider(sportId));
          ref.invalidate(sportLeaderboardsProvider(sportId));
          ref.invalidate(sportChallengesProvider(sportId));
        },
        child: AdaptivePageBody(
          restorationId: 'sport_hub_$sportId',
          slivers: <Widget>[
            AppPageHeader(
              eyebrow: 'Complete sport hub',
              title: module.title,
              subtitle: module.subtitle,
              trailing: Icon(_sportIcon(sportId), size: 46),
            ),
            const SizedBox(height: AppSpacing.lg),
            _QuickActions(module: module, sportId: sportId),
            const SizedBox(height: AppSpacing.xl),
            _PreviewSection<SportsEvent>(
              title: module.eventLabel,
              subtitle: 'Upcoming activity selected for this sport.',
              value: events,
              emptyIcon: Icons.event_busy_outlined,
              emptyTitle: 'No upcoming activity',
              onSeeAll: () => context.push(AppRoutes.sportEvents(sportId)),
              itemBuilder: (SportsEvent event) => SportEventCard(
                event: event,
                onTap: () =>
                    context.push(AppRoutes.sportEvent(sportId, event.id)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PreviewSection<SportCommunity>(
              title: module.communityLabel,
              subtitle: 'Join people training and competing near you.',
              value: communities,
              emptyIcon: Icons.groups_outlined,
              emptyTitle: 'No communities yet',
              onSeeAll: () => context.push(AppRoutes.sportCommunities(sportId)),
              itemBuilder: (SportCommunity community) => SportCommunityCard(
                community: community,
                onTap: () => context.push(
                  AppRoutes.sportCommunity(sportId, community.id),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PreviewSection<SportPlace>(
              title: module.placeLabel,
              subtitle: sportId == 'running'
                  ? 'Browse route starts, tracks, and trusted running locations.'
                  : 'Verified facilities with ratings and pricing where available.',
              value: places,
              emptyIcon: Icons.place_outlined,
              emptyTitle: 'No places listed yet',
              onSeeAll: () => context.push(AppRoutes.sportPlaces(sportId)),
              itemBuilder: (SportPlace place) => SportPlaceCard(
                place: place,
                onTap: () =>
                    context.push(AppRoutes.sportPlace(sportId, place.id)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PreviewSection<SportTrainer>(
              title: 'Trainers & experts',
              subtitle: 'Verified specialists currently accepting clients.',
              value: trainers,
              emptyIcon: Icons.workspace_premium_outlined,
              emptyTitle: 'No trainers available',
              onSeeAll: () => context.push(AppRoutes.sportTrainers(sportId)),
              itemBuilder: (SportTrainer trainer) => SportTrainerCard(
                trainer: trainer,
                onTap: () =>
                    context.push(AppRoutes.sportTrainer(sportId, trainer.id)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PreviewSection<SportLeaderboard>(
              title: 'Leaderboards',
              subtitle: module.leaderboardMetric,
              value: leaderboards,
              emptyIcon: Icons.leaderboard_outlined,
              emptyTitle: 'Rankings are being prepared',
              onSeeAll: () =>
                  context.push(AppRoutes.sportLeaderboards(sportId)),
              itemBuilder: (SportLeaderboard leaderboard) =>
                  SportLeaderboardCard(leaderboard: leaderboard),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSectionHeader(
              title: 'Active challenges',
              subtitle:
                  'Community and official goals for ${module.title.toLowerCase()}.',
              actionLabel: 'All challenges',
              onAction: () => context.push(
                AppRoutes.discoverCategory('challenges-$sportId'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            challenges.when(
              data: (List<Challenge> items) => items.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No active challenges',
                      message: 'New weekly challenges will appear here.',
                    )
                  : Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: items
                          .take(3)
                          .map((Challenge item) {
                            return SizedBox(
                              width: 330,
                              child: PremiumSurface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      item.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      item.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      '${item.participantCount} participants',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (Object error, StackTrace _) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu(BuildContext context, SportModuleConfig module) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Create for ${module.title}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: Text('Create ${module.communityLabel.toLowerCase()}'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      context.push(AppRoutes.createSportCommunity(sportId)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text('Create ${module.eventLabel.toLowerCase()}'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      context.push(AppRoutes.createSportEvent(sportId)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('Publish trainer service'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      context.push(AppRoutes.manageTrainerService(sportId)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _sportIcon(String sportId) => switch (sportId) {
    'football' => Icons.sports_soccer_rounded,
    'gym' => Icons.fitness_center_rounded,
    'running' => Icons.directions_run_rounded,
    _ => Icons.sports_rounded,
  };
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.module, required this.sportId});

  final SportModuleConfig module;
  final String sportId;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, String)>
    actions = <(IconData, String, String)>[
      (Icons.place_outlined, module.placeLabel, AppRoutes.sportPlaces(sportId)),
      (Icons.explore_outlined, 'Nearby', AppRoutes.nearbyForSport(sportId)),
      (
        Icons.groups_outlined,
        module.communityLabel,
        AppRoutes.sportCommunities(sportId),
      ),
      (Icons.event_outlined, module.eventLabel, AppRoutes.sportEvents(sportId)),
      (
        Icons.workspace_premium_outlined,
        'Trainers',
        AppRoutes.sportTrainers(sportId),
      ),
      (
        Icons.leaderboard_outlined,
        'Leaderboards',
        AppRoutes.sportLeaderboards(sportId),
      ),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions
          .map(((IconData, String, String) action) {
            return ActionChip(
              avatar: Icon(action.$1, size: 18),
              label: Text(action.$2),
              onPressed: () => context.push(action.$3),
            );
          })
          .toList(growable: false),
    );
  }
}

class _PreviewSection<T> extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.itemBuilder,
    required this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final AsyncValue<List<T>> value;
  final IconData emptyIcon;
  final String emptyTitle;
  final Widget Function(T item) itemBuilder;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: 'See all',
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpacing.md),
        value.when(
          data: (List<T> items) => items.isEmpty
              ? AppEmptyState(
                  icon: emptyIcon,
                  title: emptyTitle,
                  message:
                      'This section will update as new verified activity becomes available.',
                )
              : Column(
                  children: items
                      .take(3)
                      .map(
                        (T item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: itemBuilder(item),
                        ),
                      )
                      .toList(growable: false),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (Object error, StackTrace _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load $title',
            message: error.toString(),
          ),
        ),
      ],
    );
  }
}
