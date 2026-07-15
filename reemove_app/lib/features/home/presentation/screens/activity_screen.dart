import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: AdaptivePageBody(
        slivers: const <Widget>[
          AppPageHeader(
            title: 'Activity',
            subtitle:
                'Likes, follows, comments, invitations, and challenge updates appear here.',
          ),
          SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No new activity',
            message:
                'When your ReeMove network interacts with you, it will appear here.',
          ),
        ],
      ),
    );
  }
}
