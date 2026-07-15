import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../notifications/application/notification_providers.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/widgets/notification_tile.dart';

enum _ActivityFilter {
  all,
  social,
  messages,
  events,
  challenges,
  marketplace,
  account,
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> notifications = ref.watch(
      notificationsProvider,
    );
    final AsyncValue<void> action = ref.watch(
      notificationActionControllerProvider,
    );
    final AsyncValue<NotificationHistoryState> history = ref.watch(
      notificationHistoryProvider,
    );
    ref.listen<AsyncValue<void>>(notificationActionControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
      if (next.hasError && !identical(previous?.error, next.error)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: action.isLoading
                ? null
                : () => unawaited(
                    ref
                        .read(notificationActionControllerProvider.notifier)
                        .markAllRead(),
                  ),
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () =>
                unawaited(context.push(AppRoutes.notificationSettings)),
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More activity actions',
            onSelected: (String value) {
              if (value == 'clear_read') {
                unawaited(
                  ref
                      .read(notificationActionControllerProvider.notifier)
                      .clearRead(),
                );
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'clear_read',
                    child: Text('Clear read activity'),
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(notificationUnreadCountProvider);
          ref.read(notificationHistoryProvider.notifier).reset();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => AppErrorView(
            title: 'Activity could not load',
            message: error.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(notificationsProvider),
          ),
          data: (List<AppNotification> items) {
            final NotificationHistoryState historyState =
                history.value ?? const NotificationHistoryState();
            final Map<String, AppNotification> merged =
                <String, AppNotification>{
                  for (final AppNotification item in items) item.id: item,
                  for (final AppNotification item in historyState.items)
                    item.id: item,
                };
            final List<AppNotification> allItems = merged.values.toList()
              ..sort(
                (AppNotification left, AppNotification right) =>
                    right.latestAt.compareTo(left.latestAt),
              );
            final List<AppNotification> filtered = allItems
                .where((AppNotification item) => _matches(item, _filter))
                .toList(growable: false);
            return AdaptivePageBody(
              restorationId: 'activity_inbox',
              slivers: <Widget>[
                const AppPageHeader(
                  eyebrow: 'Your private activity inbox',
                  title: 'Everything important, in one place',
                  subtitle:
                      'Messages, social activity, event changes, challenge results, and marketplace updates are grouped here. Swipe an item left to remove it.',
                ),
                const SizedBox(height: AppSpacing.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _ActivityFilter.values
                        .map((_ActivityFilter value) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: Text(_filterLabel(value)),
                              selected: _filter == value,
                              onSelected: (_) =>
                                  setState(() => _filter = value),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (filtered.isEmpty)
                  AppEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: _filter == _ActivityFilter.all
                        ? 'No activity yet'
                        : 'Nothing in this category',
                    message: _filter == _ActivityFilter.all
                        ? 'When your ReeMove network interacts with you, it will appear here.'
                        : 'Try another filter or check back after your next sports activity.',
                  )
                else
                  ...filtered.map(
                    (AppNotification notification) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: NotificationTile(
                        notification: notification,
                        onTap: () => unawaited(_open(context, notification)),
                        onDelete: () => unawaited(
                          ref
                              .read(
                                notificationActionControllerProvider.notifier,
                              )
                              .delete(notification.id),
                        ),
                      ),
                    ),
                  ),
                if (history.hasError) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Older activity could not load.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (historyState.hasMore &&
                    (items.length >= 50 ||
                        historyState.items.isNotEmpty)) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: FilledButton.tonalIcon(
                      onPressed: history.isLoading
                          ? null
                          : () => unawaited(
                              ref
                                  .read(notificationHistoryProvider.notifier)
                                  .loadMore(items),
                            ),
                      icon: history.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: const Text('Load older activity'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, AppNotification notification) async {
    if (notification.isUnread) {
      await ref
          .read(notificationActionControllerProvider.notifier)
          .markRead(notification.id);
    }
    if (!context.mounted) {
      return;
    }
    context.go(notification.route);
  }
}

bool _matches(AppNotification notification, _ActivityFilter filter) =>
    switch (filter) {
      _ActivityFilter.all => true,
      _ActivityFilter.social =>
        notification.category == AppNotificationCategory.activity,
      _ActivityFilter.messages =>
        notification.category == AppNotificationCategory.messages,
      _ActivityFilter.events =>
        notification.category == AppNotificationCategory.events,
      _ActivityFilter.challenges =>
        notification.category == AppNotificationCategory.challenges,
      _ActivityFilter.marketplace =>
        notification.category == AppNotificationCategory.marketplace,
      _ActivityFilter.account =>
        notification.category == AppNotificationCategory.system ||
            notification.category == AppNotificationCategory.productUpdates,
    };

String _filterLabel(_ActivityFilter filter) => switch (filter) {
  _ActivityFilter.all => 'All',
  _ActivityFilter.social => 'Social',
  _ActivityFilter.messages => 'Messages',
  _ActivityFilter.events => 'Events',
  _ActivityFilter.challenges => 'Challenges',
  _ActivityFilter.marketplace => 'Marketplace',
  _ActivityFilter.account => 'Account',
};
