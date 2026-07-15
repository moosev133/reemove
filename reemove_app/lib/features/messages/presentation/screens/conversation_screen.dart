import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: AdaptivePageBody(
        maxWidth: 820,
        slivers: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppEmptyState(
            icon: Icons.mark_chat_unread_outlined,
            title: 'Conversation unavailable',
            message:
                'This conversation may no longer exist, or your account may not have access. Reference: $conversationId',
          ),
        ],
      ),
    );
  }
}
