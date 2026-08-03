import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../application/groups_providers.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_enums.dart';
import '../../domain/entities/group_location.dart';
import '../../domain/entities/group_requests.dart';
import '../widgets/group_membership_badge.dart';

/// Handles both creating a new group and editing an existing one.
///
/// When [groupId] is null the screen is in create mode; otherwise it loads
/// the existing group and submits an [UpdateGroupRequest] patch.
class CreateEditGroupScreen extends ConsumerStatefulWidget {
  const CreateEditGroupScreen({this.groupId, super.key});

  final String? groupId;

  bool get isEditing => groupId != null;

  @override
  ConsumerState<CreateEditGroupScreen> createState() =>
      _CreateEditGroupScreenState();
}

class _CreateEditGroupScreenState extends ConsumerState<CreateEditGroupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _locality = TextEditingController();
  final TextEditingController _countryCode = TextEditingController();
  final TextEditingController _capacity = TextEditingController(text: '0');
  final TextEditingController _avatarUrl = TextEditingController();
  GroupPrivacy _privacy = GroupPrivacy.public;
  GroupJoinPolicy _joinPolicy = GroupJoinPolicy.open;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _locality.dispose();
    _countryCode.dispose();
    _capacity.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> action = ref.watch(groupsActionControllerProvider);
    if (!widget.isEditing) {
      return _buildForm(context, action: action, existing: null);
    }
    final AsyncValue<Group> groupValue = ref.watch(
      groupProvider(widget.groupId!),
    );
    return groupValue.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => AppErrorView(
        title: 'Group could not load',
        message: error.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(groupProvider(widget.groupId!)),
      ),
      data: (Group group) {
        if (!_prefilled) {
          _prefilled = true;
          _name.text = group.name;
          _description.text = group.description;
          _category.text = group.category;
          _locality.text = group.location.locality ?? '';
          _countryCode.text = group.location.countryCode ?? '';
          _capacity.text = group.capacity.toString();
          _avatarUrl.text = group.avatarUrl ?? '';
          _privacy = group.privacy;
          _joinPolicy = group.joinPolicy;
        }
        return _buildForm(context, action: action, existing: group);
      },
    );
  }

  Widget _buildForm(
    BuildContext context, {
    required AsyncValue<void> action,
    required Group? existing,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit group' : 'Create group'),
      ),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: 'Groups',
            title: widget.isEditing ? 'Edit ${existing?.name ?? 'group'}' : 'Start a new group',
            subtitle:
                'Owners and admins manage membership, privacy, and the join policy.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Group name'),
                  maxLength: 80,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'football, running, hiking',
                  ),
                  maxLength: 64,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<GroupPrivacy>(
                  initialValue: _privacy,
                  decoration: const InputDecoration(labelText: 'Privacy'),
                  items: GroupPrivacy.values
                      .map(
                        (GroupPrivacy value) => DropdownMenuItem<GroupPrivacy>(
                          value: value,
                          child: Text(groupPrivacyLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (GroupPrivacy? value) => setState(() {
                    _privacy = value ?? _privacy;
                    if (_privacy == GroupPrivacy.hidden) {
                      _joinPolicy = GroupJoinPolicy.inviteOnly;
                    } else if (_privacy == GroupPrivacy.private &&
                        _joinPolicy == GroupJoinPolicy.open) {
                      _joinPolicy = GroupJoinPolicy.approvalRequired;
                    }
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<GroupJoinPolicy>(
                  initialValue: _joinPolicy,
                  decoration: const InputDecoration(labelText: 'Join policy'),
                  items: GroupJoinPolicy.values
                      .map(
                        (GroupJoinPolicy value) =>
                            DropdownMenuItem<GroupJoinPolicy>(
                              value: value,
                              child: Text(groupJoinPolicyLabel(value)),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: _privacy == GroupPrivacy.hidden
                      ? null
                      : (GroupJoinPolicy? value) =>
                            setState(() => _joinPolicy = value ?? _joinPolicy),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _locality,
                        decoration: const InputDecoration(
                          labelText: 'City (optional)',
                        ),
                        maxLength: 80,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _countryCode,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                        ),
                        maxLength: 2,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _capacity,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (0 = unlimited)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    final int? parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 0 || parsed > 10000) {
                      return 'Enter a capacity between 0 and 10000.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _avatarUrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar image URL (optional)',
                    hintText: 'https://…',
                  ),
                  maxLength: 2048,
                ),
                if (action.hasError) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    action.error.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: action.isLoading ? null : _submit,
                  icon: const Icon(Icons.groups_rounded),
                  label: Text(
                    action.isLoading
                        ? 'Saving…'
                        : widget.isEditing
                        ? 'Save changes'
                        : 'Create group',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final GroupLocation location = GroupLocation(
      locality: _locality.text.trim().isEmpty ? null : _locality.text.trim(),
      countryCode: _countryCode.text.trim().isEmpty
          ? null
          : _countryCode.text.trim().toUpperCase(),
    );
    final String? avatarUrl = _avatarUrl.text.trim().isEmpty
        ? null
        : _avatarUrl.text.trim();
    if (widget.isEditing) {
      final bool ok = await ref
          .read(groupsActionControllerProvider.notifier)
          .updateGroup(
            UpdateGroupRequest(
              groupId: widget.groupId!,
              name: _name.text.trim(),
              description: _description.text.trim(),
              category: _category.text.trim(),
              privacy: _privacy,
              joinPolicy: _joinPolicy,
              location: location,
              capacity: int.parse(_capacity.text.trim()),
              avatarUrl: avatarUrl,
            ),
          );
      if (!mounted || !ok) {
        return;
      }
      context.pop();
      return;
    }
    final String? id = await ref
        .read(groupsActionControllerProvider.notifier)
        .createGroup(
          CreateGroupRequest(
            name: _name.text.trim(),
            description: _description.text.trim(),
            category: _category.text.trim(),
            privacy: _privacy,
            joinPolicy: _joinPolicy,
            capacity: int.parse(_capacity.text.trim()),
            location: location,
            avatarUrl: avatarUrl,
          ),
        );
    if (!mounted || id == null) {
      return;
    }
    context.go(AppRoutes.groupDetail(id));
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}
