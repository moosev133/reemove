import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final String displayName = profile?.displayName ?? 'Athlete';
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReeMove'),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Activity',
            onPressed: () => context.push(AppRoutes.activity),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Semantics(
              button: true,
              label: 'Open profile',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.go(AppRoutes.profile),
                child: AppAvatar(
                  displayName: displayName,
                  imageUrl: profile?.avatarUrl,
                  radius: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProfileProvider);
        },
        child: AdaptivePageBody(
          controller: _scrollController,
          slivers: <Widget>[
            AppPageHeader(
              eyebrow: 'Your movement network',
              title: 'Ready to move, ${_firstName(displayName)}?',
              subtitle:
                  'Your personalized feed will bring together people, sessions, challenges, and moments from the sports you follow.',
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppSectionHeader(
              title: 'Start from here',
              subtitle:
                  'Fast routes into the parts of ReeMove that matter today.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _QuickActionCard(
                  icon: Icons.explore_rounded,
                  title: 'Discover nearby',
                  message: 'Find people, places, and events around you.',
                  onTap: () => context.go(AppRoutes.discover),
                ),
                _QuickActionCard(
                  icon: Icons.sports_soccer_rounded,
                  title: 'Open sports',
                  message: 'Jump into football, gym, or running.',
                  onTap: () => context.go(AppRoutes.sports),
                ),
                _QuickActionCard(
                  icon: Icons.add_circle_rounded,
                  title: 'Create',
                  message: 'Share a moment or organize an activity.',
                  onTap: () => context.go(AppRoutes.create),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppEmptyState(
              icon: Icons.dynamic_feed_outlined,
              title: 'Your feed is ready to learn from you',
              message:
                  'Follow athletes and communities, join sports activities, and your home feed will become more relevant with every move.',
              actionLabel: 'Explore ReeMove',
              onAction: () => context.go(AppRoutes.discover),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstName(String displayName) {
  final List<String> parts = displayName.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? 'athlete' : parts.first;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: PremiumSurface(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
