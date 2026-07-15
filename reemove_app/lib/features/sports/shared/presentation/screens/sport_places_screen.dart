import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_place.dart';
import '../../domain/services/sport_module_registry.dart';
import '../widgets/sport_place_card.dart';

class SportPlacesScreen extends ConsumerWidget {
  const SportPlacesScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportModuleConfig module = SportModuleRegistry.resolve(sportId);
    final AsyncValue<List<SportPlace>> value = ref.watch(
      sportPlacesProvider(sportId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(module.placeLabel),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open nearby map',
            onPressed: () => context.push(AppRoutes.nearbyForSport(sportId)),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: AdaptivePageBody(
        restorationId: 'sport_places_$sportId',
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: module.placeLabel,
            subtitle:
                'Verified locations, facilities, ratings, pricing, and nearby map discovery.',
          ),
          const SizedBox(height: AppSpacing.lg),
          value.when(
            data: (List<SportPlace> items) => items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.place_outlined,
                    title: 'No places found',
                    message: 'New verified locations will appear here.',
                  )
                : Column(
                    children: items
                        .map(
                          (SportPlace item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SportPlaceCard(
                              place: item,
                              onTap: () => context.push(
                                AppRoutes.sportPlace(sportId, item.id),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace _) => AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Places are unavailable',
              message: error.toString(),
            ),
          ),
        ],
      ),
    );
  }
}
