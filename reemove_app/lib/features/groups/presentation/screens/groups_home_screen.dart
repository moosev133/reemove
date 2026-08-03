import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_membership.dart';
import '../widgets/group_card.dart';

class GroupsHomeScreen extends ConsumerWidget {
  const GroupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MyGroupMembership>> mine = ref.watch(myGroupsProvider);
    final AsyncValue<List<Group>> discover = ref.watch(
      discoverableGroupsProvider(null),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Invitations',
            onPressed: () => context.push(AppRoutes.groupInvitations),
            icon: const Icon(Icons.mail_outline_rounded),
          ),
          IconButton(
            tooltip: 'Create group',
            onPressed: () => context.push(AppRoutes.createGroup),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Train together',
            title: 'Groups',
            subtitle:
                'Discover public clubs or manage the groups you already belong to.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('My groups', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          mine.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => AppErrorView(
              title: 'Could not load your groups',
              message: error is Failure ? error.message : '$error',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(myGroupsProvider),
            ),
            data: (List<MyGroupMembership> groups) {
              if (groups.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No groups yet',
                  message: 'Create a group or join one from discovery.',
                );
              }
              return Column(
                children: groups
                    .map(
                      (MyGroupMembership membership) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GroupCard.fromMembership(
                          membership: membership,
                          onTap: () =>
                              context.push(AppRoutes.group(membership.groupId)),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Discover', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          discover.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => AppErrorView(
              title: 'Could not load groups',
              message: error is Failure ? error.message : '$error',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(discoverableGroupsProvider(null)),
            ),
            data: (List<Group> groups) {
              if (groups.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.travel_explore_outlined,
                  title: 'Nothing to discover',
                  message: 'Public groups will appear here when available.',
                );
              }
              return Column(
                children: groups
                    .map(
                      (Group group) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GroupCard.fromGroup(
                          group: group,
                          onTap: () =>
                              context.push(AppRoutes.group(group.groupId)),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumSurface(
            onTap: () => context.push(AppRoutes.createGroup),
            child: const Row(
              children: <Widget>[
                Icon(Icons.add_circle_outline_rounded),
                SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Create a new group')),
                Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
