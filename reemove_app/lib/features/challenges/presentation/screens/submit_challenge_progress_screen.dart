import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../application/challenge_providers.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_requests.dart';

class SubmitChallengeProgressScreen extends ConsumerStatefulWidget {
  const SubmitChallengeProgressScreen({required this.challengeId, super.key});

  final String challengeId;

  @override
  ConsumerState<SubmitChallengeProgressScreen> createState() =>
      _SubmitChallengeProgressScreenState();
}

class _SubmitChallengeProgressScreenState
    extends ConsumerState<SubmitChallengeProgressScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _progress = TextEditingController();
  final TextEditingController _note = TextEditingController();
  XFile? _proof;
  String? _selectedActivityId;
  bool _uploading = false;

  @override
  void dispose() {
    _progress.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Challenge?> value = ref.watch(
      challengeProvider(widget.challengeId),
    );
    final AsyncValue<void> action = ref.watch(
      challengeActionControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Add progress')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(error.toString())),
        data: (Challenge? challenge) {
          if (challenge == null) {
            return const Center(child: Text('Challenge unavailable.'));
          }
          final ChallengeRule rule = challenge.primaryRule;
          return AdaptivePageBody(
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: 'Verified submission',
                title: challenge.title,
                subtitle:
                    'Only submit progress you completed. ReeMove checks duplicates, timing, daily caps, linked activity ownership, and suspicious jumps.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _progress,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Progress (${rule.unit})',
                        helperText:
                            'Daily maximum: ${rule.maximumDailyProgress} ${rule.unit}',
                      ),
                      validator: (String? value) {
                        final double? parsed = double.tryParse(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a positive amount.';
                        }
                        if (parsed > rule.maximumDailyProgress) {
                          return 'This is above the daily verification cap.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (rule.verificationMethod ==
                            ChallengeVerificationMethod.automaticActivity ||
                        rule.verificationMethod ==
                            ChallengeVerificationMethod.activityAndProof)
                      _ActivityPicker(
                        challenge: challenge,
                        selectedActivityId: _selectedActivityId,
                        onChanged: (String? value) {
                          setState(() => _selectedActivityId = value);
                        },
                      ),
                    if (rule.verificationMethod ==
                            ChallengeVerificationMethod.photoProof ||
                        rule.verificationMethod ==
                            ChallengeVerificationMethod.activityAndProof ||
                        rule.verificationMethod ==
                            ChallengeVerificationMethod
                                .organizerReview) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _pickProof,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          _proof == null
                              ? 'Add proof photo'
                              : 'Replace proof photo',
                        ),
                      ),
                      if (_proof != null)
                        Text(_proof!.name, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _note,
                      maxLength: 300,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        helperText:
                            'Do not include private health or location details.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: action.isLoading || _uploading
                          ? null
                          : () => _submit(challenge),
                      icon: action.isLoading || _uploading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('Submit for verification'),
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickProof() async {
    final XFile? value = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (value != null) {
      setState(() => _proof = value);
    }
  }

  Future<void> _submit(Challenge challenge) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ChallengeRule rule = challenge.primaryRule;
    final bool proofRequired =
        rule.verificationMethod !=
        ChallengeVerificationMethod.automaticActivity;
    if (proofRequired && _proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add the required proof photo.')),
      );
      return;
    }
    String? proofPath;
    if (_proof != null) {
      setState(() => _uploading = true);
      final Result<String> upload = await ref
          .read(challengeActionControllerProvider.notifier)
          .uploadProof(challengeId: challenge.id, localPath: _proof!.path);
      proofPath = upload.when<String?>(
        success: (String value) => value,
        failure: (Failure failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
          return null;
        },
      );
      if (mounted) {
        setState(() => _uploading = false);
      }
      if (proofPath == null) {
        return;
      }
    }
    final bool success = await ref
        .read(challengeActionControllerProvider.notifier)
        .submit(
          SubmitChallengeProgressRequest(
            challengeId: challenge.id,
            progressDelta: double.parse(_progress.text),
            activityId: _selectedActivityId,
            proofStoragePath: proofPath,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress submitted for verification.')),
      );
      Navigator.of(context).pop();
    }
  }
}

class _ActivityPicker extends ConsumerWidget {
  const _ActivityPicker({
    required this.challenge,
    required this.selectedActivityId,
    required this.onChanged,
  });

  final Challenge challenge;
  final String? selectedActivityId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChallengeActivityOption>> value = ref.watch(
      eligibleChallengeActivitiesProvider(challenge.id),
    );
    return value.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Verified ReeMove activity',
          helperText: 'Finding activities completed during this challenge…',
        ),
        child: LinearProgressIndicator(),
      ),
      error: (Object error, StackTrace _) => InputDecorator(
        decoration: InputDecoration(
          labelText: 'Verified ReeMove activity',
          errorText: error.toString(),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => ref.invalidate(
              eligibleChallengeActivitiesProvider(challenge.id),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ),
      data: (List<ChallengeActivityOption> activities) {
        if (activities.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Verified ReeMove activity',
              errorText: 'No eligible activity is available yet.',
              helperText:
                  'Record and verify an activity for this sport during the challenge period, then return here.',
            ),
            child: Text('Your verified activities will appear here.'),
          );
        }
        final String? safeValue =
            activities.any(
              (ChallengeActivityOption item) => item.id == selectedActivityId,
            )
            ? selectedActivityId
            : null;
        return DropdownButtonFormField<String>(
          initialValue: safeValue,
          decoration: const InputDecoration(
            labelText: 'Verified ReeMove activity',
            helperText:
                'ReeMove checks ownership, sport, date, metric, and duplicate use.',
          ),
          items: activities
              .map(
                (ChallengeActivityOption item) => DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(
                    _activityLabel(context, item, challenge.primaryRule),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
          validator: (String? value) =>
              value == null ? 'Select one verified activity.' : null,
        );
      },
    );
  }

  static String _activityLabel(
    BuildContext context,
    ChallengeActivityOption activity,
    ChallengeRule rule,
  ) {
    final String date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(activity.occurredAt.toLocal());
    final String? metricKey = switch (rule.metric) {
      ChallengeMetric.distance => 'distanceKm',
      ChallengeMetric.duration => 'durationMinutes',
      ChallengeMetric.repetitions => 'repetitions',
      ChallengeMetric.volume => 'volumeKg',
      ChallengeMetric.points => 'matchPoints',
      ChallengeMetric.sessions || ChallengeMetric.attendance => null,
    };
    if (metricKey == null) {
      return '$date · Verified session';
    }
    final double? value = activity.metrics[metricKey];
    if (value == null) {
      return '$date · Verified activity';
    }
    final String formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$date · $formatted ${rule.unit}';
  }
}
