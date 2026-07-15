import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../application/feed_providers.dart';
import '../../domain/entities/story.dart';
import '../widgets/inline_video_player.dart';
import '../widgets/network_media_image.dart';
import '../widgets/relative_time.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({required this.authorId, super.key});

  final String authorId;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  int _index = 0;

  void _markViewed(Story story) {
    if (!story.isViewed) {
      unawaited(ref.read(storyRepositoryProvider).markViewed(story.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StoryGroup>> rail = ref.watch(storyRailProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: rail.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (_, _) => AppEmptyState(
          icon: Icons.auto_awesome_motion_outlined,
          title: 'Stories could not load',
          message: 'Return to the feed and try again.',
          actionLabel: 'Return home',
          onAction: () => context.go(AppRoutes.home),
        ),
        data: (List<StoryGroup> groups) {
          final StoryGroup? group = groups
              .where((StoryGroup item) => item.author.id == widget.authorId)
              .firstOrNull;
          if (group == null || group.stories.isEmpty) {
            return AppEmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'This story expired',
              message: 'Stories are available for 24 hours.',
              actionLabel: 'Return home',
              onAction: () => context.go(AppRoutes.home),
            );
          }
          final int safeIndex = _index
              .clamp(0, group.stories.length - 1)
              .toInt();
          final Story story = group.stories[safeIndex];
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _markViewed(story),
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) {
              final double width = MediaQuery.sizeOf(context).width;
              if (details.localPosition.dx < width * .35) {
                if (safeIndex > 0) {
                  setState(() => _index = safeIndex - 1);
                }
              } else if (safeIndex < group.stories.length - 1) {
                setState(() => _index = safeIndex + 1);
              } else {
                context.pop();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (story.media.kind.name == 'video' &&
                    story.media.downloadUrl != null)
                  InlineVideoPlayer(
                    url: story.media.downloadUrl!,
                    thumbnailUrl: story.media.thumbnailUrl,
                    autoPlay: true,
                    loop: false,
                    fit: BoxFit.contain,
                  )
                else if (story.media.downloadUrl != null)
                  NetworkMediaImage(
                    url: story.media.downloadUrl!,
                    fit: BoxFit.contain,
                  )
                else
                  const Center(
                    child: Text(
                      'Media is processing',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xAA000000),
                        Colors.transparent,
                        Color(0x99000000),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: List<Widget>.generate(
                            group.stories.length,
                            (int index) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: LinearProgressIndicator(
                                  value: index <= safeIndex ? 1 : 0,
                                  minHeight: 3,
                                  color: Colors.white,
                                  backgroundColor: Colors.white30,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            AppAvatar(
                              displayName: group.author.displayName,
                              imageUrl: group.author.avatarUrl,
                              radius: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${group.author.displayName}  ·  ${relativeTime(story.createdAt)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: context.pop,
                              color: Colors.white,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if ((story.caption ?? '').isNotEmpty)
                          Text(
                            story.caption!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
