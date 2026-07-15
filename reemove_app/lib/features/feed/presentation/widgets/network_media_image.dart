import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetworkMediaImage extends StatelessWidget {
  const NetworkMediaImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (BuildContext context, String _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      ),
      errorWidget: (BuildContext context, String _, Object error) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    final Widget clipped = borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
    return semanticLabel == null
        ? clipped
        : Semantics(image: true, label: semanticLabel, child: clipped);
  }
}
