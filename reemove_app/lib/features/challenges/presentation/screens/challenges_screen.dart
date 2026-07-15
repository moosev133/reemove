import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../application/challenge_providers.dart';
import '../../domain/entities/challenge.dart';
import '../widgets/challenge_card.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({this.sportId, super.key});

  final String? sportId;

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(challengeCatalogControllerProvider.notifier)
            .initialize(sportId: widget.sportId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChallengeCatalogState state = ref.watch(
      challengeCatalogControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Badges and history',
            onPressed: () => context.push(AppRoutes.challengeRewards),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createChallenge),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: ref
            .read(challengeCatalogControllerProvider.notifier)
            .refresh,
        child: AdaptivePageBody(
          restorationId: 'challenges_${widget.sportId ?? 'all'}',
          slivers: <Widget>[
            AppPageHeader(
              eyebrow: 'Move with purpose',
              title: widget.sportId == null
                  ? 'Safe goals. Verified progress.'
                  : '${_sportName(widget.sportId!)} challenges',
              subtitle:
                  'Join weekly, community, trainer, and AI-assisted challenges. Progress only counts after the required verification checks.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _SportFilter(selected: state.sportId),
            const SizedBox(height: AppSpacing.lg),
            if (state.errorMessage != null)
              AppErrorView(
                title: 'Challenges could not load',
                message: state.errorMessage!,
                actionLabel: 'Try again',
                onAction: () => unawaited(
                  ref
                      .read(challengeCatalogControllerProvider.notifier)
                      .refresh(),
                ),
              )
            else if (state.isLoading && state.items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (state.items.isEmpty)
              const AppEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No active challenges',
                message:
                    'Try another sport or check again when the next weekly set begins.',
              )
            else
              ...state.items.map(
                (Challenge challenge) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ChallengeCard(
                    challenge: challenge,
                    onTap: () => unawaited(
                      context.push(AppRoutes.challenge(challenge.id)),
                    ),
                  ),
                ),
              ),
            if (state.nextCursor != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: OutlinedButton(
                  onPressed: state.isLoadingMore
                      ? null
                      : ref
                            .read(challengeCatalogControllerProvider.notifier)
                            .loadMore,
                  child: state.isLoadingMore
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
              ),
            ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _SportFilter extends ConsumerWidget {
  const _SportFilter({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <String?>[null, 'football', 'gym', 'running']
          .map((String? id) {
            return ChoiceChip(
              label: Text(id == null ? 'All sports' : _sportName(id)),
              selected: id == selected,
              onSelected: (_) => ref
                  .read(challengeCatalogControllerProvider.notifier)
                  .setSport(id),
            );
          })
          .toList(growable: false),
    );
  }
}

String _sportName(String id) => switch (id) {
  'football' => 'Football',
  'gym' => 'Gym',
  'running' => 'Running',
  _ => id,
};
