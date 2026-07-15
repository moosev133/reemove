import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/media_asset.dart';
import 'inline_video_player.dart';
import 'network_media_image.dart';

class PostMediaGallery extends StatefulWidget {
  const PostMediaGallery({
    required this.media,
    this.aspectRatio = 1,
    this.autoPlayVideo = false,
    super.key,
  });

  final List<MediaAsset> media;
  final double aspectRatio;
  final bool autoPlayVideo;

  @override
  State<PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<PostMediaGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PageView.builder(
            itemCount: widget.media.length,
            onPageChanged: (int value) => setState(() => _index = value),
            itemBuilder: (BuildContext context, int index) {
              final MediaAsset item = widget.media[index];
              if (item.kind == MediaKind.video && item.downloadUrl != null) {
                return InlineVideoPlayer(
                  url: item.downloadUrl!,
                  thumbnailUrl: item.thumbnailUrl,
                  autoPlay: widget.autoPlayVideo,
                );
              }
              final String? url = item.downloadUrl ?? item.thumbnailUrl;
              if (url == null) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.hourglass_top_rounded)),
                );
              }
              return NetworkMediaImage(
                url: url,
                semanticLabel:
                    'Post media ${index + 1} of ${widget.media.length}',
              );
            },
          ),
          if (widget.media.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    '${_index + 1}/${widget.media.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          if (widget.media.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(widget.media.length, (
                  int index,
                ) {
                  final bool active = index == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
