import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../domain/entities/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin<ProfileScreen> {
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
            tooltip: 'Account and security',
            onPressed: () => context.push(AppRoutes.accountSecurity),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: profileValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => AdaptivePageBody(
          slivers: const <Widget>[
            AppEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message:
                  'Your profile could not be loaded. Check your connection and try again.',
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
          return AdaptivePageBody(
            maxWidth: 940,
            slivers: <Widget>[
              _ProfileHero(profile: profile),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.publicProfile(profile.usernameNormalized),
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View public profile'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.accountSecurity),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Account settings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppEmptyState(
                icon: Icons.grid_view_rounded,
                title: 'Your activity grid is empty',
                message:
                    'Posts, reels, activity, and saved collections will be organized here.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppAvatar(
                displayName: profile.displayName,
                imageUrl: profile.avatarUrl,
                radius: 46,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            profile.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        if (profile.isVerified) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.verified_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '@${profile.username}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (profile.bio.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(profile.bio),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              _Stat(label: 'Posts', value: profile.postsCount),
              _Stat(label: 'Followers', value: profile.followersCount),
              _Stat(label: 'Following', value: profile.followingCount),
            ],
          ),
          if (profile.favoriteSportIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: profile.favoriteSportIds
                    .map((String sport) => Chip(label: Text(_humanize(sport))))
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _humanize(String value) {
  return value
      .replaceAll(RegExp(r'[-_]'), ' ')
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
