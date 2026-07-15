import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/domain/entities/profile_connection.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../application/messaging_providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> auth = ref.watch(currentAuthUserProvider);
    final AuthUser? user = auth.value;
    final AsyncValue<ProfileConnectionPage>? following = user == null
        ? null
        : ref.watch(
            profileConnectionsProvider(
              ProfileConnectionsQuery(
                profileId: user.uid,
                type: ProfileConnectionType.following,
              ),
            ),
          );
    final bool busy = ref.watch(messagingActionControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New group'),
        actions: <Widget>[
          TextButton(
            onPressed: busy || _selected.isEmpty ? null : _create,
            child: const Text('Create'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _titleController,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'Saturday football squad',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Select people you follow',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('${_selected.length}/49'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: following == null
                  ? const Center(child: CircularProgressIndicator())
                  : following.when(
                      data: (ProfileConnectionPage page) {
                        if (page.items.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'Follow people first, then invite them to a group.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: page.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final UserProfile profile = page.items[index];
                            final bool selected = _selected.contains(
                              profile.uid,
                            );
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value ?? false) {
                                    if (_selected.length < 49) {
                                      _selected.add(profile.uid);
                                    }
                                  } else {
                                    _selected.remove(profile.uid);
                                  }
                                });
                              },
                              secondary: AppAvatar(
                                displayName: profile.displayName,
                                imageUrl: profile.avatarUrl,
                              ),
                              title: Text(profile.displayName),
                              subtitle: Text('@${profile.username}'),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (Object error, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final String title = _titleController.text.trim();
    if (title.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a group name.')));
      return;
    }
    final String? conversationId = await ref
        .read(messagingActionControllerProvider.notifier)
        .createGroup(
          title: title,
          memberIds: _selected.toList(growable: false),
        );
    if (!mounted) {
      return;
    }
    if (conversationId == null) {
      final Object? error = ref.read(messagingActionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Group could not be created.'),
        ),
      );
      return;
    }
    context.go(AppRoutes.conversation(conversationId));
  }
}
