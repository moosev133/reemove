import 'package:flutter/material.dart' hide Visibility;

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/sports_event.dart';

class SportEventCard extends StatelessWidget {
  const SportEventCard({required this.event, required this.onTap, super.key});

  final SportsEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime local = event.startAt.toLocal();
    return PremiumSurface(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 58,
            child: Column(
              children: <Widget>[
                Text(
                  _month(local.month),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${local.day}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  event.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    AppStatusChip(
                      label: event.capacity == 0
                          ? '${event.attendeeCount} attending'
                          : '${event.attendeeCount}/${event.capacity}',
                      icon: Icons.people_alt_outlined,
                      color: scheme.primary,
                    ),
                    AppStatusChip(
                      label: _eventType(event.type),
                      icon: Icons.event_available_rounded,
                      color: scheme.secondary,
                    ),
                    if (event.price != null)
                      AppStatusChip(
                        label:
                            '${event.price!.amountMajor.toStringAsFixed(2)} ${event.price!.currency}',
                        icon: Icons.payments_outlined,
                        color: scheme.tertiary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _month(int month) => const <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ][month - 1];

  static String _eventType(SportsEventType type) => switch (type) {
    SportsEventType.match => 'Match',
    SportsEventType.meetup => 'Meetup',
    SportsEventType.training => 'Training',
    SportsEventType.classSession => 'Class',
    SportsEventType.competition => 'Competition',
    SportsEventType.community => 'Community',
  };
}
