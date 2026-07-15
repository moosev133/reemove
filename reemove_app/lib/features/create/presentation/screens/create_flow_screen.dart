import 'package:flutter/material.dart';

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
    final String title = _titleFor(creationType);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: 'Coming in its dedicated module',
            title: title,
            subtitle:
                'The social publishing tools are ready. This creation type will be enabled in its scheduled product phase.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: _iconFor(creationType),
            title: '$title is not available yet',
            message:
                'Nothing has been published or charged. Return to Create to share a post, story, or reel now.',
          ),
        ],
      ),
    );
  }
}

String _titleFor(String type) => switch (type) {
  'event' => 'Create event or match',
  'challenge' => 'Create challenge',
  'listing' => 'Create marketplace listing',
  _ => 'Create',
};

IconData _iconFor(String type) => switch (type) {
  'event' => Icons.event_available_outlined,
  'challenge' => Icons.emoji_events_outlined,
  'listing' => Icons.sell_outlined,
  _ => Icons.add_circle_outline_rounded,
};
