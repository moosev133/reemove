import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/entities/profile_relationship.dart';
import '../../domain/entities/user_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.profile,
    required this.isOwnProfile,
    super.key,
    this.relationship,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.secondaryLabel,
    this.onFollowers,
    this.onFollowing,
  });

  final UserProfile profile;
  final bool isOwnProfile;
  final ProfileRelationship? relationship;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final String? secondaryLabel;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Cover(profile: profile),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Transform.translate(
                    offset: const Offset(0, -38),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surface,
                            border: Border.all(color: colors.surface, width: 5),
                          ),
                          child: AppAvatar(
                            displayName: profile.displayName,
                            imageUrl: profile.avatarUrl,
                            radius: 48,
                          ),
                        ),
                        const Spacer(),
                        if (onPrimaryAction != null)
                          FilledButton(
                            onPressed: onPrimaryAction,
                            child: Text(_primaryLabel()),
                          ),
                        if (onSecondaryAction != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          OutlinedButton(
                            onPressed: onSecondaryAction,
                            child: Text(
                              secondaryLabel ??
                                  (isOwnProfile ? 'Share' : 'Message'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -24),
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            if (profile.isVerified) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.verified_rounded,
                                color: colors.primary,
                                semanticLabel:
                                    'Verified ${profile.profileLabel}',
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '@${profile.username} · ${profile.profileLabel}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        if (profile.professionalDetails.headline !=
                            null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            profile.professionalDetails.headline!,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                        if (profile.bio.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(profile.bio),
                        ],
                        if (profile.websiteUrl != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.link_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  profile.websiteUrl!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: <Widget>[
                            _ProfileStat(
                              value: profile.postsCount + profile.reelsCount,
                              label: 'Content',
                            ),
                            _ProfileStat(
                              value: profile.followersCount,
                              label: 'Followers',
                              onTap: onFollowers,
                            ),
                            _ProfileStat(
                              value: profile.followingCount,
                              label: 'Following',
                              onTap: onFollowing,
                            ),
                          ],
                        ),
                        if (profile.favoriteSportIds.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: profile.favoriteSportIds
                                .take(6)
                                .map(
                                  (String sport) => Chip(
                                    avatar: sport == profile.primarySportId
                                        ? const Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                          )
                                        : null,
                                    label: Text(_humanize(sport)),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _primaryLabel() {
    if (isOwnProfile) {
      return 'Edit profile';
    }
    return switch (relationship?.state) {
      FollowRelationshipState.following ||
      FollowRelationshipState.mutual => 'Following',
      FollowRelationshipState.requestSent => 'Requested',
      FollowRelationshipState.requestReceived => 'Respond',
      FollowRelationshipState.blocked => 'Blocked',
      FollowRelationshipState.blockedBy => 'Unavailable',
      _ => 'Follow',
    };
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 150,
      child: profile.coverUrl == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    colors.primaryContainer,
                    colors.secondaryContainer,
                    colors.tertiaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: profile.coverUrl!,
              fit: BoxFit.cover,
              placeholder: (BuildContext context, String url) =>
                  ColoredBox(color: colors.surfaceContainerHighest),
              errorWidget: (BuildContext context, String url, Object error) =>
                  ColoredBox(color: colors.surfaceContainerHighest),
            ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: <Widget>[
              Text(
                _compact(value),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _compact(int value) {
  if (value < 1000) {
    return '$value';
  }
  if (value < 1000000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '${(value / 1000000).toStringAsFixed(1)}M';
}

String _humanize(String value) => value
    .replaceAll(RegExp(r'[-_]'), ' ')
    .split(RegExp(r'\s+'))
    .where((String item) => item.isNotEmpty)
    .map((String item) => '${item[0].toUpperCase()}${item.substring(1)}')
    .join(' ');
