import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../application/feed_providers.dart';
import '../../domain/entities/story.dart';

class StoryRail extends ConsumerWidget {
  const StoryRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StoryGroup>> stories = ref.watch(storyRailProvider);
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: <Widget>[
          _CreateStoryTile(
            onTap: () => context.go(AppRoutes.createFlow('story')),
          ),
          ...stories.when(
            loading: () => List<Widget>.generate(
              5,
              (int index) => const _StoryLoadingTile(),
            ),
            error: (_, _) => <Widget>[
              _StoryErrorTile(onRetry: () => ref.invalidate(storyRailProvider)),
            ],
            data: (List<StoryGroup> groups) => groups
                .map(
                  (StoryGroup group) => _StoryTile(
                    group: group,
                    onTap: () =>
                        context.push(AppRoutes.storyGroup(group.author.id)),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _CreateStoryTile extends StatelessWidget {
  const _CreateStoryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _StoryTileShell(
      label: 'Your story',
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          CircleAvatar(
            radius: 31,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.person_outline_rounded),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.group, required this.onTap});

  final StoryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return _StoryTileShell(
      label: group.author.displayName.split(' ').first,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: group.hasUnseen
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[colors.primary, colors.tertiary],
                )
              : null,
          border: group.hasUnseen
              ? null
              : Border.all(color: colors.outlineVariant, width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
          ),
          child: AppAvatar(
            displayName: group.author.displayName,
            imageUrl: group.author.avatarUrl,
            radius: 28,
          ),
        ),
      ),
    );
  }
}

class _StoryTileShell extends StatelessWidget {
  const _StoryTileShell({
    required this.label,
    required this.child,
    required this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Column(
            children: <Widget>[
              child,
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryLoadingTile extends StatelessWidget {
  const _StoryLoadingTile();

  @override
  Widget build(BuildContext context) {
    return _StoryTileShell(
      label: '',
      onTap: () {},
      child: CircleAvatar(
        radius: 31,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _StoryErrorTile extends StatelessWidget {
  const _StoryErrorTile({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StoryTileShell(
      label: 'Retry',
      onTap: onRetry,
      child: CircleAvatar(
        radius: 31,
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.refresh_rounded,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
