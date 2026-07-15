import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/premium_surface.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../application/profile_providers.dart';
import '../../domain/entities/profile_edit_request.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/entities/profile_privacy_settings.dart';
import '../../domain/entities/user_profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _website = TextEditingController();
  final TextEditingController _goals = TextEditingController();
  final TextEditingController _headline = TextEditingController();
  final TextEditingController _organization = TextEditingController();
  final TextEditingController _position = TextEditingController();
  final TextEditingController _experience = TextEditingController();
  final TextEditingController _specialties = TextEditingController();

  bool _initialized = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;
  String? _avatarUrl;
  String? _avatarStoragePath;
  String? _coverUrl;
  String? _coverStoragePath;
  String? _primarySportId;
  Visibility _visibility = Visibility.public;
  bool _acceptingClients = false;

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    _website.dispose();
    _goals.dispose();
    _headline.dispose();
    _organization.dispose();
    _position.dispose();
    _experience.dispose();
    _specialties.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile?> profileValue = ref.watch(
      currentUserProfileProvider,
    );
    final AsyncValue<ProfilePrivacySettings> privacyValue = ref.watch(
      profilePrivacySettingsProvider,
    );
    final bool saving = ref.watch(profileActionControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: <Widget>[
          TextButton(
            onPressed: saving || _uploadingAvatar || _uploadingCover
                ? null
                : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: profileValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text('$error')),
        data: (UserProfile? profile) {
          if (profile == null) {
            return const SizedBox.shrink();
          }
          final ProfilePrivacySettings privacy =
              privacyValue.value ?? ProfilePrivacySettings.defaults();
          _initialize(profile);
          return Form(
            key: _formKey,
            child: AdaptivePageBody(
              maxWidth: 760,
              slivers: <Widget>[
                _ImageEditor(
                  profile: profile,
                  avatarUrl: _avatarUrl,
                  coverUrl: _coverUrl,
                  uploadingAvatar: _uploadingAvatar,
                  uploadingCover: _uploadingCover,
                  onAvatar: () => _pickImage(ProfileImageKind.avatar),
                  onCover: () => _pickImage(ProfileImageKind.cover),
                ),
                const SizedBox(height: AppSpacing.lg),
                PremiumSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Public identity',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _displayName,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        maxLength: 80,
                        validator: _required,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixText: '@',
                          helperText: 'Can be changed once every 14 days.',
                        ),
                        maxLength: 30,
                        autocorrect: false,
                        validator: (String? value) {
                          final String candidate = value?.trim() ?? '';
                          if (!RegExp(
                            r'^[a-zA-Z0-9._]{3,30}$',
                          ).hasMatch(candidate)) {
                            return 'Use 3–30 letters, numbers, dots, or underscores.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _bio,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          alignLabelWithHint: true,
                        ),
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _website,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          hintText: 'https://example.com',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (String? value) {
                          final String candidate = value?.trim() ?? '';
                          if (candidate.isEmpty) {
                            return null;
                          }
                          final Uri? uri = Uri.tryParse(candidate);
                          return uri?.scheme == 'https' &&
                                  uri?.host.isNotEmpty == true
                              ? null
                              : 'Enter an HTTPS website URL.';
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
                        'Sports profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String?>(
                        initialValue: _primarySportId,
                        decoration: const InputDecoration(
                          labelText: 'Primary sport',
                          prefixIcon: Icon(Icons.sports_rounded),
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No primary sport'),
                          ),
                          ...profile.favoriteSportIds.map(
                            (String sport) => DropdownMenuItem<String?>(
                              value: sport,
                              child: Text(_humanize(sport)),
                            ),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() => _primarySportId = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _goals,
                        decoration: const InputDecoration(
                          labelText: 'Goals',
                          helperText: 'Separate goals with commas.',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        maxLength: 500,
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
                        profile.role == UserRole.athlete
                            ? 'Athlete details'
                            : '${profile.profileLabel} details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _headline,
                        decoration: const InputDecoration(
                          labelText: 'Headline',
                          hintText: 'Strength coach · Football performance',
                        ),
                        maxLength: 120,
                      ),
                      TextFormField(
                        controller: _organization,
                        decoration: const InputDecoration(
                          labelText: 'Team, gym, or organization',
                        ),
                        maxLength: 120,
                      ),
                      TextFormField(
                        controller: _position,
                        decoration: const InputDecoration(
                          labelText: 'Position or category',
                        ),
                        maxLength: 100,
                      ),
                      TextFormField(
                        controller: _experience,
                        decoration: const InputDecoration(
                          labelText: 'Years of experience',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: _specialties,
                        decoration: const InputDecoration(
                          labelText: 'Specialties',
                          helperText: 'Separate specialties with commas.',
                        ),
                        maxLength: 500,
                      ),
                      if (profile.role == UserRole.trainer)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _acceptingClients,
                          onChanged: (bool value) {
                            setState(() => _acceptingClients = value);
                          },
                          title: const Text('Accepting new clients'),
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
                        'Profile visibility',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<Visibility>(
                        initialValue: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Who can view your profile',
                          prefixIcon: Icon(Icons.visibility_outlined),
                        ),
                        items: const <DropdownMenuItem<Visibility>>[
                          DropdownMenuItem<Visibility>(
                            value: Visibility.public,
                            child: Text('Public'),
                          ),
                          DropdownMenuItem<Visibility>(
                            value: Visibility.followers,
                            child: Text('Approved followers'),
                          ),
                          DropdownMenuItem<Visibility>(
                            value: Visibility.private,
                            child: Text('Private'),
                          ),
                        ],
                        onChanged: (Visibility? value) {
                          if (value != null) {
                            setState(() => _visibility = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        privacy.followApprovalPolicy ==
                                FollowApprovalPolicy.approvalRequired
                            ? 'New followers currently require approval.'
                            : 'Public profiles can accept followers automatically.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: saving || _uploadingAvatar || _uploadingCover
                      ? null
                      : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Save profile'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _initialize(UserProfile profile) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _displayName.text = profile.displayName;
    _username.text = profile.username;
    _bio.text = profile.bio;
    _website.text = profile.websiteUrl ?? '';
    _goals.text = profile.goals.join(', ');
    _headline.text = profile.professionalDetails.headline ?? '';
    _organization.text = profile.professionalDetails.organization ?? '';
    _position.text = profile.professionalDetails.positionOrCategory ?? '';
    _experience.text =
        profile.professionalDetails.yearsExperience?.toString() ?? '';
    _specialties.text = profile.professionalDetails.specialties.join(', ');
    _acceptingClients = profile.professionalDetails.acceptingClients;
    _avatarUrl = profile.avatarUrl;
    _coverUrl = profile.coverUrl;
    _primarySportId = profile.primarySportId;
    _visibility = profile.visibility;
  }

  Future<void> _pickImage(ProfileImageKind kind) async {
    final Result<ProfileImageSource?> picked = await ref
        .read(profileImagePickerProvider)
        .pick(kind);
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
    setState(() {
      if (kind == ProfileImageKind.avatar) {
        _uploadingAvatar = true;
      } else {
        _uploadingCover = true;
      }
    });
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
          _uploadingCover = false;
        });
      }
      _show('Sign in again to continue.');
      return;
    }
    final Result<ProfileImageAsset> uploaded = await ref
        .read(profileImageRepositoryProvider)
        .upload(
          uid: user.uid,
          kind: kind,
          source: source,
          previousStoragePath: kind == ProfileImageKind.avatar
              ? _avatarStoragePath
              : _coverStoragePath,
        );
    if (!mounted) {
      return;
    }
    uploaded.when<void>(
      success: (ProfileImageAsset asset) {
        setState(() {
          if (kind == ProfileImageKind.avatar) {
            _avatarUrl = asset.downloadUrl;
            _avatarStoragePath = asset.storagePath;
            _uploadingAvatar = false;
          } else {
            _coverUrl = asset.downloadUrl;
            _coverStoragePath = asset.storagePath;
            _uploadingCover = false;
          }
        });
      },
      failure: (Failure failure) {
        setState(() {
          _uploadingAvatar = false;
          _uploadingCover = false;
        });
        _show(failure.message);
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final UserProfile? profile = ref.read(currentUserProfileProvider).value;
    final ProfilePrivacySettings privacy =
        ref.read(profilePrivacySettingsProvider).value ??
        ProfilePrivacySettings.defaults();
    if (profile == null) {
      return;
    }
    final int? experience = int.tryParse(_experience.text.trim());
    final ProfileEditRequest request = ProfileEditRequest(
      displayName: _displayName.text.trim(),
      username: _username.text.trim(),
      bio: _bio.text.trim(),
      avatarUrl: _avatarUrl,
      avatarStoragePath: _avatarStoragePath,
      coverUrl: _coverUrl,
      coverStoragePath: _coverStoragePath,
      websiteUrl: _emptyToNull(_website.text),
      primarySportId: _primarySportId,
      favoriteSportIds: profile.favoriteSportIds,
      goals: _commaValues(_goals.text),
      visibility: _visibility.storageValue,
      privacy: privacy.copyWith(
        followApprovalPolicy: _visibility == Visibility.public
            ? privacy.followApprovalPolicy
            : FollowApprovalPolicy.approvalRequired,
      ),
      professional: ProfessionalProfileInput(
        headline: _emptyToNull(_headline.text),
        organization: _emptyToNull(_organization.text),
        positionOrCategory: _emptyToNull(_position.text),
        yearsExperience: experience,
        specialties: _commaValues(_specialties.text),
        acceptingClients: _acceptingClients,
      ),
    );
    final bool success = await ref
        .read(profileActionControllerProvider.notifier)
        .updateProfile(request);
    if (!mounted) {
      return;
    }
    if (success) {
      context.pop();
    } else {
      _show('${ref.read(profileActionControllerProvider).error}');
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  static String? _emptyToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _commaValues(String value) => value
      .split(',')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  void _show(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ImageEditor extends StatelessWidget {
  const _ImageEditor({
    required this.profile,
    required this.avatarUrl,
    required this.coverUrl,
    required this.uploadingAvatar,
    required this.uploadingCover,
    required this.onAvatar,
    required this.onCover,
  });

  final UserProfile profile;
  final String? avatarUrl;
  final String? coverUrl;
  final bool uploadingAvatar;
  final bool uploadingCover;
  final VoidCallback onAvatar;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return PremiumSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  coverUrl == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                colors.primaryContainer,
                                colors.secondaryContainer,
                              ],
                            ),
                          ),
                        )
                      : Image.network(
                          coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: colors.surfaceContainerHighest),
                        ),
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: FilledButton.tonalIcon(
                      onPressed: uploadingCover ? null : onCover,
                      icon: uploadingCover
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cover'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      AppAvatar(
                        displayName: profile.displayName,
                        imageUrl: avatarUrl,
                        radius: 46,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: 'Change profile photo',
                          onPressed: uploadingAvatar ? null : onAvatar,
                          icon: uploadingAvatar
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.edit_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  const Expanded(
                    child: Text(
                      'Use a clear profile image and a cover that represents your sport, team, or business.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _humanize(String value) => value
    .replaceAll(RegExp(r'[-_]'), ' ')
    .split(RegExp(r'\s+'))
    .where((String item) => item.isNotEmpty)
    .map((String item) => '${item[0].toUpperCase()}${item.substring(1)}')
    .join(' ');
