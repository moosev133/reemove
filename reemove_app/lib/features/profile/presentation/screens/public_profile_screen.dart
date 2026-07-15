import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/user_profile.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile?> value = ref.watch(
      publicProfileByUsernameProvider(username),
    );
    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const AdaptivePageBody(
          slivers: <Widget>[
            AppEmptyState(
              icon: Icons.lock_person_outlined,
              title: 'Profile unavailable',
              message:
                  'This profile is private, inactive, or cannot be loaded right now.',
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
                  message:
                      'The username may have changed or the profile may no longer exist.',
                ),
              ],
            );
          }
          return AdaptivePageBody(
            maxWidth: 860,
            slivers: <Widget>[
              PremiumSurface(
                child: Column(
                  children: <Widget>[
                    AppAvatar(
                      displayName: profile.displayName,
                      imageUrl: profile.avatarUrl,
                      radius: 52,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                    Text(
                      '@${profile.username}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (profile.bio.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(profile.bio, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        _PublicStat(label: 'Posts', value: profile.postsCount),
                        _PublicStat(
                          label: 'Followers',
                          value: profile.followersCount,
                        ),
                        _PublicStat(
                          label: 'Following',
                          value: profile.followingCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppEmptyState(
                icon: Icons.grid_view_outlined,
                title: 'No public activity',
                message:
                    'Public posts and reels from this athlete will appear here.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PublicStat extends StatelessWidget {
  const _PublicStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
