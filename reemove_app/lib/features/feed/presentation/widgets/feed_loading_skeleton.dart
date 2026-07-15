import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final Color fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List<Widget>.generate(
        count,
        (int index) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(radius: 22, backgroundColor: fill),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(height: 14, width: 140, color: fill),
                          const SizedBox(height: 7),
                          Container(height: 10, width: 90, color: fill),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AspectRatio(aspectRatio: 1, child: ColoredBox(color: fill)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Container(height: 18, width: 48, color: fill),
                    const SizedBox(width: AppSpacing.md),
                    Container(height: 18, width: 48, color: fill),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
