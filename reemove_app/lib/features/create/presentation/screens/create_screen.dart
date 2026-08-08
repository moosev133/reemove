import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/release/release_control_service.dart';
import '../../../../core/release/release_feature_gate.dart';
import '../../../../core/release/release_providers.dart';
import '../../../../core/release/release_state.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/premium_surface.dart';

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen>
    with AutomaticKeepAliveClientMixin<CreateScreen> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ReleaseState release = ref.watch(releaseStateProvider).maybeWhen(
          data: (ReleaseState value) => value,
          orElse: () => ReleaseControlService.loadSafeDefaults(),
        );
    final List<_CreationOption> options = <_CreationOption>[
      const _CreationOption(
        id: 'post',
        title: 'Post',
        description: 'Share photos, video, progress, or a sports moment.',
        icon: Icons.photo_camera_back_outlined,
      ),
      if (ReleaseFeatureGate.showStoryUpload(release))
        const _CreationOption(
        id: 'story',
        title: 'Story',
        description: 'Share an update designed for a temporary story.',
        icon: Icons.auto_awesome_motion_outlined,
      ),
      const _CreationOption(
        id: 'reel',
        title: 'Reel',
        description: 'Create a short sports video for discovery.',
        icon: Icons.video_collection_outlined,
      ),
      const _CreationOption(
        id: 'event',
        title: 'Event or match',
        description: 'Organize a session, match, race, or meetup.',
        icon: Icons.event_available_outlined,
      ),
      const _CreationOption(
        id: 'challenge',
        title: 'Challenge',
        description: 'Create a community challenge with goals and rankings.',
        icon: Icons.emoji_events_outlined,
      ),
      if (ReleaseFeatureGate.showMarketplace(release))
        const _CreationOption(
        id: 'listing',
        title: 'Marketplace listing',
        description: 'List sports equipment for the ReeMove community.',
        icon: Icons.sell_outlined,
      ),
      if (ReleaseFeatureGate.showAiModules(release))
        const _CreationOption(
        id: 'ai_content',
        title: 'Content Assistant',
        description: 'Draft captions and post ideas with ReeMove AI.',
        icon: Icons.edit_note_rounded,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Make your next move',
            title: 'Create',
            subtitle:
                'Choose what you want to share, organize, or offer to the ReeMove community.',
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: options
                    .map(
                      (_CreationOption option) => SizedBox(
                        width: width,
                        child: _CreationCard(
                          option: option,
                          onTap: () {
                            if (option.id == 'ai_content') {
                              context.push(AppRoutes.aiContent);
                              return;
                            }
                            context.push(AppRoutes.createFlow(option.id));
                          },
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

class _CreationOption {
  const _CreationOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

class _CreationCard extends StatelessWidget {
  const _CreationCard({required this.option, required this.onTap});

  final _CreationOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Icon(
                option.icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  option.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  option.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}
