import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../feed/application/feed_providers.dart';
import '../../../feed/domain/entities/content_report.dart';
import '../../../feed/presentation/widgets/content_report_reason_sheet.dart';
import '../../../messages/application/messaging_providers.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_content_page.dart';
import '../../domain/entities/profile_relationship.dart';
import '../../domain/entities/profile_surface.dart';
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
    final AsyncValue<ProfileSurface> surfaceValue = ref.watch(
      profileSurfaceByUsernameProvider(widget.username),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        actions: <Widget>[
          surfaceValue.maybeWhen(
            data: (ProfileSurface surface) => surface.profile == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Profile actions',
                    onPressed: () => _showMore(surface.profile!),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: surfaceValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => AdaptivePageBody(
          slivers: <Widget>[
            AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Couldn’t load profile',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(
                profileSurfaceByUsernameProvider(widget.username),
              ),
            ),
          ],
        ),
        data: (ProfileSurface surface) {
          final UserProfile? profile = surface.profile;
          if (profile == null) {
            return AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: surface.access == ProfileAccessLevel.unavailable
                      ? Icons.block_outlined
                      : Icons.person_search_outlined,
                  title: surface.access == ProfileAccessLevel.unavailable
                      ? 'Profile unavailable'
                      : 'Profile not found',
                  message: surface.access == ProfileAccessLevel.unavailable
                      ? 'This profile is inactive or unavailable to you.'
                      : 'The username may have changed.',
                ),
              ],
            );
          }
          final ProfileRelationship relationship = surface.relationship;
          final bool isPreview = surface.isPreview;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileSurfaceByUsernameProvider(widget.username));
              await ref.read(
                profileSurfaceByUsernameProvider(widget.username).future,
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
                  onPrimaryAction: () => _primaryAction(profile, relationship),
                  secondaryLabel: _secondaryLabel(relationship),
                  onSecondaryAction: relationship.canMessage
                      ? () => context.go(
                          AppRoutes.newConversationFor(profile.username),
                        )
                      : relationship.canRequestMessage
                      ? () => unawaited(
                          _messageRequestAction(profile, relationship),
                        )
                      : null,
                  onFollowers: relationship.canViewFollowers
                      ? () => context.push(
                          AppRoutes.profileConnections(
                            profile.uid,
                            'followers',
                          ),
                        )
                      : null,
                  onFollowing: relationship.canViewFollowers
                      ? () => context.push(
                          AppRoutes.profileConnections(
                            profile.uid,
                            'following',
                          ),
                        )
                      : null,
                ),
                if (isPreview) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  const AppEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'This account is private',
                    message:
                        'Follow this profile to see their posts, reels, and follower lists.',
                  ),
                ] else ...<Widget>[
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
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _primaryAction(
    UserProfile profile,
    ProfileRelationship relationship,
  ) async {
    final controller = ref.read(profileActionControllerProvider.notifier);
    final FollowRelationshipState state = relationship.state;
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

  String? _secondaryLabel(ProfileRelationship relationship) {
    if (relationship.canMessage) {
      return 'Message';
    }
    if (!relationship.canRequestMessage) {
      return null;
    }
    return relationship.hasPendingMessageRequest
        ? 'Requested'
        : 'Request message';
  }

  Future<void> _messageRequestAction(
    UserProfile profile,
    ProfileRelationship relationship,
  ) async {
    final messaging = ref.read(messagingRepositoryProvider);
    if (relationship.hasPendingMessageRequest) {
      final Result<void> result = await messaging.cancelMessageRequest(
        profile.uid,
      );
      if (!mounted) {
        return;
      }
      result.when<void>(
        success: (_) {
          ref.invalidate(profileSurfaceByUsernameProvider(widget.username));
          ref.invalidate(profileRelationshipProvider(profile.uid));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message request cancelled.')),
          );
        },
        failure: (Failure failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
      );
      return;
    }

    final Result<String?> result = await messaging.createMessageRequest(
      profile.uid,
    );
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (String? conversationId) {
        ref.invalidate(profileSurfaceByUsernameProvider(widget.username));
        ref.invalidate(profileRelationshipProvider(profile.uid));
        if (conversationId != null && conversationId.isNotEmpty) {
          context.go(AppRoutes.conversation(conversationId));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message request sent.')),
        );
      },
      failure: (Failure failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
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
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _reportProfile(profile);
              },
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

  Future<void> _reportProfile(UserProfile profile) async {
    final ContentReportReason? reason = await showContentReportReasonSheet(
      context,
      title: 'Why are you reporting this profile?',
    );
    if (reason == null || !mounted) {
      return;
    }
    final Result<void> result = await ref
        .read(postInteractionRepositoryProvider)
        .report(
          ContentReportRequest(
            targetType: 'user',
            targetId: profile.uid,
            reason: reason,
          ),
        );
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for review.')),
        );
      },
      failure: (Failure failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
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
