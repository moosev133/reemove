import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sports_event.dart';
import '../../domain/services/sport_module_registry.dart';
import '../widgets/sport_event_card.dart';

class SportEventsScreen extends ConsumerWidget {
  const SportEventsScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportModuleConfig module = SportModuleRegistry.resolve(sportId);
    final AsyncValue<List<SportsEvent>> value = ref.watch(
      sportEventsProvider(sportId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(module.eventLabel),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create event',
            onPressed: () => context.push(AppRoutes.createSportEvent(sportId)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: AdaptivePageBody(
        restorationId: 'sport_events_$sportId',
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: module.eventLabel,
            subtitle:
                'Matches, sessions, classes, meetups, races, and competitions with trusted attendance controls.',
          ),
          const SizedBox(height: AppSpacing.lg),
          value.when(
            data: (List<SportsEvent> items) => items.isEmpty
                ? AppEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Nothing scheduled',
                    message: 'Create the first event for this sport hub.',
                    actionLabel: 'Create event',
                    onAction: () =>
                        context.push(AppRoutes.createSportEvent(sportId)),
                  )
                : Column(
                    children: items
                        .map(
                          (SportsEvent item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SportEventCard(
                              event: item,
                              onTap: () => context.push(
                                AppRoutes.sportEvent(sportId, item.id),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (Object error, StackTrace _) => Text(error.toString()),
          ),
        ],
      ),
    );
  }
}
