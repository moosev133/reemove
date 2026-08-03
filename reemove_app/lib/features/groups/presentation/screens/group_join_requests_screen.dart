import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group_member.dart';

class GroupJoinRequestsScreen extends ConsumerWidget {
  const GroupJoinRequestsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupJoinRequest>> requestsValue = ref.watch(
      groupJoinRequestsProvider(groupId),
    );
    final AsyncValue<void> action = ref.watch(groupsActionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join requests')),
      body: requestsValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) {
          final bool denied = error is StateError &&
              error.message.contains('Owner or admin');
          return AppErrorView(
            title: denied ? 'Managers only' : 'Requests unavailable',
            message: denied
                ? 'Only the owner or admins can review join requests.'
                : error.toString(),
            actionLabel: denied ? null : 'Retry',
            onAction: denied
                ? null
                : () => ref.invalidate(groupJoinRequestsProvider(groupId)),
          );
        },
        data: (List<GroupJoinRequest> requests) {
          if (requests.isEmpty) {
            return AdaptivePageBody(
              slivers: const <Widget>[
                AppEmptyState(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'No pending requests',
                  message: 'New join requests will appear here for review.',
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupJoinRequestsProvider(groupId));
              await ref.read(groupJoinRequestsProvider(groupId).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final GroupJoinRequest request = requests[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () =>
                      context.push(AppRoutes.publicProfile(request.username)),
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
                        tooltip: 'Decline request',
                        onPressed: action.isLoading
                            ? null
                            : () => _respond(
                                context,
                                ref,
                                request,
                                approve: false,
                              ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Approve request',
                        onPressed: action.isLoading
                            ? null
                            : () => _respond(
                                context,
                                ref,
                                request,
                                approve: true,
                              ),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    GroupJoinRequest request,
    {required bool approve}
  ) async {
    final bool ok = await ref
        .read(groupsActionControllerProvider.notifier)
        .respondToJoinRequest(
          groupId: groupId,
          requesterId: request.requesterId,
          approve: approve,
        );
    if (!context.mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(approve ? 'Member approved.' : 'Request declined.')),
    );
  }
}
