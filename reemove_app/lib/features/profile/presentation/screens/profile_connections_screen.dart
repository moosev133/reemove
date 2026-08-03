import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_connection.dart';
import '../../domain/entities/user_profile.dart';

class ProfileConnectionsScreen extends ConsumerStatefulWidget {
  const ProfileConnectionsScreen({
    required this.profileId,
    required this.type,
    super.key,
  });

  final String profileId;
  final ProfileConnectionType type;

  @override
  ConsumerState<ProfileConnectionsScreen> createState() =>
      _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState
    extends ConsumerState<ProfileConnectionsScreen> {
  ProfileConnectionPage? _page;
  bool _loadingMore = false;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final ProfileConnectionsQuery query = ProfileConnectionsQuery(
      profileId: widget.profileId,
      type: widget.type,
    );
    final AsyncValue<ProfileConnectionPage> value = ref.watch(
      profileConnectionsProvider(query),
    );
    final AuthUser? viewer = ref.watch(currentAuthUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(_title(widget.type))),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) {
          if (error is ProfileConnectionsRestricted) {
            return AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'This list is hidden',
                  message:
                      error.message ??
                      'The profile owner limited who can view this list.',
                ),
              ],
            );
          }
          return AdaptivePageBody(
            slivers: <Widget>[
              AppEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Connections unavailable',
                message: '$error',
                actionLabel: 'Try again',
                onAction: () =>
                    ref.invalidate(profileConnectionsProvider(query)),
              ),
            ],
          );
        },
        data: (ProfileConnectionPage initial) {
          _page ??= initial;
          final ProfileConnectionPage page = _page!;
          if (page.items.isEmpty) {
            return AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: _emptyIcon(widget.type),
                  title: _emptyTitle(widget.type),
                  message: _emptyMessage(widget.type),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _page = null;
                _failure = null;
              });
              ref.invalidate(profileConnectionsProvider(query));
              await ref.read(profileConnectionsProvider(query).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: page.items.length + (page.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                if (index == page.items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: _loadMore,
                              child: const Text('Load more'),
                            ),
                    ),
                  );
                }
                final UserProfile profile = page.items[index];
                return _ConnectionTile(
                  profile: profile,
                  trailing: _trailing(
                    context,
                    profile,
                    viewer?.uid == widget.profileId,
                  ),
                  onTap: () => context.push(
                    AppRoutes.publicProfile(profile.usernameNormalized),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _failure == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  _failure!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
    );
  }

  Widget? _trailing(BuildContext context, UserProfile profile, bool isOwner) {
    if (!isOwner) {
      return null;
    }
    return switch (widget.type) {
      ProfileConnectionType.requests => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Decline request',
            onPressed: () => _respond(profile, accept: false),
            icon: const Icon(Icons.close_rounded),
          ),
          FilledButton(
            onPressed: () => _respond(profile, accept: true),
            child: const Text('Accept'),
          ),
        ],
      ),
      ProfileConnectionType.followers => IconButton(
        tooltip: 'Remove follower',
        onPressed: () => _removeFollower(profile),
        icon: const Icon(Icons.person_remove_outlined),
      ),
      ProfileConnectionType.following => TextButton(
        onPressed: () => _unfollow(profile),
        child: const Text('Unfollow'),
      ),
      ProfileConnectionType.sentRequests => TextButton(
        onPressed: () => _cancelSentRequest(profile),
        child: const Text('Cancel'),
      ),
    };
  }

  Future<void> _cancelSentRequest(UserProfile profile) async {
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .cancelRequest(profile.uid);
    if (!mounted) {
      return;
    }
    if (success) {
      _removeLocally(profile.uid);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follow request canceled.')));
    } else {
      _showActionFailure();
    }
  }

  Future<void> _respond(UserProfile profile, {required bool accept}) async {
    final bool success = accept
        ? await ref
              .read(profileActionControllerProvider.notifier)
              .acceptRequest(profile.uid)
        : await ref
              .read(profileActionControllerProvider.notifier)
              .declineRequest(profile.uid);
    if (!mounted) {
      return;
    }
    if (success) {
      _removeLocally(profile.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Follow request accepted.' : 'Request declined.',
          ),
        ),
      );
    } else {
      _showActionFailure();
    }
  }

  Future<void> _removeFollower(UserProfile profile) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Remove ${profile.displayName}?'),
            content: const Text(
              'They will stop following you. They are not notified.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .removeFollower(profile.uid);
    if (!mounted) {
      return;
    }
    if (success) {
      _removeLocally(profile.uid);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follower removed.')));
    } else {
      _showActionFailure();
    }
  }

  Future<void> _unfollow(UserProfile profile) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Unfollow ${profile.displayName}?'),
            content: const Text(
              'Their posts will leave your feed. They are not notified.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Unfollow'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .unfollow(profile.uid);
    if (!mounted) {
      return;
    }
    if (success) {
      _removeLocally(profile.uid);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unfollowed.')));
    } else {
      _showActionFailure();
    }
  }

  void _removeLocally(String uid) {
    final ProfileConnectionPage? page = _page;
    if (page == null) {
      return;
    }
    setState(() {
      _page = ProfileConnectionPage(
        items: page.items
            .where((UserProfile profile) => profile.uid != uid)
            .toList(growable: false),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    });
  }

  Future<void> _loadMore() async {
    final ProfileConnectionPage? current = _page;
    if (current == null || current.nextCursor == null || _loadingMore) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _failure = null;
    });
    final Result<ProfileConnectionPage> result = await ref
        .read(profileSocialRepositoryProvider)
        .listConnections(
          profileId: widget.profileId,
          type: widget.type,
          cursor: current.nextCursor,
        );
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (ProfileConnectionPage next) {
        final Map<String, UserProfile> merged = <String, UserProfile>{
          for (final UserProfile profile in current.items) profile.uid: profile,
          for (final UserProfile profile in next.items) profile.uid: profile,
        };
        setState(() {
          _page = ProfileConnectionPage(
            items: merged.values.toList(growable: false),
            hasMore: next.hasMore,
            nextCursor: next.nextCursor,
          );
          _loadingMore = false;
        });
      },
      failure: (Failure failure) {
        setState(() {
          _loadingMore = false;
          _failure = failure.message;
        });
      },
    );
  }

  void _showActionFailure() {
    final Object? error = ref.read(profileActionControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'The action failed.')),
    );
  }

  static String _title(ProfileConnectionType type) => switch (type) {
    ProfileConnectionType.followers => 'Followers',
    ProfileConnectionType.following => 'Following',
    ProfileConnectionType.requests => 'Follow requests',
    ProfileConnectionType.sentRequests => 'Sent requests',
  };

  static IconData _emptyIcon(ProfileConnectionType type) => switch (type) {
    ProfileConnectionType.followers => Icons.people_outline_rounded,
    ProfileConnectionType.following => Icons.person_search_outlined,
    ProfileConnectionType.requests => Icons.mark_email_read_outlined,
    ProfileConnectionType.sentRequests => Icons.send_outlined,
  };

  static String _emptyTitle(ProfileConnectionType type) => switch (type) {
    ProfileConnectionType.followers => 'No followers yet',
    ProfileConnectionType.following => 'Not following anyone yet',
    ProfileConnectionType.requests => 'No pending requests',
    ProfileConnectionType.sentRequests => 'No sent requests',
  };

  static String _emptyMessage(ProfileConnectionType type) => switch (type) {
    ProfileConnectionType.followers =>
      'People who follow this profile will appear here.',
    ProfileConnectionType.following =>
      'Profiles followed by this account will appear here.',
    ProfileConnectionType.requests =>
      'New follow requests will be available here for review.',
    ProfileConnectionType.sentRequests =>
      'Profiles you have requested to follow will appear here.',
  };
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.profile,
    required this.onTap,
    this.trailing,
  });

  final UserProfile profile;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Keep profile navigation and trailing actions as separate hit targets so
    // Unfollow / Remove do not merge into the row's navigation semantics.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    AppAvatar(
                      displayName: profile.displayName,
                      imageUrl: profile.avatarUrl,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              if (profile.isVerified) ...<Widget>[
                                const SizedBox(width: AppSpacing.xxs),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 17,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '@${profile.username} · ${profile.profileLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) ?trailing,
        ],
      ),
    );
  }
}
