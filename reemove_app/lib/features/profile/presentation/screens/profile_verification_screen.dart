import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
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

class ProfileVerificationScreen extends ConsumerStatefulWidget {
  const ProfileVerificationScreen({super.key});

  @override
  ConsumerState<ProfileVerificationScreen> createState() =>
      _ProfileVerificationScreenState();
}

class _ProfileVerificationScreenState
    extends ConsumerState<ProfileVerificationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _legalName = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final List<VerificationEvidence> _evidence = <VerificationEvidence>[];
  VerificationType _type = VerificationType.athlete;
  bool _uploading = false;
  bool _resubmitting = false;

  @override
  void dispose() {
    _legalName.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile? profile = ref.watch(currentUserProfileProvider).value;
    final AsyncValue<VerificationRequest?> requestValue = ref.watch(
      currentVerificationRequestProvider,
    );
    final bool saving = ref.watch(profileActionControllerProvider).isLoading;
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
          if (request != null &&
              request.status != VerificationRequestStatus.canceled &&
              !_resubmitting) {
            return _RequestStatus(
              request: request,
              canceling: saving,
              onCancel: request.status == VerificationRequestStatus.pending
                  ? () => _cancel(request)
                  : null,
              onSubmitAgain:
                  request.status == VerificationRequestStatus.rejected
                  ? () {
                      _type = request.requestedType;
                      _legalName.text = request.legalName;
                      _summary.text = request.summary;
                      setState(() => _resubmitting = true);
                    }
                  : null,
            );
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
                        'and sports businesses. A badge never guarantees skills '
                        'or commercial claims.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DropdownButtonFormField<VerificationType>(
                        initialValue: _type,
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
                        onChanged: (VerificationType? value) {
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
                        'Upload a clear image of relevant identity, certification, '
                        'competition, employment, or business-registration evidence. '
                        'Evidence is private and only available to authorized reviewers.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final VerificationEvidence item in _evidence)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: Text(item.label),
                          subtitle: const Text('Uploaded securely'),
                          trailing: IconButton(
                            tooltip: 'Remove from request',
                            onPressed: _uploading
                                ? null
                                : () => _removeEvidence(item),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _uploading || _evidence.length >= 6
                            ? null
                            : _addEvidence,
                        icon: _uploading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _evidence.isEmpty
                              ? 'Upload evidence'
                              : 'Add another file',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: saving || _uploading ? null : _submit,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit verification request'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addEvidence() async {
    final Result<ProfileImageSource?> picked = await ref
        .read(profileImagePickerProvider)
        .pick(ProfileImageKind.cover);
    final ProfileImageSource? source = picked.when<ProfileImageSource?>(
      success: (ProfileImageSource? value) => value,
      failure: (Failure failure) {
        _show(failure.message);
        return null;
      },
    );
    if (source == null) {
      return;
    }
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      _show('Sign in again to continue.');
      return;
    }
    final String? label = await _askLabel();
    if (label == null || label.trim().isEmpty) {
      return;
    }
    setState(() => _uploading = true);
    final Result<VerificationEvidence> uploaded = await ref
        .read(verificationEvidenceRepositoryProvider)
        .upload(uid: user.uid, label: label.trim(), source: source);
    if (!mounted) {
      return;
    }
    uploaded.when<void>(
      success: (VerificationEvidence item) {
        setState(() {
          _evidence.add(item);
          _uploading = false;
        });
      },
      failure: (Failure failure) {
        setState(() => _uploading = false);
        _show(failure.message);
      },
    );
  }

  Future<void> _removeEvidence(VerificationEvidence item) async {
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      _show('Sign in again to continue.');
      return;
    }
    setState(() => _uploading = true);
    final Result<void> removed = await ref
        .read(verificationEvidenceRepositoryProvider)
        .delete(uid: user.uid, storagePath: item.storagePath);
    if (!mounted) {
      return;
    }
    removed.when<void>(
      success: (_) {
        setState(() {
          _evidence.remove(item);
          _uploading = false;
        });
      },
      failure: (Failure failure) {
        setState(() => _uploading = false);
        _show(failure.message);
      },
    );
  }

  Future<String?> _askLabel() async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Describe this evidence'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_evidence.isEmpty) {
      _show('Upload at least one private evidence file.');
      return;
    }
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .submitVerification(
          VerificationSubmission(
            requestedType: _type,
            legalName: _legalName.text.trim(),
            summary: _summary.text.trim(),
            evidence: List<VerificationEvidence>.unmodifiable(_evidence),
          ),
        );
    if (!mounted) {
      return;
    }
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
