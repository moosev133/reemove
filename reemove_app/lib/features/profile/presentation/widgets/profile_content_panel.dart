import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../feed/domain/entities/feed_post.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_content_page.dart';
import 'profile_content_grid.dart';

class ProfileContentPanel extends ConsumerStatefulWidget {
  const ProfileContentPanel({
    required this.profileId,
    required this.filter,
    required this.onOpen,
    super.key,
  });

  final String profileId;
  final ProfileContentFilter filter;
  final ValueChanged<String> onOpen;

  @override
  ConsumerState<ProfileContentPanel> createState() =>
      _ProfileContentPanelState();
}

class _ProfileContentPanelState extends ConsumerState<ProfileContentPanel> {
  ProfileContentPage? _page;
  bool _loadingMore = false;
  String? _failure;

  @override
  void didUpdateWidget(covariant ProfileContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.filter != widget.filter) {
      _page = null;
      _failure = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileContentQuery query = ProfileContentQuery(
      profileId: widget.profileId,
      filter: widget.filter,
    );
    final AsyncValue<ProfileContentPage> initial = ref.watch(
      profileContentPageProvider(query),
    );
    return initial.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(profileContentPageProvider(query)),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (ProfileContentPage value) {
        _page ??= value;
        final ProfileContentPage page = _page!;
        return Column(
          children: <Widget>[
            ProfileContentGrid(
              page: page,
              filter: widget.filter,
              onOpen: widget.onOpen,
              onLoadMore: page.hasMore && !_loadingMore ? _loadMore : null,
            ),
            if (_loadingMore) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const CircularProgressIndicator(),
            ],
            if (_failure != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _loadMore() async {
    final ProfileContentPage? current = _page;
    if (current == null || current.nextCursor == null || _loadingMore) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _failure = null;
    });
    final AuthUser? viewer = await ref.read(currentAuthUserProvider.future);
    if (viewer == null) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _failure = 'Sign in again to continue.';
        });
      }
      return;
    }
    final Result<ProfileContentPage> result = await ref
        .read(profileContentRepositoryProvider)
        .load(
          profileId: widget.profileId,
          viewerId: viewer.uid,
          filter: widget.filter,
          cursor: current.nextCursor,
        );
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (ProfileContentPage next) {
        final Map<String, FeedPost> merged = <String, FeedPost>{
          for (final item in current.items) item.id: item,
          for (final item in next.items) item.id: item,
        };
        setState(() {
          _page = ProfileContentPage(
            items: merged.values.toList(growable: false),
            hasMore: next.hasMore,
            nextCursor: next.nextCursor,
          );
          _loadingMore = false;
        });
      },
      failure: (Failure failure) {
        setState(() {
          _loadingMore = false;
          _failure = failure.message;
        });
      },
    );
  }
}
