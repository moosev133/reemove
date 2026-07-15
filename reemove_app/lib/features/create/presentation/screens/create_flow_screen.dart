import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';

class CreateFlowScreen extends StatelessWidget {
  const CreateFlowScreen({required this.creationType, super.key});

  final String creationType;

  @override
  Widget build(BuildContext context) {
    final String title = _titleFor(creationType);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: 'Create safely',
            title: title,
            subtitle:
                'Set up your $title with the right audience, sport, and visibility.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: _iconFor(creationType),
            title: '$title is temporarily unavailable',
            message:
                'Creation is currently disabled for this account. Nothing has been published or charged, and you can return here later.',
          ),
        ],
      ),
    );
  }
}

String _titleFor(String type) => switch (type) {
  'post' => 'Create post',
  'story' => 'Create story',
  'reel' => 'Create reel',
  'event' => 'Create event or match',
  'challenge' => 'Create challenge',
  'listing' => 'Create marketplace listing',
  _ => 'Create',
};

IconData _iconFor(String type) => switch (type) {
  'post' => Icons.photo_camera_back_outlined,
  'story' => Icons.auto_awesome_motion_outlined,
  'reel' => Icons.video_collection_outlined,
  'event' => Icons.event_available_outlined,
  'challenge' => Icons.emoji_events_outlined,
  'listing' => Icons.sell_outlined,
  _ => Icons.add_circle_outline_rounded,
};
