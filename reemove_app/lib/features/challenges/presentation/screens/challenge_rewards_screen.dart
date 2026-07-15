import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/challenge_providers.dart';
import '../../domain/entities/challenge.dart';

class ChallengeRewardsScreen extends ConsumerWidget {
  const ChallengeRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EarnedChallengeBadge>> badges = ref.watch(
      myChallengeBadgesProvider,
    );
    final AsyncValue<List<Challenge>> history = ref.watch(
      myChallengeHistoryProvider,
    );
    final AsyncValue<List<ChallengeRewardClaim>> rewards = ref.watch(
      myChallengeRewardClaimsProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Badges & challenge history')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Your achievements',
            title: 'Progress worth remembering',
            subtitle:
                'Badges are awarded only after verified completion. Sponsored rewards may have separate eligibility and expiry rules.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Earned badges', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          badges.when(
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace _) => Text(error.toString()),
            data: (List<EarnedChallengeBadge> items) => items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No badges yet',
                    message:
                        'Complete a verified challenge to earn your first badge.',
                  )
                : Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: items
                        .map((EarnedChallengeBadge item) {
                          return SizedBox(
                            width: 220,
                            child: PremiumSurface(
                              child: Column(
                                children: <Widget>[
                                  const CircleAvatar(
                                    radius: 30,
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    item.badge.name,
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    item.badge.description,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Chip(label: Text(item.badge.rarity)),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Claimed rewards',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          rewards.when(
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace _) => Text(error.toString()),
            data: (List<ChallengeRewardClaim> items) => items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.redeem_outlined,
                    title: 'No claimed rewards',
                    message:
                        'Eligible sponsor rewards appear here after verified completion.',
                  )
                : Column(
                    children: items
                        .map((ChallengeRewardClaim item) {
                          return PremiumSurface(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.redeem_rounded),
                              ),
                              title: Text(item.reward.title),
                              subtitle: Text(
                                '${item.reward.valueText} · ${item.reward.sponsorName ?? 'ReeMove'}',
                              ),
                              trailing: Text(item.status),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Challenge history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace _) => Text(error.toString()),
            data: (List<Challenge> items) => items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No challenge history',
                    message: 'Challenges you join will appear here.',
                  )
                : Column(
                    children: items
                        .map((Challenge item) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.flag_rounded),
                            ),
                            title: Text(item.title),
                            subtitle: Text(
                              '${item.sportId} · ${item.status.name}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                context.push(AppRoutes.challenge(item.id)),
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
}
