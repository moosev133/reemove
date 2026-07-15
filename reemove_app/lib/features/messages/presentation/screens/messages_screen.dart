import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with AutomaticKeepAliveClientMixin<MessagesScreen> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Start a conversation',
            onPressed: () => context.go(AppRoutes.discover),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: AdaptivePageBody(
        maxWidth: 820,
        slivers: <Widget>[
          const AppPageHeader(
            eyebrow: 'Your sports conversations',
            title: 'Messages',
            subtitle:
                'Direct messages, groups, match planning, and marketplace conversations stay together here.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const SearchBar(
            hintText: 'Search conversations',
            leading: Icon(Icons.search_rounded),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            message:
                'Discover athletes, trainers, groups, and events to start a sports conversation.',
            actionLabel: 'Discover people',
            onAction: () => context.go(AppRoutes.discover),
          ),
        ],
      ),
    );
  }
}
