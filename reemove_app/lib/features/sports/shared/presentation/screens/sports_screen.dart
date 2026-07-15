import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_section_header.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../../../authentication/application/authentication_providers.dart';

class SportsScreen extends ConsumerStatefulWidget {
  const SportsScreen({super.key});

  @override
  ConsumerState<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends ConsumerState<SportsScreen>
    with AutomaticKeepAliveClientMixin<SportsScreen> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final List<String> favoriteIds =
        ref.watch(currentUserProfileProvider).value?.favoriteSportIds ??
        const <String>[];
    const List<_SportSummary> sports = <_SportSummary>[
      _SportSummary(
        id: 'football',
        title: 'Football',
        icon: Icons.sports_soccer_rounded,
        description:
            'Matches, pitches, teams, events, challenges, and trainers.',
      ),
      _SportSummary(
        id: 'gym',
        title: 'Gym',
        icon: Icons.fitness_center_rounded,
        description:
            'Gyms, workouts, training partners, coaches, and progress.',
      ),
      _SportSummary(
        id: 'running',
        title: 'Running',
        icon: Icons.directions_run_rounded,
        description: 'Routes, clubs, sessions, challenges, and leaderboards.',
      ),
    ];
    final List<_SportSummary> ordered = List<_SportSummary>.of(sports)
      ..sort((_SportSummary a, _SportSummary b) {
        final bool aFavorite = favoriteIds.contains(a.id);
        final bool bFavorite = favoriteIds.contains(b.id);
        if (aFavorite == bFavorite) {
          return a.title.compareTo(b.title);
        }
        return aFavorite ? -1 : 1;
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Sports')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'One app, every sport',
            title: 'Your sports hubs',
            subtitle:
                'Each sport has its own community, places, events, challenges, leaderboards, and expert network.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: favoriteIds.isEmpty
                ? 'Featured sports'
                : 'Your sports first',
            subtitle: favoriteIds.isEmpty
                ? 'Choose a hub to start exploring.'
                : 'Favorite sports are prioritized from your onboarding choices.',
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardWidth = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - AppSpacing.md * 2) / 3
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: ordered
                    .map(
                      (_SportSummary sport) => SizedBox(
                        width: cardWidth,
                        child: _SportHubCard(
                          sport: sport,
                          isFavorite: favoriteIds.contains(sport.id),
                          onTap: () =>
                              context.push(AppRoutes.sportHub(sport.id)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SportSummary {
  const _SportSummary({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String id;
  final String title;
  final IconData icon;
  final String description;
}

class _SportHubCard extends StatelessWidget {
  const _SportHubCard({
    required this.sport,
    required this.isFavorite,
    required this.onTap,
  });

  final _SportSummary sport;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Icon(
                    sport.icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 30,
                  ),
                ),
              ),
              const Spacer(),
              if (isFavorite)
                const Chip(
                  avatar: Icon(Icons.star_rounded, size: 18),
                  label: Text('Favorite'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(sport.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sport.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Text(
                'Open hub',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_forward_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
