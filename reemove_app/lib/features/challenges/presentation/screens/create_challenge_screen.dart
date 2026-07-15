import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../application/challenge_providers.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_requests.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({this.initialSportId, super.key});

  final String? initialSportId;

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _target = TextEditingController(text: '5');
  final TextEditingController _dailyCap = TextEditingController(text: '2');
  late String _sportId;
  ChallengeDifficulty _difficulty = ChallengeDifficulty.beginner;
  ChallengeMetric _metric = ChallengeMetric.sessions;
  ChallengeVerificationMethod _verification =
      ChallengeVerificationMethod.automaticActivity;
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _endsAt = DateTime.now().add(const Duration(days: 7));
  bool _restDays = true;

  @override
  void initState() {
    super.initState();
    _sportId = widget.initialSportId ?? 'running';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _dailyCap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(
      challengeActionControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Create challenge')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Community challenge',
            title: 'Set a clear, safe goal',
            subtitle:
                'Challenges are reviewed automatically for unsafe language, excessive targets, and unsupported metrics before publishing.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (String? value) => (value ?? '').trim().length < 4
                      ? 'Use at least 4 characters.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  maxLength: 600,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    helperText:
                        'Explain the goal and what counts. Do not encourage pain, deprivation, or unsafe behavior.',
                  ),
                  validator: (String? value) => (value ?? '').trim().length < 12
                      ? 'Add a clearer description.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _sportId,
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'football',
                      child: Text('Football'),
                    ),
                    DropdownMenuItem(value: 'gym', child: Text('Gym')),
                    DropdownMenuItem(value: 'running', child: Text('Running')),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _sportId = value ?? _sportId),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ChallengeDifficulty>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: ChallengeDifficulty.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _difficulty = value ?? _difficulty),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ChallengeMetric>(
                  initialValue: _metric,
                  decoration: const InputDecoration(labelText: 'Metric'),
                  items: _metricsFor(_sportId)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_metricLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _metric = value ?? _metric),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _target,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Total target (${_unitFor(_metric)})',
                        ),
                        validator: _positiveNumber,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _dailyCap,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Daily cap (${_unitFor(_metric)})',
                        ),
                        validator: _positiveNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ChallengeVerificationMethod>(
                  initialValue: _verification,
                  decoration: const InputDecoration(labelText: 'Verification'),
                  items: ChallengeVerificationMethod.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_verificationLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _verification = value ?? _verification),
                ),
                const SizedBox(height: AppSpacing.md),
                _DateTile(
                  label: 'Starts',
                  value: _startsAt,
                  onTap: () => _pickDate(start: true),
                ),
                _DateTile(
                  label: 'Ends',
                  value: _endsAt,
                  onTap: () => _pickDate(start: false),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _restDays,
                  onChanged: (bool value) => setState(() => _restDays = value),
                  title: const Text('Require rest days'),
                  subtitle: const Text(
                    'Recommended for duration, distance, volume, and repetition goals.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: action.isLoading ? null : _submit,
                  icon: action.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.emoji_events_rounded),
                  label: const Text('Publish challenge'),
                ),
                if (action.hasError) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    action.error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_endsAt.difference(_startsAt) < const Duration(hours: 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The challenge must run for at least one hour.'),
        ),
      );
      return;
    }
    final String? id = await ref
        .read(challengeActionControllerProvider.notifier)
        .create(
          CreateChallengeRequest(
            sportId: _sportId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            difficulty: _difficulty,
            startsAt: _startsAt,
            endsAt: _endsAt,
            metric: _metric,
            target: double.parse(_target.text),
            unit: _unitFor(_metric),
            verificationMethod: _verification,
            maximumDailyProgress: double.parse(_dailyCap.text),
            minimumAge: 14,
            requiresRestDays: _restDays,
            maximumEffortMinutesPerDay:
                _difficulty == ChallengeDifficulty.advanced ? 120 : 90,
          ),
        );
    if (id != null && mounted) {
      context.go(AppRoutes.challenge(id));
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final DateTime initial = start ? _startsAt : _endsAt;
    final DateTime? value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (value == null) {
      return;
    }
    setState(() {
      final DateTime next = DateTime(
        value.year,
        value.month,
        value.day,
        initial.hour,
      );
      if (start) {
        _startsAt = next;
      } else {
        _endsAt = next;
      }
    });
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.calendar_today_outlined),
    title: Text(label),
    subtitle: Text(
      '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year}',
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

String? _positiveNumber(String? value) {
  final double? parsed = double.tryParse(value ?? '');
  if (parsed == null || parsed <= 0) {
    return 'Enter a positive number.';
  }
  return null;
}

List<ChallengeMetric> _metricsFor(String sportId) => switch (sportId) {
  'running' => const <ChallengeMetric>[
    ChallengeMetric.distance,
    ChallengeMetric.duration,
    ChallengeMetric.sessions,
  ],
  'gym' => const <ChallengeMetric>[
    ChallengeMetric.sessions,
    ChallengeMetric.volume,
    ChallengeMetric.repetitions,
    ChallengeMetric.duration,
  ],
  'football' => const <ChallengeMetric>[
    ChallengeMetric.sessions,
    ChallengeMetric.attendance,
    ChallengeMetric.points,
    ChallengeMetric.duration,
  ],
  _ => const <ChallengeMetric>[ChallengeMetric.sessions],
};

String _unitFor(ChallengeMetric metric) => switch (metric) {
  ChallengeMetric.distance => 'km',
  ChallengeMetric.duration => 'minutes',
  ChallengeMetric.sessions => 'sessions',
  ChallengeMetric.repetitions => 'reps',
  ChallengeMetric.volume => 'kg',
  ChallengeMetric.attendance => 'sessions',
  ChallengeMetric.points => 'points',
};

String _metricLabel(ChallengeMetric metric) => switch (metric) {
  ChallengeMetric.distance => 'Distance',
  ChallengeMetric.duration => 'Active time',
  ChallengeMetric.sessions => 'Sessions',
  ChallengeMetric.repetitions => 'Repetitions',
  ChallengeMetric.volume => 'Training volume',
  ChallengeMetric.attendance => 'Attendance',
  ChallengeMetric.points => 'Points',
};

String _verificationLabel(ChallengeVerificationMethod method) =>
    switch (method) {
      ChallengeVerificationMethod.automaticActivity =>
        'Linked ReeMove activity',
      ChallengeVerificationMethod.activityAndProof => 'Activity and proof',
      ChallengeVerificationMethod.photoProof => 'Photo proof',
      ChallengeVerificationMethod.organizerReview => 'Organizer review',
    };
