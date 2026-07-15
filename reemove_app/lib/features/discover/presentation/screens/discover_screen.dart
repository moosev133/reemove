import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/premium_surface.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin<DiscoverScreen> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Explore your sports world',
            title: 'Discover',
            subtitle:
                'Search across athletes, trainers, clubs, groups, places, events, routes, and challenges.',
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchBar(
            hintText: 'Search ReeMove',
            leading: const Icon(Icons.search_rounded),
            onTap: () => context.push(AppRoutes.discoverSearch),
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumSurface(
            onTap: () => context.push(AppRoutes.nearby),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.explore_rounded,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Explore nearby',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'See players, places, matches, classes, and routes on one live map.',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(
            title: 'Explore by category',
            subtitle:
                'Browse the part of the sports community you need right now.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _CategoryCard(
                icon: Icons.people_alt_outlined,
                title: 'People',
                onTap: () => context.push(AppRoutes.discoverCategory('people')),
              ),
              _CategoryCard(
                icon: Icons.place_outlined,
                title: 'Places',
                onTap: () => context.push(AppRoutes.discoverCategory('places')),
              ),
              _CategoryCard(
                icon: Icons.event_outlined,
                title: 'Events',
                onTap: () => context.push(AppRoutes.discoverCategory('events')),
              ),
              _CategoryCard(
                icon: Icons.emoji_events_outlined,
                title: 'Challenges',
                onTap: () => context.push(AppRoutes.challenges),
              ),
              _CategoryCard(
                icon: Icons.storefront_outlined,
                title: 'Marketplace',
                onTap: () => context.push(AppRoutes.marketplace),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppEmptyState(
            icon: Icons.shield_outlined,
            title: 'Discovery respects your privacy',
            message:
                'Results follow profile visibility, age-segment, blocking, sport, and location preferences.',
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: PremiumSurface(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}
