import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/group_requests.dart';
import '../../domain/entities/group_session.dart';

class GroupScheduleScreen extends ConsumerWidget {
  const GroupScheduleScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupSession>> sessionsValue = ref.watch(
      groupSessionsProvider(groupId),
    );
    final AsyncValue<Group> groupValue = ref.watch(groupProvider(groupId));
    final bool canManage = groupValue.value?.isManager ?? false;
    final bool isMember = groupValue.value?.isMember ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New session'),
            )
          : null,
      body: sessionsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => AppErrorView(
          title: 'Schedule unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupSessionsProvider(groupId)),
        ),
        data: (List<GroupSession> sessions) {
          if (sessions.isEmpty) {
            return AdaptivePageBody(
              slivers: const <Widget>[
                AppEmptyState(
                  icon: Icons.event_outlined,
                  title: 'No sessions scheduled',
                  message:
                      'Training, matches, and events for this group will appear here.',
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupSessionsProvider(groupId));
              await ref.read(groupSessionsProvider(groupId).future);
            },
            child: AdaptivePageBody(
              slivers: <Widget>[
                ...sessions.map(
                  (GroupSession session) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SessionTile(
                      session: session,
                      canManage: canManage,
                      canRsvp: isMember &&
                          session.status == GroupSessionStatus.scheduled,
                      onCancel: () => _cancelSession(context, ref, session),
                      onRsvp: (GroupSessionRsvpStatus status) =>
                          _rsvp(context, ref, session, status),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _rsvp(
    BuildContext context,
    WidgetRef ref,
    GroupSession session,
    GroupSessionRsvpStatus status,
  ) async {
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .respondToGroupSessionRsvp(
          groupId: groupId,
          sessionId: session.sessionId,
          status: status,
        );
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      final Object? error = ref.read(groupsActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error?.toString() ?? 'Could not update RSVP.',
          ),
        ),
      );
    }
  }

  Future<void> _cancelSession(
    BuildContext context,
    WidgetRef ref,
    GroupSession session,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Cancel ${session.title}?'),
            content: const Text(
              'Members will be notified and this session will show as cancelled.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep it'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancel session'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref
        .read(groupsActionControllerProvider.notifier)
        .cancelGroupSession(groupId: groupId, sessionId: session.sessionId);
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _CreateSessionSheet(groupId: groupId),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.canManage,
    required this.canRsvp,
    required this.onCancel,
    required this.onRsvp,
  });

  final GroupSession session;
  final bool canManage;
  final bool canRsvp;
  final VoidCallback onCancel;
  final ValueChanged<GroupSessionRsvpStatus> onRsvp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.title,
                      style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                  Text(
                      session.sessionType.displayLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (session.activity.isNotEmpty &&
                        session.activity != session.sessionType.wireValue) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        session.activity,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                const SizedBox(height: AppSpacing.xs),
                if (session.startAt != null)
                  Text(
                    _formatRange(session.startAt!, session.endAt),
                        style: theme.textTheme.labelMedium,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                  children: <Widget>[
                    AppStatusChip(
                      label: switch (session.status) {
                        GroupSessionStatus.scheduled => 'Scheduled',
                        GroupSessionStatus.cancelled => 'Cancelled',
                        GroupSessionStatus.completed => 'Completed',
                      },
                      icon: session.isCancelled
                          ? Icons.event_busy_outlined
                          : Icons.event_available_outlined,
                      color: session.isCancelled
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        if (!session.isCancelled)
                          AppStatusChip(
                            label:
                                '${session.rsvpCounts.going} going'
                                '${session.capacity > 0 ? ' / ${session.capacity}' : ''}',
                            icon: Icons.people_outline_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                      ],
                ),
              ],
            ),
          ),
          if (canManage && session.status == GroupSessionStatus.scheduled)
            IconButton(
              tooltip: 'Cancel session',
              onPressed: onCancel,
              icon: const Icon(Icons.event_busy_outlined),
            ),
            ],
          ),
          if (canRsvp) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: GroupSessionRsvpStatus.values.map((
                GroupSessionRsvpStatus status,
              ) {
                final bool selected = session.viewerRsvp == status;
                final bool disabledGoing =
                    status == GroupSessionRsvpStatus.going &&
                    session.isAtCapacity &&
                    session.viewerRsvp != GroupSessionRsvpStatus.going;
                return FilterChip(
                  label: Text(status.displayLabel),
                  selected: selected,
                  onSelected: disabledGoing
                      ? null
                      : (_) => onRsvp(status),
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatRange(DateTime start, DateTime? end) {
    final DateTime localStart = start.toLocal();
    final String startLabel =
        '${localStart.day}/${localStart.month}/${localStart.year} '
        '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
    if (end == null) {
      return startLabel;
    }
    final DateTime localEnd = end.toLocal();
    return '$startLabel – ${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}';
  }
}

class _CreateSessionSheet extends ConsumerStatefulWidget {
  const _CreateSessionSheet({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_CreateSessionSheet> createState() =>
      _CreateSessionSheetState();
}

class _CreateSessionSheetState extends ConsumerState<_CreateSessionSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _activity = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _capacity = TextEditingController(text: '0');
  GroupSessionType _sessionType = GroupSessionType.training;
  DateTime _startAt = DateTime.now().add(const Duration(days: 1));
  DateTime _endAt = DateTime.now().add(const Duration(days: 1, hours: 1));
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _activity.dispose();
    _description.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
              Text(
                'New session',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<GroupSessionType>(
                segments: GroupSessionType.values
                    .map(
                      (GroupSessionType type) => ButtonSegment<GroupSessionType>(
                        value: type,
                        label: Text(type.displayLabel),
                      ),
                    )
                    .toList(growable: false),
                selected: <GroupSessionType>{_sessionType},
                onSelectionChanged: (Set<GroupSessionType> next) {
                  setState(() => _sessionType = next.first);
                },
              ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: 120,
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _activity,
                decoration: const InputDecoration(
                  labelText: 'Sport / detail (optional)',
                ),
              maxLength: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
            ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _capacity,
                decoration: const InputDecoration(
                  labelText: 'Capacity (0 = unlimited)',
                ),
                keyboardType: TextInputType.number,
                validator: (String? value) {
                  final int? parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0 || parsed > 10000) {
                    return 'Enter a capacity from 0 to 10000';
                  }
                  return null;
                },
              ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Starts'),
              subtitle: Text(_startAt.toLocal().toString()),
              onTap: () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Ends'),
              subtitle: Text(_endAt.toLocal().toString()),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(_submitting ? 'Creating…' : 'Create session'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final DateTime initial = isStart ? _startAt : _endAt;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    final DateTime combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = combined;
        if (!_endAt.isAfter(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        _endAt = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_endAt.isAfter(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final String? sessionId = await ref
        .read(groupsActionControllerProvider.notifier)
        .createGroupSession(
          CreateGroupSessionRequest(
            groupId: widget.groupId,
            title: _title.text.trim(),
            sessionType: _sessionType,
            activity: _activity.text.trim(),
            description: _description.text.trim(),
            capacity: int.parse(_capacity.text.trim()),
            startAt: _startAt.toUtc(),
            endAt: _endAt.toUtc(),
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (sessionId != null) {
      Navigator.of(context).pop();
    }
  }
}
