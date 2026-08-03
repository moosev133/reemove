import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_membership.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.avatarUrl,
    super.key,
  });

  factory GroupCard.fromGroup({
    required Group group,
    required VoidCallback onTap,
    Key? key,
  }) {
    return GroupCard(
      key: key,
      name: group.name,
      subtitle:
          '${group.category} · ${group.privacy.name} · ${group.memberCount} members',
      avatarUrl: group.avatarUrl,
      onTap: onTap,
    );
  }

  factory GroupCard.fromMembership({
    required MyGroupMembership membership,
    required VoidCallback onTap,
    Key? key,
  }) {
    return GroupCard(
      key: key,
      name: membership.snapshot.name,
      subtitle:
          '${membership.snapshot.category} · ${membership.role.name} · ${membership.snapshot.memberCount} members',
      avatarUrl: membership.snapshot.avatarUrl,
      onTap: onTap,
    );
  }

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
