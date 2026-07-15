import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_section_header.dart';
import '../../../../../core/widgets/premium_surface.dart';

class SportHubScreen extends StatelessWidget {
  const SportHubScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context) {
    final _SportPresentation presentation = _presentationFor(sportId);
    return Scaffold(
      appBar: AppBar(title: Text(presentation.title)),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: 'Sport hub',
            title: presentation.title,
            subtitle: presentation.subtitle,
            trailing: Icon(
              presentation.icon,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(
            title: 'Explore the hub',
            subtitle:
                'Places, people, events, challenges, and expertise in one hub.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: const <Widget>[
              _HubTile(icon: Icons.place_outlined, label: 'Nearby places'),
              _HubTile(icon: Icons.groups_outlined, label: 'Teams & groups'),
              _HubTile(icon: Icons.event_outlined, label: 'Events'),
              _HubTile(icon: Icons.emoji_events_outlined, label: 'Challenges'),
              _HubTile(icon: Icons.leaderboard_outlined, label: 'Leaderboards'),
              _HubTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Trainers',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: presentation.icon,
            title: 'No ${presentation.title.toLowerCase()} activity yet',
            message:
                'Nearby places, sessions, communities, and ranked activity will appear here as they become available to your account.',
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: PremiumSurface(
        child: Row(
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportPresentation {
  const _SportPresentation({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

_SportPresentation _presentationFor(String sportId) => switch (sportId) {
  'football' => const _SportPresentation(
    title: 'Football',
    subtitle:
        'Find matches, pitches, teams, coaches, and football communities around you.',
    icon: Icons.sports_soccer_rounded,
  ),
  'gym' => const _SportPresentation(
    title: 'Gym',
    subtitle:
        'Connect with gyms, trainers, workout partners, and strength communities.',
    icon: Icons.fitness_center_rounded,
  ),
  'running' => const _SportPresentation(
    title: 'Running',
    subtitle:
        'Explore routes, clubs, sessions, races, challenges, and local runners.',
    icon: Icons.directions_run_rounded,
  ),
  _ => _SportPresentation(
    title: _humanize(sportId),
    subtitle:
        'Explore places, people, events, and communities for ${_humanize(sportId)}.',
    icon: Icons.sports_rounded,
  ),
};

String _humanize(String value) {
  final String clean = value.replaceAll(RegExp(r'[-_]'), ' ').trim();
  if (clean.isEmpty) {
    return 'Sport';
  }
  return clean
      .split(RegExp(r'\s+'))
      .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
