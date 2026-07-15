import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final String initials = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part.characters.first.toUpperCase())
        .join();
    final String? normalizedUrl = imageUrl?.trim();
    return CircleAvatar(
      radius: radius,
      foregroundImage: normalizedUrl == null || normalizedUrl.isEmpty
          ? null
          : NetworkImage(normalizedUrl),
      child: Text(
        initials.isEmpty ? 'R' : initials,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
