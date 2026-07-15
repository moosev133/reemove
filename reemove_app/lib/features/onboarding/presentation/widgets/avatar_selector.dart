import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class AvatarSelector extends StatelessWidget {
  const AvatarSelector({
    required this.displayName,
    required this.uploading,
    required this.onPressed,
    super.key,
    this.avatarUrl,
  });

  final String displayName;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String initial = displayName.trim().isEmpty
        ? 'R'
        : String.fromCharCode(displayName.trim().runes.first).toUpperCase();
    return Column(
      children: <Widget>[
        Stack(
          alignment: Alignment.bottomRight,
          children: <Widget>[
            Container(
              width: 142,
              height: 142,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[AppColors.brand, AppColors.accent],
                ),
              ),
              child: CircleAvatar(
                backgroundColor: scheme.surfaceContainerHighest,
                backgroundImage: avatarUrl == null
                    ? null
                    : NetworkImage(avatarUrl!),
                child: avatarUrl == null
                    ? Text(
                        initial,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      )
                    : null,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: uploading ? null : onPressed,
              icon: uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(uploading ? 'Uploading' : 'Change'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'JPG, PNG, WEBP, or HEIC · up to 10 MB',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
