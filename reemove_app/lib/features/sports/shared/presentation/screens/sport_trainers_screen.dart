import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_trainer.dart';
import '../../domain/services/sport_module_registry.dart';
import '../widgets/sport_trainer_card.dart';

class SportTrainersScreen extends ConsumerWidget {
  const SportTrainersScreen({required this.sportId, super.key});

  final String sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportModuleConfig module = SportModuleRegistry.resolve(sportId);
    final AsyncValue<List<SportTrainer>> value = ref.watch(
      sportTrainersProvider(sportId),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainers'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Publish a service',
            onPressed: () =>
                context.push(AppRoutes.manageTrainerService(sportId)),
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: AdaptivePageBody(
        restorationId: 'sport_trainers_$sportId',
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: 'Trainers & experts',
            subtitle:
                'Browse verified professionals, specialties, reviews, service formats, and transparent pricing.',
          ),
          const SizedBox(height: AppSpacing.lg),
          value.when(
            data: (List<SportTrainer> items) => items.isEmpty
                ? AppEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No trainers available',
                    message:
                        'Approved professionals accepting clients will appear here.',
                    actionLabel: 'Publish a service',
                    onAction: () =>
                        context.push(AppRoutes.manageTrainerService(sportId)),
                  )
                : Column(
                    children: items
                        .map(
                          (SportTrainer item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SportTrainerCard(
                              trainer: item,
                              onTap: () => context.push(
                                AppRoutes.sportTrainer(sportId, item.id),
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
