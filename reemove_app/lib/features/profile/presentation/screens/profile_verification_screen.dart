import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/debug/staging_diagnostics.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/verification_request.dart';
import '../../data/services/platform_verification_evidence_picker.dart';
import '../../domain/repositories/verification_evidence_repository.dart';
import '../../domain/services/verification_evidence_validator.dart';

enum _EvidenceUiStatus {
  choosingFile,
  readingFile,
  validating,
  selected,
  selecting,
  uploadingFile,
  savingEvidence,
  uploaded,
  failed,
  cancelled,
}

class _EvidenceRow {
  _EvidenceRow({
    required this.id,
    required this.label,
    required this.documentKind,
    required this.status,
    this.filename,
    this.sizeBytes,
    this.progress = 0,
    this.error,
    this.evidence,
    this.source,
  });

  final String id;
  String label;
  VerificationDocumentKind documentKind;
  _EvidenceUiStatus status;
  String? filename;
  int? sizeBytes;
  double progress;
  String? error;
  VerificationEvidence? evidence;
  ProfileImageSource? source;
  int bytesTransferred = 0;
  int totalBytes = 0;
  Future<bool> Function()? cancelUpload;
  String uploadAttemptId = '';

  bool get isUploaded =>
      status == _EvidenceUiStatus.uploaded && evidence != null;
}

class ProfileVerificationScreen extends ConsumerStatefulWidget {
  const ProfileVerificationScreen({
    this.uploadTimeout = const Duration(seconds: 90),
    super.key,
  });

  final Duration uploadTimeout;

  @override
  ConsumerState<ProfileVerificationScreen> createState() =>
      _ProfileVerificationScreenState();
}

