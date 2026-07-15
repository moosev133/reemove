import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/blocked_profile.dart';

class BlockedProfilesScreen extends ConsumerWidget {
  const BlockedProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BlockedProfile>> value = ref.watch(
      blockedProfilesProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked profiles')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => AdaptivePageBody(
          slivers: <Widget>[
            AppEmptyState(
              icon: Icons.block_outlined,
              title: 'Blocked profiles unavailable',
              message: '$error',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(blockedProfilesProvider),
            ),
          ],
        ),
        data: (List<BlockedProfile> blocked) {
          if (blocked.isEmpty) {
            return const AdaptivePageBody(
              slivers: <Widget>[
                AppEmptyState(
                  icon: Icons.shield_outlined,
                  title: 'No blocked profiles',
                  message: 'Profiles you block will appear here.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: blocked.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final BlockedProfile item = blocked[index];
              return ListTile(
                leading: AppAvatar(
                  displayName: item.profile.displayName,
                  imageUrl: item.profile.avatarUrl,
                ),
                title: Text(item.profile.displayName),
                subtitle: Text('@${item.profile.username}'),
                trailing: OutlinedButton(
                  onPressed: () => _unblock(context, ref, item),
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockedProfile item,
  ) async {
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .unblock(item.profile.uid);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${item.profile.displayName} was unblocked.'
              : '${ref.read(profileActionControllerProvider).error}',
        ),
      ),
    );
  }
}
