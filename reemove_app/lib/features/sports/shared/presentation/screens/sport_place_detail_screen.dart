import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_place.dart';

class SportPlaceDetailScreen extends ConsumerWidget {
  const SportPlaceDetailScreen({
    required this.sportId,
    required this.placeId,
    super.key,
  });

  final String sportId;
  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SportPlace?> value = ref.watch(
      sportPlaceProvider(placeId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Place details')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(error.toString())),
        data: (SportPlace? place) {
          if (place == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppEmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Place unavailable',
                  message: 'This listing may have been removed or restricted.',
                ),
              ),
            );
          }
          return AdaptivePageBody(
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: sportId.toUpperCase(),
                title: place.name,
                subtitle: <String>[
                  place.addressLine,
                  place.city,
                  place.countryCode,
                ].where((String item) => item.isNotEmpty).join(' • '),
                trailing: place.isVerified
                    ? Icon(
                        Icons.verified_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppStatusChip(
                    label: place.reviewCount == 0
                        ? 'No reviews yet'
                        : '${place.rating.toStringAsFixed(1)} from ${place.reviewCount} reviews',
                    icon: Icons.star_rounded,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  if (place.pricingText case final String pricing)
                    AppStatusChip(
                      label: pricing,
                      icon: Icons.payments_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      place.description.isEmpty
                          ? 'No description provided.'
                          : place.description,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PremiumSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Location',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${place.location.latitude.toStringAsFixed(4)}, ${place.location.longitude.toStringAsFixed(4)}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Map view arrives in Phase 10'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