class _ProfileVerificationScreenState
    extends ConsumerState<ProfileVerificationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _legalName = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final List<_EvidenceRow> _rows = <_EvidenceRow>[];
  VerificationType _type = VerificationType.trainer;
  VerificationDocumentKind _documentKind =
      VerificationDocumentKind.certification;
  bool _resubmitting = false;
  bool _hydratedDraft = false;
  bool _savingDraft = false;
  bool _submitting = false;
  int _rowSeq = 0;

  bool _pickingEvidence = false;

  bool get _hasPendingUpload => _rows.any(
    (_EvidenceRow row) =>
        row.status == _EvidenceUiStatus.choosingFile ||
        row.status == _EvidenceUiStatus.readingFile ||
        row.status == _EvidenceUiStatus.uploadingFile ||
        row.status == _EvidenceUiStatus.selecting ||
        row.status == _EvidenceUiStatus.savingEvidence ||
        row.status == _EvidenceUiStatus.validating ||
        row.status == _EvidenceUiStatus.selected ||
        row.status == _EvidenceUiStatus.uploadingFile,
  );

  bool get _hasFailedUpload =>
      _rows.any((_EvidenceRow row) => row.status == _EvidenceUiStatus.failed);

  List<VerificationEvidence> get _uploadedEvidence => _rows
      .where(
        (_EvidenceRow row) =>
            row.evidence != null && row.status != _EvidenceUiStatus.failed,
      )
      .map((_EvidenceRow row) => row.evidence!)
      .toList(growable: false);

  bool get _busy =>
      _savingDraft || _submitting || _hasPendingUpload || _pickingEvidence;

  @override
  void dispose() {
    _legalName.dispose();
    _summary.dispose();
    super.dispose();
  }

  void _hydrateFromRequest(VerificationRequest request) {
    if (_hydratedDraft) {
      return;
    }
    _type = request.requestedType;
    if (_legalName.text.trim().isEmpty) {
      _legalName.text = request.legalName;
    }
    if (_summary.text.trim().isEmpty) {
      _summary.text = request.summary;
    }
    // Never wipe local uploads that completed before the draft snapshot arrived.
    if (_uploadedEvidence.isEmpty &&
        !_hasPendingUpload &&
        request.evidence.isNotEmpty) {
      _rows
        ..clear()
        ..addAll(
          request.evidence.map(
            (VerificationEvidence item) => _EvidenceRow(
              id: 'draft-${item.storagePath}',
              label: item.label,
              documentKind: item.documentKind,
              status: _EvidenceUiStatus.uploaded,
              filename: item.storagePath.split('/').last,
              sizeBytes: item.sizeBytes,
              evidence: item,
            ),
          ),
        );
    } else if (_uploadedEvidence.isEmpty && request.evidence.isNotEmpty) {
      for (final VerificationEvidence item in request.evidence) {
        final bool exists = _rows.any(
          (_EvidenceRow row) => row.evidence?.storagePath == item.storagePath,
        );
        if (!exists) {
          _rows.add(
            _EvidenceRow(
              id: 'draft-${item.storagePath}',
              label: item.label,
              documentKind: item.documentKind,
              status: _EvidenceUiStatus.uploaded,
              filename: item.storagePath.split('/').last,
              sizeBytes: item.sizeBytes,
              evidence: item,
            ),
          );
        }
      }
    }
    _hydratedDraft = true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentAuthUserProvider);
    final UserProfile? profile = ref.watch(currentUserProfileProvider).value;
    final AsyncValue<VerificationRequest?> requestValue = ref.watch(
      currentVerificationRequestProvider,
    );
    final bool actionLoading = ref
        .watch(profileActionControllerProvider)
        .isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile verification')),
      body: requestValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text('$error')),
        data: (VerificationRequest? request) {
          if (profile?.isVerified == true) {
            return AdaptivePageBody(
              maxWidth: 720,
              slivers: <Widget>[
                PremiumSurface(
                  child: Column(
                    children: <Widget>[
                      Icon(
                        Icons.verified_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Verified ${profile!.profileLabel}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Your verification badge is active. ReeMove may review '
                        'verified profiles again if identity details change.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final bool showStatus =
              request != null &&
              !_resubmitting &&
              request.status != VerificationRequestStatus.canceled &&
              request.status != VerificationRequestStatus.draft;

          if (showStatus) {
            return _RequestStatus(
              request: request,
              canceling: actionLoading,
              onCancel: request.status == VerificationRequestStatus.pending
                  ? () => _cancel(request)
                  : null,
              onSubmitAgain:
                  request.status == VerificationRequestStatus.rejected
                  ? () {
                      _hydrateFromRequest(request);
                      setState(() => _resubmitting = true);
                    }
                  : null,
            );
          }

          if (request != null &&
              request.status == VerificationRequestStatus.draft &&
              !_hydratedDraft) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _hydratedDraft) {
                return;
              }
              setState(() => _hydrateFromRequest(request));
            });
          }

          return Form(
            key: _formKey,
            child: AdaptivePageBody(
              maxWidth: 720,
              slivers: <Widget>[
                PremiumSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Apply for a trusted badge',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Verification confirms authentic athletes, trainers, '
                        'and sports businesses. Upload PNG or JPEG evidence '
                        '(max 15 MB). PDF is not supported yet.',
                      ),
                      if (request?.status ==
                          VerificationRequestStatus.draft) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        AppStatusChip(
                          label: 'Draft saved',
                          icon: Icons.edit_note_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      DropdownButtonFormField<VerificationType>(
                        value: _type,
                        decoration: const InputDecoration(
                          labelText: 'Verification category',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const <DropdownMenuItem<VerificationType>>[
                          DropdownMenuItem<VerificationType>(
                            value: VerificationType.athlete,
                            child: Text('Athlete'),
                          ),
                          DropdownMenuItem<VerificationType>(
                            value: VerificationType.trainer,
                            child: Text('Trainer'),
                          ),
                          DropdownMenuItem<VerificationType>(
                            value: VerificationType.business,
                            child: Text('Sports business'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (VerificationType? value) {
                                if (value != null) {
                                  setState(() => _type = value);
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _legalName,
                        decoration: const InputDecoration(
                          labelText: 'Legal name or registered business name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        maxLength: 120,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 2) {
                            return 'Enter the legal identity shown in your evidence.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _summary,
                        decoration: const InputDecoration(
                          labelText: 'Why this profile should be verified',
                          alignLabelWithHint: true,
                        ),
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 1000,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 30) {
                            return 'Provide at least 30 characters of relevant context.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PremiumSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Private evidence',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Select a PNG or JPEG, then wait until status shows '
                        'Uploaded before submitting. Evidence stays private.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<VerificationDocumentKind>(
                        value: _documentKind,
                        decoration: const InputDecoration(
                          labelText: 'Document type for next upload',
                        ),
                        items:
                            const <DropdownMenuItem<VerificationDocumentKind>>[
                              DropdownMenuItem<VerificationDocumentKind>(
                                value: VerificationDocumentKind.identity,
                                child: Text('Identity'),
                              ),
                              DropdownMenuItem<VerificationDocumentKind>(
                                value: VerificationDocumentKind.certification,
                                child: Text('Certification'),
                              ),
                              DropdownMenuItem<VerificationDocumentKind>(
                                value: VerificationDocumentKind.registration,
                                child: Text('Business registration'),
                              ),
                              DropdownMenuItem<VerificationDocumentKind>(
                                value: VerificationDocumentKind.other,
                                child: Text('Other'),
                              ),
                            ],
                        onChanged: _busy
                            ? null
                            : (VerificationDocumentKind? value) {
                                if (value != null) {
                                  setState(() => _documentKind = value);
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final _EvidenceRow row in _rows)
                        _EvidenceTile(
                          row: row,
                          busy: _busy,
                          onRetry: () => _retryRow(row),
                          onCancelUpload: () => _cancelRowUpload(row),
                          onReplace: () => _replaceRow(row),
                          onRemove: () => _removeRow(row),
                        ),
                      OutlinedButton.icon(
                        onPressed: _busy || _rows.length >= 6
                            ? null
                            : _addEvidence,
                        icon: _pickingEvidence
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _pickingEvidence
                              ? 'Opening file picker…'
                              : _rows.isEmpty
                                  ? 'Upload evidence'
                                  : 'Add another file',
                        ),
                      ),
                      if (_hasFailedUpload) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Fix failed uploads (Retry or Remove) before submitting.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _saveDraft,
                  icon: _savingDraft
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save draft'),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _busy || _uploadedEvidence.isEmpty || _hasFailedUpload
                      ? null
                      : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit verification request'),
                ),
                if (_uploadedEvidence.isEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Submit stays disabled until at least one PNG/JPEG evidence file reaches Uploaded.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addEvidence() async {
    if (_busy) {
      return;
    }
    final String id =
        'local-${DateTime.now().microsecondsSinceEpoch}-${_rowSeq++}';
    final _EvidenceRow row = _EvidenceRow(
      id: id,
      label: 'Evidence',
      documentKind: _documentKind,
      status: _EvidenceUiStatus.choosingFile,
    );
    setState(() {
      _pickingEvidence = true;
      _rows.add(row);
    });

    final Result<ProfileImageSource?> picked = await ref
        .read(verificationEvidencePickerProvider)
        .pick(
          onPhaseChanged: (VerificationEvidencePickPhase phase) {
            if (!mounted) {
              return;
            }
            setState(() {
              row.status = switch (phase) {
                VerificationEvidencePickPhase.choosingFile =>
                  _EvidenceUiStatus.choosingFile,
                VerificationEvidencePickPhase.readingFile =>
                  _EvidenceUiStatus.readingFile,
                VerificationEvidencePickPhase.validating =>
                  _EvidenceUiStatus.validating,
              };
            });
          },
        );
    if (!mounted) {
      return;
    }
    setState(() => _pickingEvidence = false);

    final ProfileImageSource? source = picked.when<ProfileImageSource?>(
      success: (ProfileImageSource? value) => value,
      failure: (Failure failure) {
        setState(() {
          row.status = _EvidenceUiStatus.failed;
          row.error = failure.message;
        });
        _show(failure.message);
        return null;
      },
    );
    if (source == null) {
      if (picked is Success<ProfileImageSource?>) {
        setState(() => _rows.removeWhere((_EvidenceRow item) => item.id == row.id));
      _show('No file was selected.');
      }
      return;
    }

    final String defaultLabel = source.filename.trim().isEmpty
        ? 'Evidence'
        : source.filename.trim();
      setState(() {
      row.label = defaultLabel;
      row.filename = source.filename;
      row.sizeBytes = source.bytes.lengthInBytes;
      row.source = source;
      row.status = _EvidenceUiStatus.selected;
      row.error = null;
    });

    final String? label = await _askLabel(defaultLabel);
    if (!mounted) {
      return;
    }
    if (label == null) {
      setState(() {
        row.status = _EvidenceUiStatus.cancelled;
        row.error = 'Upload canceled before evidence was attached.';
      });
      _show('Upload canceled before evidence was attached.');
      return;
    }
    if (label.trim().isEmpty) {
      setState(() {
        row.status = _EvidenceUiStatus.failed;
        row.error = 'Enter a short description for this evidence file.';
      });
      _show('Enter a short description for this evidence file.');
      return;
    }
    row.label = label.trim();
    setState(() => row.status = _EvidenceUiStatus.selecting);
    await _uploadRow(row);
  }

  Future<void> _retryRow(_EvidenceRow row) async {
    if (row.source == null) {
      _show('Choose Replace to pick the file again.');
      return;
    }
    await _uploadRow(row);
  }

  Future<void> _cancelRowUpload(_EvidenceRow row) async {
    final Future<bool> Function()? cancel = row.cancelUpload;
    if (cancel == null) {
      return;
    }
    final bool canceled = await cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      row.status = _EvidenceUiStatus.failed;
      row.error = canceled
          ? 'Upload canceled by you. Tap Retry to continue.'
          : 'Could not cancel this upload. Tap Retry.';
      row.cancelUpload = null;
    });
    _show(canceled ? 'Upload canceled.' : 'Unable to cancel upload.');
  }

  Future<void> _replaceRow(_EvidenceRow row) async {
    setState(() {
      row.status = _EvidenceUiStatus.choosingFile;
      row.error = null;
      row.evidence = null;
    });
    final Result<ProfileImageSource?> picked = await ref
        .read(verificationEvidencePickerProvider)
        .pick(
          onPhaseChanged: (VerificationEvidencePickPhase phase) {
            if (!mounted) {
              return;
            }
            setState(() {
              row.status = switch (phase) {
                VerificationEvidencePickPhase.choosingFile =>
                  _EvidenceUiStatus.choosingFile,
                VerificationEvidencePickPhase.readingFile =>
                  _EvidenceUiStatus.readingFile,
                VerificationEvidencePickPhase.validating =>
                  _EvidenceUiStatus.validating,
              };
            });
          },
        );
    final ProfileImageSource? source = picked.when<ProfileImageSource?>(
      success: (ProfileImageSource? value) => value,
      failure: (Failure failure) {
        setState(() {
          row.status = _EvidenceUiStatus.failed;
          row.error = failure.message;
        });
        _show(failure.message);
        return null;
      },
    );
    if (source == null) {
      if (picked is Success<ProfileImageSource?>) {
        setState(() {
          row.status = _EvidenceUiStatus.cancelled;
          row.error = 'Replace canceled — previous file kept.';
        });
      }
      return;
    }
    final VerificationEvidence? previous = row.evidence;
    setState(() {
      row.source = source;
      row.filename = source.filename;
      row.sizeBytes = source.bytes.lengthInBytes;
      row.evidence = null;
      row.error = null;
      row.status = _EvidenceUiStatus.selecting;
    });
    await _uploadRow(row);
    if (previous != null &&
        row.evidence != null &&
        previous.storagePath != row.evidence!.storagePath) {
      final AuthUser? user = ref.read(currentAuthUserProvider).value;
      if (user != null) {
        await ref
            .read(verificationEvidenceRepositoryProvider)
            .delete(uid: user.uid, storagePath: previous.storagePath);
      }
    }
  }

  Future<void> _uploadRow(_EvidenceRow row) async {
    final ProfileImageSource? source = row.source;
    if (source == null) {
      return;
    }
    final String attemptId =
        'upload-${DateTime.now().microsecondsSinceEpoch}-${row.id}';
    final Stopwatch uploadWatch = Stopwatch()..start();
    StagingDiagnostics.log('VERIFICATION_UPLOAD_ATTEMPT', <String, Object?>{
      'attemptId': attemptId,
      'filename': source.filename,
      'sizeBytes': source.bytes.lengthInBytes,
      'declaredContentType': source.contentType,
      'documentKind': row.documentKind.name,
    });
    final Stopwatch validationWatch = Stopwatch()..start();
    final Failure? validation = VerificationEvidenceValidator.validateSource(
      source,
    );
    validationWatch.stop();
    StagingDiagnostics.log('VERIFICATION_UPLOAD_VALIDATE', <String, Object?>{
      'attemptId': attemptId,
      'elapsedMs': validationWatch.elapsedMilliseconds,
      'result': validation == null ? 'ok' : 'failed',
      'error': validation?.message,
    });
    if (validation != null) {
      setState(() {
        row.status = _EvidenceUiStatus.failed;
        row.error = validation.message;
      });
      _show(validation.message);
      return;
    }
    final AuthUser? user = ref.read(currentAuthUserProvider).value;
    if (user == null) {
      setState(() {
        row.status = _EvidenceUiStatus.failed;
        row.error = 'Sign in again to continue.';
      });
      _show(row.error!);
      return;
    }
    StagingDiagnostics.log('VERIFICATION_UPLOAD_AUTH', <String, Object?>{
      'attemptId': attemptId,
      'uid': user.uid,
    });
    setState(() {
      row.uploadAttemptId = attemptId;
      row.status = _EvidenceUiStatus.uploadingFile;
      row.progress = 0;
      row.bytesTransferred = 0;
      row.totalBytes = source.bytes.lengthInBytes;
      row.cancelUpload = null;
      row.error = null;
    });
    Result<VerificationEvidence> uploaded;
    try {
      uploaded = await ref
          .read(verificationEvidenceRepositoryProvider)
          .upload(
            uid: user.uid,
            label: row.label,
            source: source,
            documentKind: row.documentKind,
            onProgress: (double progress) {
              if (!mounted) {
                return;
              }
              setState(() => row.progress = progress);
            },
            onDetailedProgress: (VerificationUploadProgress progress) {
              if (!mounted) {
                return;
              }
              final int total = progress.totalBytes <= 0
                  ? source.bytes.lengthInBytes
                  : progress.totalBytes;
              setState(() {
                row.bytesTransferred = progress.bytesTransferred;
                row.totalBytes = total;
                row.progress =
                    total <= 0 ? 0 : progress.bytesTransferred / total;
              });
            },
            onRegisterCancel: (Future<bool> Function() cancel) {
              if (!mounted) {
                return;
              }
              setState(() => row.cancelUpload = cancel);
            },
          )
          .timeout(widget.uploadTimeout);
    } on TimeoutException catch (error) {
      uploaded = FailureResult<VerificationEvidence>(
        Failure(
          message:
              'Upload timed out after ${widget.uploadTimeout.inSeconds} seconds. Check connectivity and tap Retry.',
          code: 'profile/verification-upload-timeout',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    await uploaded.when<Future<void>>(
      success: (VerificationEvidence item) async {
        // Deduplicate by storage path.
        _rows.removeWhere(
          (_EvidenceRow other) =>
              other.id != row.id &&
              other.evidence?.storagePath == item.storagePath,
        );
        setState(() {
          row.evidence = item;
          row.status = _EvidenceUiStatus.savingEvidence;
          row.progress = 1;
          row.bytesTransferred = row.totalBytes;
          row.sizeBytes = item.sizeBytes;
          row.cancelUpload = null;
          row.error = null;
        });
        final Stopwatch draftWatch = Stopwatch()..start();
        StagingDiagnostics.log('VERIFICATION_UPLOAD_STORAGE_DONE', <String, Object?>{
          'attemptId': attemptId,
          'elapsedMs': uploadWatch.elapsedMilliseconds,
          'storagePath': item.storagePath,
        });
        final bool persisted = await _persistDraftQuietly();
        draftWatch.stop();
        StagingDiagnostics.log('VERIFICATION_UPLOAD_DRAFT_SAVE', <String, Object?>{
          'attemptId': attemptId,
          'elapsedMs': draftWatch.elapsedMilliseconds,
          'result': persisted ? 'ok' : 'failed',
          'error': persisted ? null : '${ref.read(profileActionControllerProvider).error}',
        });
        if (!mounted) {
          return;
        }
        setState(() {
          row.status = persisted ? _EvidenceUiStatus.uploaded : _EvidenceUiStatus.failed;
          if (!persisted) {
            row.error =
                'Storage upload finished, but draft save failed: ${ref.read(profileActionControllerProvider).error}';
          }
        });
        _show(
          persisted
              ? 'Evidence uploaded and saved to your draft.'
              : 'Evidence uploaded, but draft save failed. Tap Retry to save again.',
        );
      },
      failure: (Failure failure) async {
        setState(() {
          row.status = _EvidenceUiStatus.failed;
          row.cancelUpload = null;
          final String debug = (failure.debugMessage ?? '').trim();
          row.error = debug.isEmpty
              ? failure.message
              : '${failure.message}\nDetails: $debug';
        });
        StagingDiagnostics.log('VERIFICATION_UPLOAD_FAILED', <String, Object?>{
          'attemptId': attemptId,
          'elapsedMs': uploadWatch.elapsedMilliseconds,
          'code': failure.code,
          'message': failure.message,
          'debug': failure.debugMessage,
        });
        _show(failure.message);
      },
    );
  }

  Future<void> _removeRow(_EvidenceRow row) async {
    final AuthUser? user = ref.read(currentAuthUserProvider).value;
    final VerificationEvidence? evidence = row.evidence;
    setState(() => _rows.removeWhere((_EvidenceRow item) => item.id == row.id));
    if (user != null && evidence != null) {
      await ref
          .read(verificationEvidenceRepositoryProvider)
          .delete(uid: user.uid, storagePath: evidence.storagePath);
    }
    await _persistDraftQuietly();
  }

  Future<String?> _askLabel(String initial) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => _EvidenceLabelDialog(initial: initial),
    );
  }

  VerificationSubmission _submission() => VerificationSubmission(
    requestedType: _type,
    legalName: _legalName.text.trim(),
    summary: _summary.text.trim(),
    evidence: List<VerificationEvidence>.unmodifiable(_uploadedEvidence),
  );

  Future<bool> _persistDraftQuietly() async {
    setState(() => _savingDraft = true);
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .saveVerificationDraft(_submission());
    if (mounted) {
      setState(() {
        _savingDraft = false;
        if (success) {
          _hydratedDraft = true;
        }
      });
    }
    return success;
  }

  Future<void> _saveDraft() async {
    if (_hasPendingUpload) {
      _show('Wait for uploads to finish before saving the draft.');
      return;
    }
    final bool success = await _persistDraftQuietly();
    if (!mounted) {
      return;
    }
    _show(
      success
          ? 'Draft saved.'
          : '${ref.read(profileActionControllerProvider).error}',
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_hasPendingUpload) {
      _show('Wait for evidence uploads to finish before submitting.');
      return;
    }
    if (_hasFailedUpload) {
      _show('Remove or retry failed evidence before submitting.');
      return;
    }
    if (_uploadedEvidence.isEmpty) {
      _show('Upload at least one private PNG or JPEG evidence file.');
      return;
    }
    setState(() => _submitting = true);
    // Authoritative persistence before submit so server and client agree.
    final bool draftSaved = await _persistDraftQuietly();
    if (!draftSaved) {
      if (mounted) {
        setState(() => _submitting = false);
        _show(
          'Could not save the draft before submit: '
          '${ref.read(profileActionControllerProvider).error}',
        );
      }
      return;
    }
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .submitVerification(_submission());
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      if (success) {
        _resubmitting = false;
      }
    });
    _show(
      success
          ? 'Your verification request was submitted.'
          : '${ref.read(profileActionControllerProvider).error}',
    );
  }

  Future<void> _cancel(VerificationRequest request) async {
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .cancelVerification(request.id);
    if (!mounted) {
      return;
    }
    _show(
      success
          ? 'Verification request canceled.'
          : '${ref.read(profileActionControllerProvider).error}',
    );
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EvidenceLabelDialog extends StatefulWidget {
  const _EvidenceLabelDialog({required this.initial});

  final String initial;

  @override
  State<_EvidenceLabelDialog> createState() => _EvidenceLabelDialogState();
}

class _EvidenceLabelDialogState extends State<_EvidenceLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Describe this evidence'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          hintText: 'Example: coaching certificate',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.row,
    required this.busy,
    required this.onRetry,
    required this.onCancelUpload,
    required this.onReplace,
    required this.onRemove,
  });

  final _EvidenceRow row;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onCancelUpload;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String sizeLabel = row.sizeBytes == null
        ? ''
        : ' · ${(row.sizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB';
    final String statusLabel = switch (row.status) {
      _EvidenceUiStatus.choosingFile => 'Choosing file',
      _EvidenceUiStatus.readingFile => 'Reading file',
      _EvidenceUiStatus.validating => 'Validating',
      _EvidenceUiStatus.selected => 'Selected',
      _EvidenceUiStatus.selecting => 'Selecting',
      _EvidenceUiStatus.uploadingFile =>
        'Uploading file ${(row.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
      _EvidenceUiStatus.savingEvidence => 'Saving evidence',
      _EvidenceUiStatus.uploaded => 'Uploaded',
      _EvidenceUiStatus.failed => 'Failed',
      _EvidenceUiStatus.cancelled => 'Cancelled',
    };
    final String transferred =
        row.totalBytes <= 0
            ? ''
            : '\nTransferred: ${row.bytesTransferred} / ${row.totalBytes} bytes';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (row.status) {
                _EvidenceUiStatus.uploaded => Icons.verified_user_outlined,
                _EvidenceUiStatus.failed => Icons.error_outline,
                _EvidenceUiStatus.cancelled => Icons.cancel_outlined,
                _EvidenceUiStatus.uploadingFile => Icons.cloud_upload_outlined,
                _EvidenceUiStatus.savingEvidence => Icons.save_outlined,
                _EvidenceUiStatus.validating => Icons.fact_check_outlined,
                _EvidenceUiStatus.choosingFile => Icons.folder_open_outlined,
                _EvidenceUiStatus.readingFile => Icons.file_download_outlined,
                _EvidenceUiStatus.selected => Icons.check_circle_outline,
                _EvidenceUiStatus.selecting => Icons.hourglass_top_rounded,
              }),
              title: Text(row.label),
              subtitle: Text(
                '${row.filename ?? 'evidence'} · ${row.documentKind.name}$sizeLabel\n'
                'Status: $statusLabel'
                '$transferred'
                '${row.error != null ? '\n${row.error}' : ''}',
              ),
              isThreeLine: true,
            ),
            if (row.status == _EvidenceUiStatus.choosingFile ||
                row.status == _EvidenceUiStatus.readingFile ||
                row.status == _EvidenceUiStatus.uploadingFile ||
                row.status == _EvidenceUiStatus.savingEvidence)
              LinearProgressIndicator(
                value: row.status == _EvidenceUiStatus.uploadingFile ||
                        row.status == _EvidenceUiStatus.savingEvidence
                    ? row.progress
                    : null,
              ),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                if (row.status == _EvidenceUiStatus.failed)
                  TextButton(onPressed: busy ? null : onRetry, child: const Text('Retry')),
                if (row.status == _EvidenceUiStatus.uploadingFile &&
                    row.cancelUpload != null)
                  TextButton(
                    key: const Key('evidence-cancel-upload'),
                    onPressed: onCancelUpload,
                    child: const Text('Cancel'),
                  ),
                TextButton(
                  onPressed: busy ? null : onReplace,
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: busy ? null : onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestStatus extends StatelessWidget {
  const _RequestStatus({
    required this.request,
    required this.canceling,
    this.onCancel,
    this.onSubmitAgain,
  });

  final VerificationRequest request;
  final bool canceling;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmitAgain;

  @override
  Widget build(BuildContext context) {
    final String status = request.status.name;
    return AdaptivePageBody(
      maxWidth: 720,
      slivers: <Widget>[
        PremiumSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: AppStatusChip(
                  label: status,
                  icon: _statusIcon(request.status),
                  color: _statusColor(context, request.status),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _title(request.status),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(_message(request)),
              const SizedBox(height: AppSpacing.lg),
              Text('Requested category: ${request.requestedType.name}'),
              Text('Evidence files: ${request.evidence.length}'),
              if (request.rejectionReason != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Review note',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(request.rejectionReason!),
              ],
              if (onCancel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: canceling ? null : onCancel,
                  child: const Text('Cancel request'),
                ),
              ],
              if (onSubmitAgain != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: onSubmitAgain,
                  child: const Text('Prepare an updated request'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _title(VerificationRequestStatus status) => switch (status) {
    VerificationRequestStatus.pending => 'Your request is under review',
    VerificationRequestStatus.approved => 'Verification approved',
    VerificationRequestStatus.rejected => 'More evidence is needed',
    VerificationRequestStatus.canceled => 'Request canceled',
    VerificationRequestStatus.draft => 'Verification draft',
  };

  static String _message(
    VerificationRequest request,
  ) => switch (request.status) {
    VerificationRequestStatus.pending =>
      'The review team will evaluate the identity and relevance evidence. '
          'Do not upload additional sensitive material unless requested.',
    VerificationRequestStatus.approved =>
      'The badge will appear after your profile and authentication claims refresh.',
    VerificationRequestStatus.rejected =>
      'Read the review note before preparing updated evidence.',
    VerificationRequestStatus.canceled =>
      'This request is no longer being reviewed.',
    VerificationRequestStatus.draft =>
      'Complete the evidence package before submitting.',
  };

  static IconData _statusIcon(VerificationRequestStatus status) =>
      switch (status) {
        VerificationRequestStatus.pending => Icons.hourglass_top_rounded,
        VerificationRequestStatus.approved => Icons.verified_rounded,
        VerificationRequestStatus.rejected => Icons.info_outline_rounded,
        VerificationRequestStatus.canceled => Icons.cancel_outlined,
        VerificationRequestStatus.draft => Icons.edit_note_rounded,
      };

  static Color _statusColor(
    BuildContext context,
    VerificationRequestStatus status,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return switch (status) {
      VerificationRequestStatus.approved => colors.primary,
      VerificationRequestStatus.rejected => colors.error,
      VerificationRequestStatus.pending => colors.tertiary,
      VerificationRequestStatus.canceled => colors.outline,
      VerificationRequestStatus.draft => colors.secondary,
    };
  }
}
