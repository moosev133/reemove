import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

class PreferenceSwitchTile extends StatelessWidget {
  const PreferenceSwitchTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });

  final bool value;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: enabled ? scheme.primary : scheme.outline),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
