import 'package:flutter/material.dart';

class AppAvatar extends StatefulWidget {
  const AppAvatar({
    required this.displayName,
    super.key,
    this.imageUrl,
    this.radius = 24,
  });

  final String displayName;
  final String? imageUrl;
  final double radius;

  @override
  State<AppAvatar> createState() => _AppAvatarState();
}

class _AppAvatarState extends State<AppAvatar> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(AppAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String initials = widget.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part.characters.first.toUpperCase())
        .join();
    final String? normalizedUrl = widget.imageUrl?.trim();
    final bool showImage =
        !_imageFailed && normalizedUrl != null && normalizedUrl.isNotEmpty;
    return CircleAvatar(
      radius: widget.radius,
      foregroundImage: showImage ? NetworkImage(normalizedUrl) : null,
      onForegroundImageError: showImage
          ? (_, _) {
              if (mounted) {
                setState(() => _imageFailed = true);
              }
            }
          : null,
      child: Text(
        initials.isEmpty ? 'R' : initials,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
