import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../domain/entities/profile_content_page.dart';

class ProfileContentGrid extends StatelessWidget {
  const ProfileContentGrid({
    required this.page,
    required this.filter,
    required this.onOpen,
    super.key,
    this.onLoadMore,
  });

  final ProfileContentPage page;
  final ProfileContentFilter filter;
  final ValueChanged<String> onOpen;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return AppEmptyState(
        icon: _icon(filter),
        title: _title(filter),
        message: _message(filter),
      );
    }
    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 720 ? 4 : 3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: page.items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemBuilder: (BuildContext context, int index) {
                final post = page.items[index];
                final MediaAsset? media = post.media.isEmpty
                    ? null
                    : post.media.first;
                final String? url = media?.thumbnailUrl ?? media?.downloadUrl;
                return Semantics(
                  button: true,
                  label: post.kind.name == 'reel' ? 'Open reel' : 'Open post',
                  child: InkWell(
                    onTap: () => onOpen(post.id),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          child: url == null
                              ? const Icon(Icons.image_not_supported_outlined)
                              : CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  errorWidget:
                                      (
                                        BuildContext context,
                                        String url,
                                        Object error,
                                      ) => const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                ),
                        ),
                        if (post.isVideo)
                          const Positioned(
                            top: AppSpacing.xs,
                            right: AppSpacing.xs,
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              shadows: <Shadow>[Shadow(blurRadius: 8)],
                            ),
                          ),
                        if (post.media.length > 1)
                          const Positioned(
                            top: AppSpacing.xs,
                            left: AppSpacing.xs,
                            child: Icon(
                              Icons.collections_rounded,
                              color: Colors.white,
                              shadows: <Shadow>[Shadow(blurRadius: 8)],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (page.hasMore && onLoadMore != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('Load more'),
          ),
        ],
      ],
    );
  }

  static IconData _icon(ProfileContentFilter filter) => switch (filter) {
    ProfileContentFilter.posts => Icons.grid_view_rounded,
    ProfileContentFilter.reels => Icons.smart_display_outlined,
    ProfileContentFilter.saved => Icons.bookmark_border_rounded,
    ProfileContentFilter.reposted => Icons.repeat_rounded,
  };

  static String _title(ProfileContentFilter filter) => switch (filter) {
    ProfileContentFilter.posts => 'No posts yet',
    ProfileContentFilter.reels => 'No reels yet',
    ProfileContentFilter.saved => 'Nothing saved yet',
    ProfileContentFilter.reposted => 'No reposts yet',
  };

  static String _message(ProfileContentFilter filter) => switch (filter) {
    ProfileContentFilter.posts =>
      'Published photo and video posts will appear here.',
    ProfileContentFilter.reels => 'Published reels will appear here.',
    ProfileContentFilter.saved =>
      'Posts you save are private and appear only to you.',
    ProfileContentFilter.reposted => 'Content you repost will appear here.',
  };
}
