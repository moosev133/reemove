import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../challenges/presentation/screens/create_challenge_screen.dart';
import '../../../feed/domain/entities/content_draft.dart';
import '../../../feed/presentation/screens/content_composer_screen.dart';
import '../../../marketplace/presentation/screens/create_marketplace_listing_screen.dart';

class CreateFlowScreen extends StatelessWidget {
  const CreateFlowScreen({required this.creationType, super.key});

  final String creationType;

  @override
  Widget build(BuildContext context) {
    final DraftKind? kind = switch (creationType) {
      'post' => DraftKind.post,
      'story' => DraftKind.story,
      'reel' => DraftKind.reel,
      _ => null,
    };
    if (kind != null) {
      return ContentComposerScreen(kind: kind);
    }
    if (creationType == 'challenge') {
      return const CreateChallengeScreen();
    }
    if (creationType == 'listing') {
      return const CreateMarketplaceListingScreen();
    }
    if (creationType == 'event') {
      return Scaffold(
        appBar: AppBar(title: const Text('Create event or match')),
        body: AdaptivePageBody(
          slivers: <Widget>[
            const AppPageHeader(
              eyebrow: 'Sports hubs own events',
              title: 'Choose a sport first',
              subtitle:
                  'Events and matches are created inside a sport hub so they inherit the community, place catalog, and members for that sport.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Open a sport hub to continue',
              message:
                  'Pick Football, Gym, or Running, then use Create event from that hub.',
              actionLabel: 'Open Sports',
              onAction: () => context.go(AppRoutes.sports),
            ),
          ],
        ),
      );
    }
    final String title = _titleFor(creationType);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: 'Unavailable creation type',
            title: title,
            subtitle:
                'This creation path is not wired. Share a post, story, reel, challenge, or listing from Create instead.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: _iconFor(creationType),
            title: '$title is not available',
            message: 'Return to Create and choose a supported option.',
          ),
        ],
      ),
    );
  }
}

String _titleFor(String type) => switch (type) {
  'event' => 'Create event or match',
  _ => 'Create',
};

IconData _iconFor(String type) => switch (type) {
  'event' => Icons.event_available_outlined,
  _ => Icons.add_circle_outline_rounded,
};
