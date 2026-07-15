import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/messaging_providers.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key, this.initialUsername});

  final String? initialUsername;

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  late final TextEditingController _controller;
  String? _searchedUsername;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUsername ?? '');
    if (_controller.text.trim().isNotEmpty) {
      _searchedUsername = _controller.text.trim().toLowerCase();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? username = _searchedUsername;
    final AsyncValue<UserProfile?>? result = username == null
        ? null
        : ref.watch(publicProfileByUsernameProvider(username));
    final bool busy = ref.watch(messagingActionControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              'Find someone by username',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You can message people allowed by their privacy settings. Blocking and messaging controls are enforced on the server.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _search,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (result == null)
              const _SearchHint()
            else
              result.when(
                data: (UserProfile? profile) {
                  if (profile == null) {
                    return const _SearchMessage(
                      icon: Icons.person_search_outlined,
                      title: 'No profile found',
                      message: 'Check the username and try again.',
                    );
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          AppAvatar(
                            displayName: profile.displayName,
                            imageUrl: profile.avatarUrl,
                            radius: 28,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  profile.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '@${profile.username} · ${profile.profileLabel}',
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: busy ? null : () => _start(profile),
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Message'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, _) => _SearchMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Search failed',
                  message: error.toString(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _search() {
    final String value = _controller.text.trim().toLowerCase().replaceFirst(
      '@',
      '',
    );
    if (value.isEmpty) {
      return;
    }
    setState(() => _searchedUsername = value);
  }

  Future<void> _start(UserProfile profile) async {
    final String? conversationId = await ref
        .read(messagingActionControllerProvider.notifier)
        .createDirect(profile.uid);
    if (!mounted) {
      return;
    }
    if (conversationId == null) {
      final Object? error = ref.read(messagingActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error?.toString() ?? 'Conversation could not be created.',
          ),
        ),
      );
      return;
    }
    context.go(AppRoutes.conversation(conversationId));
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) => const _SearchMessage(
    icon: Icons.alternate_email_rounded,
    title: 'Search by exact username',
    message: 'Usernames make it easier to find the right athlete or trainer.',
  );
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
