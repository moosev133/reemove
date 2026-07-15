import 'package:flutter/material.dart' hide Visibility;

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/sport_community.dart';

class SportCommunityCard extends StatelessWidget {
  const SportCommunityCard({
    required this.community,
    required this.onTap,
    super.key,
  });

  final SportCommunity community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(
            displayName: community.name,
            imageUrl: community.avatarUrl,
            radius: 30,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        community.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (community.isVerified)
                      Icon(
                        Icons.verified_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  community.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    AppStatusChip(
                      label: '${community.memberCount} members',
                      icon: Icons.groups_rounded,
                      color: scheme.primary,
                    ),
                    AppStatusChip(
                      label: _joinLabel(community.joinPolicy),
                      icon: Icons.login_rounded,
                      color: scheme.secondary,
                    ),
                    if (community.city.isNotEmpty)
                      AppStatusChip(
                        label: community.city,
                        icon: Icons.location_on_outlined,
                        color: scheme.tertiary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _joinLabel(SportCommunityJoinPolicy policy) => switch (policy) {
    SportCommunityJoinPolicy.open => 'Open to join',
    SportCommunityJoinPolicy.approvalRequired => 'Approval required',
    SportCommunityJoinPolicy.inviteOnly => 'Invite only',
  };
}
