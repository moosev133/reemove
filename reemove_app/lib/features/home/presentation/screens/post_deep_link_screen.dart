import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';

class PostDeepLinkScreen extends StatelessWidget {
  const PostDeepLinkScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppEmptyState(
            icon: Icons.hide_image_outlined,
            title: 'This post is unavailable',
            message:
                'It may have been removed, made private, or shared with an account that cannot access it. Reference: $postId',
          ),
        ],
      ),
    );
  }
}
