import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../application/marketplace_catalog.dart';
import '../../domain/entities/marketplace_listing.dart';

class MarketplaceFilterSheet extends StatefulWidget {
  const MarketplaceFilterSheet({required this.initial, super.key});

  final MarketplaceSearchFilters initial;

  @override
  State<MarketplaceFilterSheet> createState() => _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState extends State<MarketplaceFilterSheet> {
  late MarketplaceSearchFilters _filters = widget.initial;
  late final TextEditingController _minimumController = TextEditingController(
    text: _filters.minimumPriceMinor == null
        ? ''
        : (_filters.minimumPriceMinor! / 100).toStringAsFixed(0),
  );
  late final TextEditingController _maximumController = TextEditingController(
    text: _filters.maximumPriceMinor == null
        ? ''
        : (_filters.maximumPriceMinor! / 100).toStringAsFixed(0),
  );

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Marketplace filters',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Sport', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filters.sportId == null,
                  onSelected: (_) => setState(
                    () => _filters = _filters.copyWith(
                      clearSport: true,
                      clearCategory: true,
                    ),
                  ),
                ),
                ...MarketplaceCatalog.sportLabels.entries.map(
                  (MapEntry<String, String> entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _filters.sportId == entry.key,
                    onSelected: (_) => setState(() {
                      final bool categorySupported =
                          _filters.categoryId == null ||
                          _categoriesFor(
                            entry.key,
                          ).any((item) => item.id == _filters.categoryId);
                      _filters = _filters.copyWith(
                        sportId: entry.key,
                        clearCategory: !categorySupported,
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String?>(
              initialValue: _filters.categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ..._categoriesFor(_filters.sportId).map(
                  (MarketplaceCategoryOption item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(item.label),
                  ),
                ),
              ],
              onChanged: (String? value) => setState(
                () => _filters = _filters.copyWith(
                  categoryId: value,
                  clearCategory: value == null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ListingCondition?>(
              initialValue: _filters.condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: <DropdownMenuItem<ListingCondition?>>[
                const DropdownMenuItem<ListingCondition?>(
                  value: null,
                  child: Text('Any condition'),
                ),
                ...ListingCondition.values.map(
                  (ListingCondition item) =>
                      DropdownMenuItem<ListingCondition?>(
                        value: item,
                        child: Text(_conditionLabel(item)),
                      ),
                ),
              ],
              onChanged: (ListingCondition? value) => setState(
                () => _filters = _filters.copyWith(
                  condition: value,
                  clearCondition: value == null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minimumController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum price (₪)',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _maximumController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum price (₪)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Delivery', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: MarketplaceDeliveryOption.values
                  .map(
                    (MarketplaceDeliveryOption item) => FilterChip(
                      label: Text(_deliveryLabel(item)),
                      selected: _filters.deliveryOptions.contains(item),
                      onSelected: (bool selected) {
                        final Set<MarketplaceDeliveryOption> next =
                            Set<MarketplaceDeliveryOption>.from(
                              _filters.deliveryOptions,
                            );
                        selected ? next.add(item) : next.remove(item);
                        setState(
                          () => _filters = _filters.copyWith(
                            deliveryOptions: next,
                          ),
                        );
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<MarketplaceSort>(
              initialValue: _filters.sort,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: MarketplaceSort.values
                  .where(
                    (MarketplaceSort item) =>
                        item != MarketplaceSort.nearest ||
                        _filters.usesLocation,
                  )
                  .map(
                    (MarketplaceSort item) => DropdownMenuItem<MarketplaceSort>(
                      value: item,
                      child: Text(_sortLabel(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (MarketplaceSort? value) {
                if (value != null) {
                  setState(() => _filters = _filters.copyWith(sort: value));
                }
              },
            ),
            if (_filters.usesLocation) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text('Distance: ${_filters.radiusKm.toStringAsFixed(0)} km'),
              Slider(
                min: 1,
                max: 100,
                divisions: 99,
                value: _filters.radiusKm.clamp(1, 100).toDouble(),
                label: '${_filters.radiusKm.toStringAsFixed(0)} km',
                onChanged: (double value) => setState(
                  () => _filters = _filters.copyWith(radiusKm: value),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () {
                final double? minimum = double.tryParse(
                  _minimumController.text.trim(),
                );
                final double? maximum = double.tryParse(
                  _maximumController.text.trim(),
                );
                if ((minimum != null && minimum < 0) ||
                    (maximum != null && maximum < 0) ||
                    (minimum != null && maximum != null && minimum > maximum)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid price range.')),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _filters.copyWith(
                    minimumPriceMinor: minimum == null
                        ? null
                        : (minimum * 100).round(),
                    clearMinimumPrice: minimum == null,
                    maximumPriceMinor: maximum == null
                        ? null
                        : (maximum * 100).round(),
                    clearMaximumPrice: maximum == null,
                  ),
                );
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    _minimumController.clear();
    _maximumController.clear();
    setState(() {
      _filters = MarketplaceSearchFilters(
        query: widget.initial.query,
        latitude: widget.initial.latitude,
        longitude: widget.initial.longitude,
        radiusKm: widget.initial.radiusKm,
      );
    });
  }

  static List<MarketplaceCategoryOption> _categoriesFor(String? sportId) =>
      MarketplaceCatalog.categories
          .where(
            (MarketplaceCategoryOption item) =>
                sportId == null ||
                item.sportIds.isEmpty ||
                item.sportIds.contains(sportId),
          )
          .toList(growable: false);

  static String _conditionLabel(ListingCondition value) => switch (value) {
    ListingCondition.newItem => 'New',
    ListingCondition.likeNew => 'Like new',
    ListingCondition.good => 'Good',
    ListingCondition.fair => 'Fair',
    ListingCondition.poor => 'Well used',
  };

  static String _deliveryLabel(MarketplaceDeliveryOption value) =>
      switch (value) {
        MarketplaceDeliveryOption.pickup => 'Pickup',
        MarketplaceDeliveryOption.meetup => 'Meet in public',
        MarketplaceDeliveryOption.shipping => 'Shipping',
      };

  static String _sortLabel(MarketplaceSort value) => switch (value) {
    MarketplaceSort.newest => 'Newest',
    MarketplaceSort.priceLowToHigh => 'Price: low to high',
    MarketplaceSort.priceHighToLow => 'Price: high to low',
    MarketplaceSort.nearest => 'Nearest',
  };
}
