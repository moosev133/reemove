import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';

class AiHubScreen extends StatelessWidget {
  const AiHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_AiModuleTile> modules = <_AiModuleTile>[
      _AiModuleTile(
        title: 'AI Coach',
        description: 'Ask for sport, recovery, and motivation guidance.',
        icon: Icons.chat_bubble_outline_rounded,
        route: AppRoutes.aiCoach,
      ),
      _AiModuleTile(
        title: 'Workout Generator',
        description: 'Build a safe weekly session plan for your sport.',
        icon: Icons.fitness_center_rounded,
        route: AppRoutes.aiWorkout,
      ),
      _AiModuleTile(
        title: 'Nutrition Guidance',
        description: 'Get conservative fueling tips for training days.',
        icon: Icons.restaurant_menu_rounded,
        route: AppRoutes.aiNutrition,
      ),
      _AiModuleTile(
        title: 'Player Matchmaker',
        description: 'Rank nearby athletes already found by discovery.',
        icon: Icons.groups_outlined,
        route: AppRoutes.aiMatchmaker,
      ),
      _AiModuleTile(
        title: 'Challenge Generator',
        description: 'Create low-to-moderate risk community challenges.',
        icon: Icons.emoji_events_outlined,
        route: AppRoutes.aiChallenge,
      ),
      _AiModuleTile(
        title: 'Content Assistant',
        description: 'Draft captions and post ideas for your activity.',
        icon: Icons.edit_note_rounded,
        route: AppRoutes.aiContent,
      ),
      _AiModuleTile(
        title: 'Trainer Insights',
        description: 'Review business metrics for trainer accounts.',
        icon: Icons.insights_rounded,
        route: AppRoutes.aiTrainerInsights,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ReeMove AI')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Safety-first AI for sport',
            title: 'Choose a module',
            subtitle:
                'Every request is authenticated, rate-limited, moderated, and never exposes an API key to the app.',
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: modules
                    .map(
                      (_AiModuleTile module) => SizedBox(
                        width: width,
                        child: PremiumSurface(
                          onTap: () => context.push(module.route),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                module.icon,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      module.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      module.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiModuleTile {
  const _AiModuleTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
}
