import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_content_page.dart';
import '../../domain/entities/profile_relationship.dart';
import '../../domain/entities/user_profile.dart';
import '../widgets/profile_content_panel.dart';
import '../widgets/profile_header.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  ProfileContentFilter _filter = ProfileContentFilter.posts;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile?> profileValue = ref.watch(
      publicProfileByUsernameProvider(widget.username),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        actions: <Widget>[
          profileValue.maybeWhen(
            data: (UserProfile? profile) => profile == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Profile actions',
                    onPressed: () => _showMore(profile),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profileValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const AdaptivePageBody(
          slivers: <Widget>[
            AppEmptyState(
              icon: Icons.lock_person_outlined,
              title: 'Profile unavailable',
              message: 'This profile is private, inactive, or unavailable.',
            ),
          ],
        ),
        data: (UserProfile? profile) {
          if (profile == null) {
            return const AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Profile not found',
                  message: 'The username may have changed.',
                ),
              ],
            );
          }
          final AsyncValue<ProfileRelationship> relationshipValue = ref.watch(
            profileRelationshipProvider(profile.uid),
          );
          final ProfileRelationship? relationship = relationshipValue.value;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicProfileByUsernameProvider(widget.username));
              ref.invalidate(profileRelationshipProvider(profile.uid));
              await ref.read(
                publicProfileByUsernameProvider(widget.username).future,
              );
            },
            child: AdaptivePageBody(
              maxWidth: 980,
              restorationId: 'public_profile_${profile.uid}',
              slivers: <Widget>[
                ProfileHeader(
                  profile: profile,
                  isOwnProfile: false,
                  relationship: relationship,
                  onPrimaryAction: relationshipValue.isLoading
                      ? null
                      : () => _primaryAction(profile, relationship),
                  onSecondaryAction: relationship?.canMessage == true
                      ? () => context.go(
                          AppRoutes.newConversationFor(profile.username),
                        )
                      : null,
                  onFollowers: relationship?.canViewFollowers == true
                      ? () => context.push(
                          AppRoutes.profileConnections(
                            profile.uid,
                            'followers',
                          ),
                        )
                      : null,
                  onFollowing: relationship?.canViewFollowers == true
                      ? () => context.push(
                          AppRoutes.profileConnections(
                            profile.uid,
                            'following',
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<ProfileContentFilter>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<ProfileContentFilter>>[
                    ButtonSegment<ProfileContentFilter>(
                      value: ProfileContentFilter.posts,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('Posts'),
                    ),
                    ButtonSegment<ProfileContentFilter>(
                      value: ProfileContentFilter.reels,
                      icon: Icon(Icons.smart_display_outlined),
                      label: Text('Reels'),
                    ),
                  ],
                  selected: <ProfileContentFilter>{_filter},
                  onSelectionChanged: (Set<ProfileContentFilter> value) {
                    setState(() => _filter = value.first);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ProfileContentPanel(
                  profileId: profile.uid,
                  filter: _filter,
                  onOpen: (String postId) =>
                      context.push(AppRoutes.homePost(postId)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _primaryAction(
    UserProfile profile,
    ProfileRelationship? relationship,
  ) async {
    final controller = ref.read(profileActionControllerProvider.notifier);
    final FollowRelationshipState state =
        relationship?.state ?? FollowRelationshipState.none;
    bool success;
    switch (state) {
      case FollowRelationshipState.none:
      case FollowRelationshipState.followedBy:
        success = await controller.follow(profile.uid);
        break;
      case FollowRelationshipState.following:
      case FollowRelationshipState.mutual:
        final bool confirmed = await _confirm(
          title: 'Unfollow ${profile.displayName}?',
          action: 'Unfollow',
        );
        if (!confirmed) {
          return;
        }
        success = await controller.unfollow(profile.uid);
        break;
      case FollowRelationshipState.requestSent:
        success = await controller.cancelRequest(profile.uid);
        break;
      case FollowRelationshipState.requestReceived:
        await _respondToRequest(profile);
        return;
      case FollowRelationshipState.blocked:
        success = await controller.unblock(profile.uid);
        break;
      case FollowRelationshipState.blockedBy:
      case FollowRelationshipState.self:
        return;
    }
    if (!mounted) {
      return;
    }
    final AsyncValue<void> action = ref.read(profileActionControllerProvider);
    if (!success && action.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${action.error}')));
    }
  }

  Future<void> _respondToRequest(UserProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '${profile.displayName} wants to follow you',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(profileActionControllerProvider.notifier)
                      .acceptRequest(profile.uid);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(profileActionControllerProvider.notifier)
                      .declineRequest(profile.uid);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Decline'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMore(UserProfile profile) async {
    final BuildContext pageContext = context;
    await showModalBottomSheet<void>(
      context: pageContext,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report profile'),
              subtitle: const Text('Send this profile to the safety team.'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            ListTile(
              leading: Icon(
                Icons.block_rounded,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: const Text('Block profile'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (await _confirm(
                  title: 'Block ${profile.displayName}?',
                  action: 'Block',
                )) {
                  await ref
                      .read(profileActionControllerProvider.notifier)
                      .block(profile.uid);
                  if (!pageContext.mounted) {
                    return;
                  }
                  pageContext.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm({required String title, required String action}) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(title),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }
}
