import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../../core/widgets/app_status_chip.dart';
import '../../../../../core/widgets/premium_surface.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_trainer.dart';

class SportTrainerDetailScreen extends ConsumerWidget {
  const SportTrainerDetailScreen({
    required this.sportId,
    required this.trainerId,
    super.key,
  });

  final String sportId;
  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SportTrainer?> trainerValue = ref.watch(
      sportTrainerProvider(trainerId),
    );
    final AsyncValue<List<TrainerService>> servicesValue = ref.watch(
      trainerServicesProvider(trainerId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Trainer profile')),
      body: trainerValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(error.toString())),
        data: (SportTrainer? trainer) {
          if (trainer == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Trainer unavailable',
                  message: 'This professional profile is no longer available.',
                ),
              ),
            );
          }
          return AdaptivePageBody(
            slivers: <Widget>[
              AppPageHeader(
                eyebrow: 'Verified sport professional',
                title: trainer.displayName,
                subtitle: trainer.headline ?? trainer.bio,
                trailing: AppAvatar(
                  displayName: trainer.displayName,
                  imageUrl: trainer.avatarUrl,
                  radius: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppStatusChip(
                    label: trainer.reviewCount == 0
                        ? 'New trainer'
                        : '${trainer.rating.toStringAsFixed(1)} • ${trainer.reviewCount} reviews',
                    icon: Icons.star_rounded,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  AppStatusChip(
                    label: '${trainer.yearsExperience} years experience',
                    icon: Icons.workspace_premium_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  if (trainer.city.isNotEmpty)
                    AppStatusChip(
                      label: trainer.city,
                      icon: Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.newConversationFor(trainer.username),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Message trainer'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.publicProfile(trainer.username),
                      ),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('View profile'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PremiumSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(trainer.bio),
                    if (trainer.specialties.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: trainer.specialties
                            .map((String item) => Chip(label: Text(item)))
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Services & pricing',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              servicesValue.when(
                data: (List<TrainerService> services) => services.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.design_services_outlined,
                        title: 'No active services',
                        message:
                            'Contact the trainer for current availability.',
                      )
                    : Column(
                        children: services
                            .map((TrainerService service) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: PremiumSurface(
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              service.title,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(service.description),
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            Text(
                                              '${service.durationMinutes} min • ${service.deliveryMode.name}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Text(
                                        '${service.price.amountMajor.toStringAsFixed(0)} ${service.price.currency}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (Object error, StackTrace _) => Text(error.toString()),
              ),
            ],
          );
        },
      ),
    );
  }
}
