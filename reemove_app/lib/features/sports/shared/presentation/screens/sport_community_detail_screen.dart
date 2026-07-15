import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_community.dart';

class SportCommunityDetailScreen extends ConsumerWidget {
  const SportCommunityDetailScreen({
    required this.sportId,
    required this.communityId,
    super.key,
  });

  final String sportId;
  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SportCommunity?> communityValue = ref.watch(
      sportCommunityProvider(communityId),
    );
    final AsyncValue<List<SportCommunityMember>> membersValue = ref.watch(
      sportCommunityMembersProvider(communityId),
    );
    final AsyncValue<SportCommunityMembershipStatus> membershipValue = ref
        .watch(sportCommunityMembershipProvider(communityId));
    final SportCommunityMembershipStatus currentMembership =
        membershipValue.value ?? SportCommunityMembershipStatus.none;
    final bool canManageRequests =
        currentMembership == SportCommunityMembershipStatus.owner ||
        currentMembership == SportCommunityMembershipStatus.administrator;
    final AsyncValue<List<SportCommunityMember>> requestsValue =
        canManageRequests
        ? ref.watch(sportCommunityJoinRequestsProvider(communityId))
        : const AsyncValue<List<SportCommunityMember>>.data(
            <SportCommunityMember>[],
          );
    final AsyncValue<void> action = ref.watch(
      sportsHubActionControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: communityValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(error.toString())),
        data: (SportCommunity? community) {
          if (community == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppEmptyState(
                  icon: Icons.group_off_outlined,
                  title: 'Community unavailable',
                  message:
                      'This community may have been removed or restricted.',
                ),
              ),
            );
          }
          final SportCommunityMembershipStatus membership = currentMembership;
          return AdaptivePageBody(
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: sportId.toUpperCase(),
                title: community.name,
                subtitle: community.description,
                trailing: AppAvatar(
                  displayName: community.name,
                  imageUrl: community.avatarUrl,
                  radius: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppStatusChip(
                    label: '${community.memberCount} members',
                    icon: Icons.groups_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (community.city.isNotEmpty)
                    AppStatusChip(
                      label: community.city,
                      icon: Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  if (community.pricingText case final String pricing)
                    AppStatusChip(
                      label: pricing,
                      icon: Icons.payments_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _MembershipButton(
                status: membership,
                isLoading: action.isLoading,
                isFull: community.isFull,
                joinPolicy: community.joinPolicy,
                onJoin: () async {
                  final bool ok = await ref
                      .read(sportsHubActionControllerProvider.notifier)
                      .joinCommunity(communityId);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          community.joinPolicy ==
                                  SportCommunityJoinPolicy.approvalRequired
                              ? 'Join request sent.'
                              : 'You joined ${community.name}.',
                        ),
                      ),
                    );
                  }
                },
                onLeave: () async {
                  final bool ok = await ref
                      .read(sportsHubActionControllerProvider.notifier)
                      .leaveCommunity(communityId);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You left the community.')),
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
              if (canManageRequests) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Join requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                requestsValue.when(
                  data: (List<SportCommunityMember> requests) =>
                      requests.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'No pending requests',
                          message: 'New approval requests will appear here.',
                        )
                      : PremiumSurface(
                          child: Column(
                            children: requests
                                .map((SportCommunityMember request) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: AppAvatar(
                                      displayName: request.displayName,
                                      imageUrl: request.avatarUrl,
                                    ),
                                    title: Text(request.displayName),
                                    subtitle: Text('@${request.username}'),
                                    trailing: Wrap(
                                      spacing: AppSpacing.xs,
                                      children: <Widget>[
                                        IconButton(
                                          tooltip: 'Reject request',
                                          onPressed: action.isLoading
                                              ? null
                                              : () => _respondToRequest(
                                                  context: context,
                                                  ref: ref,
                                                  userId: request.userId,
                                                  approve: false,
                                                ),
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                        IconButton.filledTonal(
                                          tooltip: 'Approve request',
                                          onPressed:
                                              action.isLoading ||
                                                  community.isFull
                                              ? null
                                              : () => _respondToRequest(
                                                  context: context,
                                                  ref: ref,
                                                  userId: request.userId,
                                                  approve: true,
                                                ),
                                          icon: const Icon(Icons.check_rounded),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (Object error, StackTrace _) => Text(error.toString()),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('Members', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              membersValue.when(
                data: (List<SportCommunityMember> members) => members.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No public members yet',
                        message: 'Approved members will appear here.',
                      )
                    : PremiumSurface(
                        child: Column(
                          children: members
                              .take(20)
                              .map((SportCommunityMember member) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: AppAvatar(
                                    displayName: member.displayName,
                                    imageUrl: member.avatarUrl,
                                  ),
                                  title: Text(member.displayName),
                                  subtitle: Text('@${member.username}'),
                                  trailing: Text(_roleLabel(member.status)),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (Object error, StackTrace _) => Text(error.toString()),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _respondToRequest({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required bool approve,
  }) async {
    final bool ok = await ref
        .read(sportsHubActionControllerProvider.notifier)
        .respondToCommunityJoinRequest(
          communityId: communityId,
          userId: userId,
          approve: approve,
        );
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Member approved.' : 'Request rejected.'),
      ),
    );
  }

  static String _roleLabel(SportCommunityMembershipStatus status) =>
      switch (status) {
        SportCommunityMembershipStatus.owner => 'Owner',
        SportCommunityMembershipStatus.administrator => 'Admin',
        SportCommunityMembershipStatus.pending => 'Pending',
        SportCommunityMembershipStatus.member => 'Member',
        SportCommunityMembershipStatus.none => '',
      };
}

class _MembershipButton extends StatelessWidget {
  const _MembershipButton({
    required this.status,
    required this.isLoading,
    required this.isFull,
    required this.joinPolicy,
    required this.onJoin,
    required this.onLeave,
  });

  final SportCommunityMembershipStatus status;
  final bool isLoading;
  final bool isFull;
  final SportCommunityJoinPolicy joinPolicy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (status == SportCommunityMembershipStatus.owner ||
        status == SportCommunityMembershipStatus.administrator) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: Text(
          status == SportCommunityMembershipStatus.owner
              ? 'You own this community'
              : 'You manage this community',
        ),
      );
    }
    if (status == SportCommunityMembershipStatus.member) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onLeave,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Leave community'),
      );
    }
    if (status == SportCommunityMembershipStatus.pending) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: const Text('Request pending'),
      );
    }
    final bool disabled =
        isLoading ||
        isFull ||
        joinPolicy == SportCommunityJoinPolicy.inviteOnly;
    return FilledButton.icon(
      onPressed: disabled ? null : onJoin,
      icon: const Icon(Icons.group_add_rounded),
      label: Text(
        isFull
            ? 'Community is full'
            : joinPolicy == SportCommunityJoinPolicy.inviteOnly
            ? 'Invite only'
            : joinPolicy == SportCommunityJoinPolicy.approvalRequired
            ? 'Request to join'
            : 'Join community',
      ),
    );
  }
}
