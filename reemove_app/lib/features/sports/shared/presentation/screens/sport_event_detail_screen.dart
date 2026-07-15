import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_participation.dart';
import '../../domain/entities/sports_event.dart';

class SportEventDetailScreen extends ConsumerWidget {
  const SportEventDetailScreen({
    required this.sportId,
    required this.eventId,
    super.key,
  });

  final String sportId;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SportsEvent?> eventValue = ref.watch(
      sportEventProvider(eventId),
    );
    final AsyncValue<SportsEventParticipation> participationValue = ref.watch(
      sportEventParticipationProvider(eventId),
    );
    final AsyncValue<void> action = ref.watch(
      sportsHubActionControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: eventValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(error.toString())),
        data: (SportsEvent? event) {
          if (event == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Event unavailable',
                  message: 'This event may have been cancelled or restricted.',
                ),
              ),
            );
          }
          final SportsEventAttendanceStatus status =
              participationValue.value?.status ??
              SportsEventAttendanceStatus.none;
          final DateTime start = event.startAt.toLocal();
          final DateTime end = event.endAt.toLocal();
          return AdaptivePageBody(
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: sportId.toUpperCase(),
                title: event.title,
                subtitle: event.description,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppStatusChip(
                    label:
                        '${start.day}/${start.month}/${start.year} • ${_time(start)}–${_time(end)}',
                    icon: Icons.schedule_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  AppStatusChip(
                    label: event.capacity == 0
                        ? '${event.attendeeCount} attending'
                        : '${event.attendeeCount}/${event.capacity} attending',
                    icon: Icons.people_alt_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  AppStatusChip(
                    label: '${event.minimumLevel}–${event.maximumLevel}',
                    icon: Icons.stairs_rounded,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _AttendanceButton(
                status: status,
                loading: action.isLoading,
                onAttend: () async {
                  final bool ok = await ref
                      .read(sportsHubActionControllerProvider.notifier)
                      .attendEvent(eventId);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attendance updated.')),
                    );
                  }
                },
                onLeave: () async {
                  final bool ok = await ref
                      .read(sportsHubActionControllerProvider.notifier)
                      .leaveEvent(eventId);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You left the event.')),
                    );
                  }
                },
              ),
              if (action.hasError) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  action.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PremiumSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Event information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      icon: Icons.language_rounded,
                      label: event.timezone,
                    ),
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label:
                          event.location.locality ??
                          event.location.countryCode ??
                          'Location provided after joining',
                    ),
                    if (event.price != null)
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        label:
                            '${event.price!.amountMajor.toStringAsFixed(2)} ${event.price!.currency}',
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _AttendanceButton extends StatelessWidget {
  const _AttendanceButton({
    required this.status,
    required this.loading,
    required this.onAttend,
    required this.onLeave,
  });

  final SportsEventAttendanceStatus status;
  final bool loading;
  final VoidCallback onAttend;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (status == SportsEventAttendanceStatus.attending ||
        status == SportsEventAttendanceStatus.waitlisted) {
      return OutlinedButton.icon(
        onPressed: loading ? null : onLeave,
        icon: const Icon(Icons.event_busy_outlined),
        label: Text(
          status == SportsEventAttendanceStatus.waitlisted
              ? 'Leave waitlist'
              : 'Cancel attendance',
        ),
      );
    }
    return FilledButton.icon(
      onPressed: loading ? null : onAttend,
      icon: const Icon(Icons.event_available_rounded),
      label: const Text('Attend event'),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
