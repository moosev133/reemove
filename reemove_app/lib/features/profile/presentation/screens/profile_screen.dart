import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../domain/entities/profile_content_page.dart';
import '../../domain/entities/user_profile.dart';
import '../widgets/profile_content_panel.dart';
import '../widgets/profile_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin<ProfileScreen> {
  ProfileContentFilter _filter = ProfileContentFilter.posts;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AsyncValue<UserProfile?> profileValue = ref.watch(
      currentUserProfileProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'My marketplace listings',
            onPressed: () => context.push(AppRoutes.myMarketplaceListings),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Profile settings',
            onPressed: () => context.push(AppRoutes.profileSettings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: profileValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const AdaptivePageBody(
          slivers: <Widget>[
            AppEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message: 'Your profile could not be loaded. Try again shortly.',
            ),
          ],
        ),
        data: (UserProfile? profile) {
          if (profile == null) {
            return const AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: Icons.person_add_alt_outlined,
                  title: 'Profile setup required',
                  message:
                      'Complete account setup before opening your profile.',
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProfileProvider);
              await ref.read(currentUserProfileProvider.future);
            },
            child: AdaptivePageBody(
              maxWidth: 980,
              restorationId: 'own_profile_scroll',
              slivers: <Widget>[
                ProfileHeader(
                  profile: profile,
                  isOwnProfile: true,
                  onPrimaryAction: () => context.push(AppRoutes.editProfile),
                  onSecondaryAction: () => _shareProfile(profile),
                  onFollowers: () => context.push(
                    AppRoutes.profileConnections(profile.uid, 'followers'),
                  ),
                  onFollowing: () => context.push(
                    AppRoutes.profileConnections(profile.uid, 'following'),
                  ),
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
                    ButtonSegment<ProfileContentFilter>(
                      value: ProfileContentFilter.saved,
                      icon: Icon(Icons.bookmark_border_rounded),
                      label: Text('Saved'),
                    ),
                    ButtonSegment<ProfileContentFilter>(
                      value: ProfileContentFilter.reposted,
                      icon: Icon(Icons.repeat_rounded),
                      label: Text('Reposts'),
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

  Future<void> _shareProfile(UserProfile profile) async {
    final String value =
        'https://reemove.app${AppRoutes.profileAlias(profile.usernameNormalized)}';
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile link copied.')));
  }
}
