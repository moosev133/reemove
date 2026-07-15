class MarketplaceCategoryOption {
  const MarketplaceCategoryOption({
    required this.id,
    required this.label,
    required this.iconName,
    this.sportIds = const <String>[],
  });

  final String id;
  final String label;
  final String iconName;
  final List<String> sportIds;
}

abstract final class MarketplaceCatalog {
  static const List<MarketplaceCategoryOption> categories =
      <MarketplaceCategoryOption>[
        MarketplaceCategoryOption(
          id: 'football_gear',
          label: 'Football gear',
          iconName: 'sports_soccer',
          sportIds: <String>['football'],
        ),
        MarketplaceCategoryOption(
          id: 'gym_equipment',
          label: 'Gym equipment',
          iconName: 'fitness_center',
          sportIds: <String>['gym'],
        ),
        MarketplaceCategoryOption(
          id: 'running_gear',
          label: 'Running gear',
          iconName: 'directions_run',
          sportIds: <String>['running'],
        ),
        MarketplaceCategoryOption(
          id: 'wearables',
          label: 'Sports wearables',
          iconName: 'watch',
        ),
        MarketplaceCategoryOption(
          id: 'apparel',
          label: 'Sports apparel',
          iconName: 'checkroom',
        ),
        MarketplaceCategoryOption(
          id: 'recovery',
          label: 'Recovery equipment',
          iconName: 'spa',
        ),
        MarketplaceCategoryOption(
          id: 'other',
          label: 'Other sports equipment',
          iconName: 'category',
        ),
      ];

  static const Map<String, String> sportLabels = <String, String>{
    'football': 'Football',
    'gym': 'Gym',
    'running': 'Running',
  };

  static String categoryLabel(String id) {
    for (final MarketplaceCategoryOption item in categories) {
      if (item.id == id) {
        return item.label;
      }
    }
    return 'Sports equipment';
  }
}
