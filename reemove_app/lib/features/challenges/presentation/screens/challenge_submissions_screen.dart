import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/challenge_providers.dart';
import '../../domain/entities/challenge.dart';

class ChallengeSubmissionsScreen extends ConsumerWidget {
  const ChallengeSubmissionsScreen({required this.challengeId, super.key});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChallengeSubmission>> value = ref.watch(
      challengeSubmissionsProvider(challengeId),
    );
    final AsyncValue<void> action = ref.watch(
      challengeActionControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Review submissions')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Organizer review',
            title: 'Verify progress fairly',
            subtitle:
                'Review proof only for the challenge goal. Do not infer health, identity, or private location details from an upload.',
          ),
          const SizedBox(height: AppSpacing.lg),
          value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace _) => AppErrorView(
              title: 'Submissions could not load',
              message: error.toString(),
              actionLabel: 'Try again',
              onAction: () =>
                  ref.invalidate(challengeSubmissionsProvider(challengeId)),
            ),
            data: (List<ChallengeSubmission> submissions) => submissions.isEmpty
                ? const AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No submissions waiting',
                    message:
                        'Pending and flagged entries will appear here for review.',
                  )
                : Column(
                    children: submissions
                        .map((ChallengeSubmission submission) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: PremiumSurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          submission.avatarUrl == null
                                          ? null
                                          : NetworkImage(submission.avatarUrl!),
                                      child: submission.avatarUrl == null
                                          ? const Icon(
                                              Icons.person_outline_rounded,
                                            )
                                          : null,
                                    ),
                                    title: Text(submission.displayName),
                                    subtitle: Text(
                                      submission.username.isEmpty
                                          ? submission.userId
                                          : '@${submission.username}',
                                    ),
                                    trailing: Chip(
                                      label: Text(submission.status.name),
                                    ),
                                  ),
                                  Text(
                                    'Submitted ${_format(submission.progressDelta)} units',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  if (submission.note != null &&
                                      submission.note!.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(submission.note!),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: <Widget>[
                                      Chip(
                                        avatar: Icon(
                                          submission.riskScore >= 70
                                              ? Icons.warning_amber_rounded
                                              : Icons.shield_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Risk ${submission.riskScore.toStringAsFixed(0)}',
                                        ),
                                      ),
                                      ...submission.riskReasons.map(
                                        (String reason) => Chip(
                                          label: Text(
                                            reason.replaceAll('_', ' '),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  if (submission.proofStoragePath != null)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showProof(context, ref, submission),
                                      icon: const Icon(Icons.image_outlined),
                                      label: const Text(
                                        'View proof for 5 minutes',
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: action.isLoading
                                              ? null
                                              : () => _review(
                                                  context,
                                                  ref,
                                                  submission,
                                                  approve: false,
                                                ),
                                          icon: const Icon(Icons.close_rounded),
                                          label: const Text('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: action.isLoading
                                              ? null
                                              : () => _review(
                                                  context,
                                                  ref,
                                                  submission,
                                                  approve: true,
                                                ),
                                          icon: const Icon(
                                            Icons.verified_rounded,
                                          ),
                                          label: const Text('Approve'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    ChallengeSubmission submission, {
    required bool approve,
  }) async {
    final bool completed = await ref
        .read(challengeActionControllerProvider.notifier)
        .reviewSubmission(
          challengeId: challengeId,
          submissionId: submission.id,
          approve: approve,
        );
    if (!context.mounted || !completed) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approve ? 'Submission approved.' : 'Submission rejected.',
        ),
      ),
    );
  }

  Future<void> _showProof(
    BuildContext context,
    WidgetRef ref,
    ChallengeSubmission submission,
  ) async {
    final Result<String> result = await ref
        .read(challengeActionControllerProvider.notifier)
        .createProofReviewUrl(
          challengeId: challengeId,
          submissionId: submission.id,
        );
    if (!context.mounted) {
      return;
    }
    result.when<void>(
      success: (String url) {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (BuildContext dialogContext) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 760,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Submission proof',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Flexible(
                        child: InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const AppEmptyState(
                                  icon: Icons.broken_image_outlined,
                                  title: 'Proof could not load',
                                  message:
                                      'The temporary link may have expired.',
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'This temporary link expires after five minutes.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      failure: (Failure failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }
}

String _format(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
