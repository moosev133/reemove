import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/feed_providers.dart';
import '../../domain/entities/content_draft.dart';
import '../../domain/entities/upload_status.dart';
import '../../domain/value_objects/content_limits.dart';

class ContentComposerScreen extends ConsumerStatefulWidget {
  const ContentComposerScreen({required this.kind, super.key});

  final DraftKind kind;

  @override
  ConsumerState<ContentComposerScreen> createState() =>
      _ContentComposerScreenState();
}

class _ContentComposerScreenState extends ConsumerState<ContentComposerScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  ContentDraft? _draft;
  bool _loading = true;
  bool _publishing = false;
  double _uploadProgress = 0;
  String? _error;

  int get _captionLimit => widget.kind == DraftKind.story
      ? ContentLimits.storyCaptionCharacters
      : ContentLimits.postCaptionCharacters;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final Result<ContentDraft?> result = await ref
        .read(contentDraftRepositoryProvider)
        .load(widget.kind);
    ContentDraft draft = result.when(
      success: (ContentDraft? value) => value ?? _newDraft(),
      failure: (_) => _newDraft(),
    );
    final Result<List<DraftMediaSelection>> recovery = await ref
        .read(contentMediaPickerProvider)
        .recoverLostSelections();
    recovery.when<void>(
      success: (List<DraftMediaSelection> selections) {
        if (selections.isNotEmpty && draft.media.isEmpty) {
          final List<DraftMediaSelection> valid = _validateForKind(selections);
          if (valid.isNotEmpty) {
            draft = draft.copyWith(media: valid);
          }
        }
      },
      failure: (_) {},
    );
    if (!mounted) {
      return;
    }
    _captionController.text = draft.caption;
    _locationController.text = draft.locationLabel ?? '';
    setState(() {
      _draft = draft;
      _loading = false;
    });
  }

  ContentDraft _newDraft() => ContentDraft.empty(
    kind: widget.kind,
    id: '${widget.kind.name}-${DateTime.now().microsecondsSinceEpoch}',
  );

  List<DraftMediaSelection> _validateForKind(
    List<DraftMediaSelection> selections,
  ) {
    if (widget.kind == DraftKind.reel) {
      return selections
          .where(
            (DraftMediaSelection item) => item.kind == DraftMediaKind.video,
          )
          .take(1)
          .toList(growable: false);
    }
    if (widget.kind == DraftKind.story) {
      return selections.take(1).toList();
    }
    final bool hasVideo = selections.any(
      (DraftMediaSelection item) => item.kind == DraftMediaKind.video,
    );
    return hasVideo
        ? selections
              .where(
                (DraftMediaSelection item) => item.kind == DraftMediaKind.video,
              )
              .take(1)
              .toList(growable: false)
        : selections.take(ContentLimits.maxPostImages).toList(growable: false);
  }

  Future<void> _pickMedia() async {
    if (_publishing) {
      return;
    }
    final result = widget.kind == DraftKind.reel
        ? await ref.read(contentMediaPickerProvider).pickVideo()
        : await _showMediaChoice();
    result.when<void>(
      success: (Object? value) {
        final List<DraftMediaSelection> picked;
        if (value is DraftMediaSelection) {
          picked = <DraftMediaSelection>[value];
        } else if (value is List<DraftMediaSelection>) {
          picked = value;
        } else {
          picked = const <DraftMediaSelection>[];
        }
        if (picked.isEmpty) {
          return;
        }
        final List<DraftMediaSelection> merged = _validateForKind(
          <DraftMediaSelection>[...?_draft?.media, ...picked],
        );
        _updateDraft(_draft!.copyWith(media: merged));
      },
      failure: _showFailure,
    );
  }

  Future<Result<Object?>> _showMediaChoice() async {
    final DraftMediaKind? kind = await showModalBottomSheet<DraftMediaKind>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photos'),
                subtitle: Text(
                  widget.kind == DraftKind.story
                      ? 'One photo for this story'
                      : 'Up to ${ContentLimits.maxPostImages} photos',
                ),
                onTap: () => Navigator.pop(context, DraftMediaKind.image),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Choose video'),
                subtitle: const Text('One video, up to 90 seconds'),
                onTap: () => Navigator.pop(context, DraftMediaKind.video),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind == null) {
      return const Success<Object?>(null);
    }
    if (kind == DraftMediaKind.video) {
      final Result<DraftMediaSelection?> result = await ref
          .read(contentMediaPickerProvider)
          .pickVideo();
      return result.when<Result<Object?>>(
        success: (DraftMediaSelection? value) => Success<Object?>(value),
        failure: (Failure failure) => FailureResult<Object?>(failure),
      );
    }
    final Result<List<DraftMediaSelection>> result = await ref
        .read(contentMediaPickerProvider)
        .pickImages(limit: widget.kind == DraftKind.story ? 1 : 10);
    return result.when<Result<Object?>>(
      success: (List<DraftMediaSelection> value) => Success<Object?>(value),
      failure: (Failure failure) => FailureResult<Object?>(failure),
    );
  }

  void _removeMedia(int index) {
    final ContentDraft draft = _draft!;
    final List<DraftMediaSelection> media = List.of(draft.media)
      ..removeAt(index);
    _updateDraft(draft.copyWith(media: media));
  }

  void _updateDraft(ContentDraft draft) {
    setState(() {
      _draft = draft;
      _error = null;
    });
    unawaited(ref.read(contentDraftRepositoryProvider).save(draft));
  }

  Future<void> _publish() async {
    final ContentDraft? current = _draft;
    if (current == null || _publishing) {
      return;
    }
    final String caption = _captionController.text.trim();
    if (caption.length > _captionLimit) {
      setState(
        () => _error = 'The caption is longer than $_captionLimit characters.',
      );
      return;
    }
    if (current.media.isEmpty) {
      setState(() => _error = 'Choose media before publishing.');
      return;
    }
    if (widget.kind == DraftKind.reel &&
        current.media.first.kind != DraftMediaKind.video) {
      setState(() => _error = 'A reel needs one video.');
      return;
    }
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      setState(() => _error = 'Sign in again before publishing.');
      return;
    }
    final ContentDraft ready = current.copyWith(
      caption: caption,
      locationLabel: _locationController.text.trim(),
      clearLocationLabel: _locationController.text.trim().isEmpty,
    );
    _updateDraft(ready);
    setState(() {
      _publishing = true;
      _uploadProgress = 0;
      _error = null;
    });

    final List<MediaAsset> uploaded = <MediaAsset>[];
    try {
      for (int index = 0; index < ready.media.length; index++) {
        final DraftMediaSelection selection = ready.media[index];
        MediaAsset? completed;
        await for (final MediaUploadStatus status
            in ref
                .read(contentPublishingRepositoryProvider)
                .uploadMedia(
                  ownerId: user.uid,
                  draftId: ready.id,
                  selection: selection,
                )) {
          if (!mounted) {
            return;
          }
          setState(() {
            _uploadProgress = (index + status.progress) / ready.media.length;
          });
          if (status.state == MediaProcessingState.failed) {
            throw StateError(status.message ?? 'A media upload failed.');
          }
          if (status.asset != null) {
            completed = status.asset;
          }
        }
        if (completed == null) {
          throw StateError('A media upload did not finish.');
        }
        uploaded.add(completed);
      }

      final Result<void> result;
      if (widget.kind == DraftKind.story) {
        final storyResult = await ref
            .read(contentPublishingRepositoryProvider)
            .publishStory(draft: ready, media: uploaded.single);
        result = storyResult.when<Result<void>>(
          success: (_) => const Success<void>(null),
          failure: FailureResult<void>.new,
        );
      } else {
        final postResult = await ref
            .read(contentPublishingRepositoryProvider)
            .publishPost(draft: ready, media: uploaded);
        result = postResult.when<Result<void>>(
          success: (_) => const Success<void>(null),
          failure: FailureResult<void>.new,
        );
      }
      await result.when<Future<void>>(
        success: (_) async {
          await ref.read(contentDraftRepositoryProvider).clear(widget.kind);
          ref.invalidate(feedControllerProvider);
          ref.invalidate(storyRailProvider);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.kind == DraftKind.story
                    ? 'Story published.'
                    : widget.kind == DraftKind.reel
                    ? 'Reel uploaded. It will appear after video processing.'
                    : 'Post published.',
              ),
            ),
          );
          context.go(
            widget.kind == DraftKind.story
                ? AppRoutes.home
                : widget.kind == DraftKind.reel
                ? AppRoutes.reels
                : AppRoutes.home,
          );
        },
        failure: (Failure failure) async => _showFailure(failure),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  void _showFailure(Failure failure) {
    if (!mounted) {
      return;
    }
    setState(() => _error = failure.message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _draft == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final ContentDraft draft = _draft!;
    final String title = switch (widget.kind) {
      DraftKind.post => 'New post',
      DraftKind.story => 'New story',
      DraftKind.reel => 'New reel',
    };
    return PopScope(
      canPop: !_publishing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: <Widget>[
            TextButton(
              onPressed: _publishing ? null : _publish,
              child: const Text('Publish'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _MediaPreview(
                        draft: draft,
                        onPick: _pickMedia,
                        onRemove: _removeMedia,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _captionController,
                        maxLength: _captionLimit,
                        minLines: 3,
                        maxLines: 8,
                        enabled: !_publishing,
                        decoration: InputDecoration(
                          labelText: 'Caption',
                          hintText: widget.kind == DraftKind.story
                              ? 'Add context to your story…'
                              : 'Share the move, milestone, or lesson…',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (String value) =>
                            _updateDraft(draft.copyWith(caption: value)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<Visibility>(
                        initialValue: draft.visibility,
                        decoration: const InputDecoration(
                          labelText: 'Audience',
                          prefixIcon: Icon(Icons.visibility_outlined),
                        ),
                        items: Visibility.values
                            .map(
                              (Visibility value) =>
                                  DropdownMenuItem<Visibility>(
                                    value: value,
                                    child: Text(_visibilityLabel(value)),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: _publishing
                            ? null
                            : (Visibility? value) {
                                if (value != null) {
                                  _updateDraft(
                                    draft.copyWith(visibility: value),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _locationController,
                        enabled: !_publishing,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Location label (optional)',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          hintText: 'Central Park, Haifa Beach, local gym…',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: draft.allowComments,
                        title: const Text('Allow comments'),
                        subtitle: const Text(
                          'You can remove individual comments later.',
                        ),
                        onChanged: _publishing
                            ? null
                            : (bool value) => _updateDraft(
                                draft.copyWith(allowComments: value),
                              ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_publishing) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        LinearProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Uploading ${(_uploadProgress * 100).round()}%',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: _publishing ? null : _publish,
                        icon: const Icon(Icons.publish_rounded),
                        label: Text(
                          _publishing ? 'Publishing…' : 'Publish $title',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.draft,
    required this.onPick,
    required this.onRemove,
  });

  final ContentDraft draft;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (draft.media.isEmpty) {
      return AspectRatio(
        aspectRatio: draft.kind == DraftKind.story ? 9 / 16 : 4 / 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPick,
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add_photo_alternate_outlined, size: 48),
                SizedBox(height: AppSpacing.sm),
                Text('Choose photos or video'),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: draft.kind == DraftKind.story ? 420 : 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: draft.media.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final DraftMediaSelection media = draft.media[index];
              return SizedBox(
                width: draft.kind == DraftKind.story ? 236 : 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: media.kind == DraftMediaKind.image
                          ? FutureBuilder<Uint8List>(
                              future: XFile(media.localPath).readAsBytes(),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<Uint8List> snapshot,
                                  ) {
                                    if (snapshot.hasData) {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return const ColoredBox(
                                        color: Colors.black12,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                            )
                          : ColoredBox(
                              color: Colors.black,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      media.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove media',
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add or replace media'),
        ),
      ],
    );
  }
}

String _visibilityLabel(Visibility visibility) => switch (visibility) {
  Visibility.public => 'Everyone',
  Visibility.followers => 'Followers',
  Visibility.private => 'Only me',
};
