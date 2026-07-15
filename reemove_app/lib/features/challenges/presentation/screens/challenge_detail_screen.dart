import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../application/challenge_providers.dart';
import '../../domain/entities/challenge.dart';
import '../widgets/challenge_leaderboard_panel.dart';
import '../widgets/challenge_progress_card.dart';
import '../widgets/challenge_safety_notice.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({required this.challengeId, super.key});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Challenge?> challengeValue = ref.watch(
      challengeProvider(challengeId),
    );
    final AsyncValue<ChallengeParticipation?> participationValue = ref.watch(
      challengeParticipationProvider(challengeId),
    );
    final AsyncValue<List<ChallengeLeaderboardEntry>> leaderboard = ref.watch(
      challengeLeaderboardProvider(challengeId),
    );
    final AsyncValue<void> action = ref.watch(
      challengeActionControllerProvider,
    );

    return challengeValue.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          title: 'Challenge unavailable',
          message: error.toString(),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(challengeProvider(challengeId)),
        ),
      ),
      data: (Challenge? challenge) {
        if (challenge == null) {
          return const Scaffold(
            body: AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Challenge unavailable',
              message: 'It may have ended or been removed.',
            ),
          );
        }
        final ChallengeParticipation? participation = participationValue.value;
        final String? viewerId = ref.watch(currentAuthUserProvider).value?.uid;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Challenge'),
            actions: <Widget>[
              if (viewerId == challenge.creatorId)
                IconButton(
                  tooltip: 'Review submissions',
                  onPressed: () => context.push(
                    AppRoutes.reviewChallengeSubmissions(challenge.id),
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                ),
              IconButton(
                tooltip: 'Share challenge',
                onPressed: () => _copyLink(context, challenge.id),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          body: AdaptivePageBody(
            restorationId: 'challenge_$challengeId',
            slivers: <Widget>[
              AppPageHeader(
                eyebrow:
                    '${challenge.source.name} · ${challenge.difficulty.name}',
                title: challenge.title,
                subtitle: challenge.description,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChallengeSummary(challenge: challenge),
              const SizedBox(height: AppSpacing.lg),
              ChallengeSafetyNotice(policy: challenge.safetyPolicy),
              const SizedBox(height: AppSpacing.lg),
              if (participation != null)
                ChallengeProgressCard(
                  challenge: challenge,
                  participation: participation,
                  onSubmit: () => context.push(
                    AppRoutes.submitChallengeProgress(challenge.id),
                  ),
                  onClaim:
                      challenge.badgeId != null ||
                          challenge.rewardIds.isNotEmpty
                      ? () async {
                          final bool claimed = await ref
                              .read(challengeActionControllerProvider.notifier)
                              .claim(challenge.id);
                          if (claimed && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Badge and eligible rewards claimed.',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  onReminderChanged: (bool enabled) => ref
                      .read(challengeActionControllerProvider.notifier)
                      .setReminder(challenge.id, enabled),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: challenge.isJoinable && !action.isLoading
                        ? () async {
                            final bool joined = await ref
                                .read(
                                  challengeActionControllerProvider.notifier,
                                )
                                .join(challenge.id);
                            if (joined && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Challenge joined.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Join challenge'),
                  ),
                ),
              if (participation?.status ==
                  ChallengeParticipationStatus.active) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: action.isLoading
                        ? null
                        : () => ref
                              .read(challengeActionControllerProvider.notifier)
                              .leave(challenge.id),
                    child: const Text('Leave challenge'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Verified leaderboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              leaderboard.when(
                data: (List<ChallengeLeaderboardEntry> entries) =>
                    ChallengeLeaderboardPanel(entries: entries),
                loading: () => const LinearProgressIndicator(),
                error: (Object error, StackTrace _) => Text(error.toString()),
              ),
              const SizedBox(height: AppSpacing.xl),
              _VerificationExplanation(challenge: challenge),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }

  static void _copyLink(BuildContext context, String challengeId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share link: https://links.reemove.app${AppRoutes.challengeAlias(challengeId)}',
        ),
      ),
    );
  }
}

class _ChallengeSummary extends StatelessWidget {
  const _ChallengeSummary({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final ChallengeRule rule = challenge.primaryRule;
    return PremiumSurface(
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          _SummaryItem(label: 'Goal', value: '${rule.target} ${rule.unit}'),
          _SummaryItem(
            label: 'Participants',
            value: '${challenge.participantCount}',
          ),
          _SummaryItem(
            label: 'Completed',
            value: '${challenge.completionCount}',
          ),
          _SummaryItem(label: 'Ends', value: _date(challenge.endsAt)),
          _SummaryItem(
            label: 'Verification',
            value: _verification(rule.verificationMethod),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _VerificationExplanation extends StatelessWidget {
  const _VerificationExplanation({required this.challenge});
  final Challenge challenge;
  @override
  Widget build(BuildContext context) {
    final ChallengeRule rule = challenge.primaryRule;
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'How progress is verified',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(switch (rule.verificationMethod) {
            ChallengeVerificationMethod.automaticActivity =>
              'Link an eligible ReeMove activity. Server checks the activity owner, sport, timestamp, metric, and duplication.',
            ChallengeVerificationMethod.activityAndProof =>
              'Link an eligible activity and add supporting proof. Flagged entries wait for review.',
            ChallengeVerificationMethod.photoProof =>
              'Upload a recent photo. Location and private metadata are not published.',
            ChallengeVerificationMethod.organizerReview =>
              'The challenge organizer reviews each entry before it affects rankings.',
          }),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Daily verified progress is capped at ${rule.maximumDailyProgress} ${rule.unit} to reduce mistakes and abuse.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _verification(ChallengeVerificationMethod method) => switch (method) {
  ChallengeVerificationMethod.automaticActivity => 'Activity',
  ChallengeVerificationMethod.activityAndProof => 'Activity + proof',
  ChallengeVerificationMethod.photoProof => 'Photo proof',
  ChallengeVerificationMethod.organizerReview => 'Organizer review',
};

String _date(DateTime value) =>
    '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year}';
