import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'network_media_image.dart';

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    required this.url,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.loop = true,
    this.showControls = true,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool loop;
  final bool showControls;
  final BoxFit fit;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      unawaited(_initialize());
      return;
    }
    if (oldWidget.autoPlay != widget.autoPlay) {
      final VideoPlayerController? controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        if (widget.autoPlay) {
          unawaited(controller.play());
        } else {
          unawaited(controller.pause());
        }
      }
    }
  }

  Future<void> _initialize() async {
    try {
      final Uri? uri = Uri.tryParse(widget.url);
      if (uri == null) {
        throw const FormatException('Invalid video URL.');
      }
      final VideoPlayerController controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(widget.loop);
      if (widget.autoPlay) {
        await controller.play();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      _error = error;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final VideoPlayerController? controller = _controller;
      if (controller != null) {
        unawaited(controller.pause());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final VideoPlayerController? controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    if (_error != null) {
      return _VideoFallback(thumbnailUrl: widget.thumbnailUrl);
    }
    if (controller == null || !controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _VideoFallback(thumbnailUrl: widget.thumbnailUrl),
          const Center(child: CircularProgressIndicator.adaptive()),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.showControls
          ? () async {
              if (controller.value.isPlaying) {
                await controller.pause();
              } else {
                await controller.play();
              }
              if (mounted) {
                setState(() {});
              }
            }
          : null,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: <Widget>[
          FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (widget.showControls && !controller.value.isPlaying)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x33000000),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          if (widget.showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return NetworkMediaImage(url: thumbnailUrl!);
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.videocam_off_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
