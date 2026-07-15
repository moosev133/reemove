import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_community.dart';
import '../../domain/services/sport_module_registry.dart';
import '../widgets/sport_community_card.dart';

class SportCommunitiesScreen extends ConsumerWidget {
  const SportCommunitiesScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportModuleConfig module = SportModuleRegistry.resolve(sportId);
    final AsyncValue<List<SportCommunity>> value = ref.watch(
      sportCommunitiesProvider(sportId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(module.communityLabel),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create community',
            onPressed: () =>
                context.push(AppRoutes.createSportCommunity(sportId)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: AdaptivePageBody(
        restorationId: 'sport_communities_$sportId',
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: module.communityLabel,
            subtitle:
                'Join verified teams, clubs, and groups. Owners control membership and capacity.',
          ),
          const SizedBox(height: AppSpacing.lg),
          value.when(
            data: (List<SportCommunity> items) => items.isEmpty
                ? AppEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No communities yet',
                    message:
                        'Create the first ${module.communityLabel.toLowerCase()} in this hub.',
                    actionLabel: 'Create community',
                    onAction: () =>
                        context.push(AppRoutes.createSportCommunity(sportId)),
                  )
                : Column(
                    children: items
                        .map(
                          (SportCommunity item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SportCommunityCard(
                              community: item,
                              onTap: () => context.push(
                                AppRoutes.sportCommunity(sportId, item.id),
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
