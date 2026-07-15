enum SportHubFeature {
  places,
  communities,
  events,
  challenges,
  leaderboards,
  trainers,
  pricing,
  routes,
}

class SportModuleConfig {
  const SportModuleConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.communityLabel,
    required this.eventLabel,
    required this.placeLabel,
    required this.leaderboardMetric,
    required this.features,
  });

  final String id;
  final String title;
  final String subtitle;
  final String communityLabel;
  final String eventLabel;
  final String placeLabel;
  final String leaderboardMetric;
  final Set<SportHubFeature> features;
}

abstract final class SportModuleRegistry {
  static const SportModuleConfig football = SportModuleConfig(
    id: 'football',
    title: 'Football',
    subtitle:
        'Matches, pitches, teams, coaches, and local football communities.',
    communityLabel: 'Teams & groups',
    eventLabel: 'Matches & training',
    placeLabel: 'Pitches & facilities',
    leaderboardMetric: 'Goals & match points',
    features: <SportHubFeature>{
      SportHubFeature.places,
      SportHubFeature.communities,
      SportHubFeature.events,
      SportHubFeature.challenges,
      SportHubFeature.leaderboards,
      SportHubFeature.trainers,
      SportHubFeature.pricing,
    },
  );

  static const SportModuleConfig gym = SportModuleConfig(
    id: 'gym',
    title: 'Gym',
    subtitle: 'Gyms, classes, workout groups, strength rankings, and trainers.',
    communityLabel: 'Workout groups',
    eventLabel: 'Classes & sessions',
    placeLabel: 'Gyms & studios',
    leaderboardMetric: 'Training volume',
    features: <SportHubFeature>{
      SportHubFeature.places,
      SportHubFeature.communities,
      SportHubFeature.events,
      SportHubFeature.challenges,
      SportHubFeature.leaderboards,
      SportHubFeature.trainers,
      SportHubFeature.pricing,
    },
  );

  static const SportModuleConfig running = SportModuleConfig(
    id: 'running',
    title: 'Running',
    subtitle:
        'Routes, clubs, group runs, races, coaches, and distance rankings.',
    communityLabel: 'Running clubs',
    eventLabel: 'Runs & races',
    placeLabel: 'Routes & tracks',
    leaderboardMetric: 'Distance & pace',
    features: <SportHubFeature>{
      SportHubFeature.places,
      SportHubFeature.communities,
      SportHubFeature.events,
      SportHubFeature.challenges,
      SportHubFeature.leaderboards,
      SportHubFeature.trainers,
      SportHubFeature.routes,
    },
  );

  static const List<SportModuleConfig> implemented = <SportModuleConfig>[
    football,
    gym,
    running,
  ];

  static SportModuleConfig resolve(String sportId) {
    return implemented.firstWhere(
      (SportModuleConfig item) => item.id == sportId,
      orElse: () => SportModuleConfig(
        id: sportId,
        title: _humanize(sportId),
        subtitle:
            'Places, people, events, experts, and communities for ${_humanize(sportId)}.',
        communityLabel: 'Communities',
        eventLabel: 'Events',
        placeLabel: 'Places',
        leaderboardMetric: 'Rankings',
        features: const <SportHubFeature>{
          SportHubFeature.places,
          SportHubFeature.communities,
          SportHubFeature.events,
          SportHubFeature.challenges,
          SportHubFeature.leaderboards,
          SportHubFeature.trainers,
        },
      ),
    );
  }

  static String _humanize(String value) {
    final String clean = value.replaceAll(RegExp(r'[-_]'), ' ').trim();
    if (clean.isEmpty) {
      return 'Sport';
    }
    return clean
        .split(RegExp(r'\s+'))
        .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
