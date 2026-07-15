import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class SelectableOptionCard extends StatelessWidget {
  const SelectableOptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.72)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brand.withValues(alpha: 0.18)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: selected ? AppColors.brandDeep : null),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
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
              const SizedBox(width: AppSpacing.sm),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
