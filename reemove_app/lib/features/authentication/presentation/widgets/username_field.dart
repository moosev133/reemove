import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../application/authentication_providers.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/value_objects/auth_validators.dart';

class UsernameField extends ConsumerStatefulWidget {
  const UsernameField({
    required this.controller,
    super.key,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  ConsumerState<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends ConsumerState<UsernameField> {
  Timer? _debounce;
  UsernameAvailability? _availability;
  Object? _error;
  bool _checking = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant UsernameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final int version = ++_requestVersion;
    final String username = widget.controller.text;
    final String? validation = AuthValidators.username(username);
    setState(() {
      _availability = null;
      _error = null;
      _checking = false;
    });
    if (validation != null) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_check(username, version));
    });
  }

  Future<void> _check(String username, int version) async {
    setState(() => _checking = true);
    final Result<UsernameAvailability> result = await ref
        .read(usernameRepositoryProvider)
        .checkAvailability(username);
    if (!mounted || version != _requestVersion) {
      return;
    }
    result.when<void>(
      success: (UsernameAvailability availability) {
        setState(() {
          _checking = false;
          _availability = availability;
          _error = null;
        });
      },
      failure: (Failure failure) {
        setState(() {
          _checking = false;
          _availability = null;
          _error = failure;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool? available = _availability == null
        ? null
        : _availability!.state == UsernameAvailabilityState.available;
    final Color statusColor = available == true
        ? AppColors.success
        : available == false
        ? AppColors.danger
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const <String>[AutofillHints.username],
          validator: AuthValidators.username,
          decoration: InputDecoration(
            labelText: 'Username',
            hintText: 'your.username',
            prefixText: '@',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : available == null
                ? null
                : Icon(
                    available
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: statusColor,
                  ),
          ),
        ),
        if (_availability != null || _error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error is Failure
                ? (_error! as Failure).message
                : available == true
                ? '@${_availability!.normalizedUsername} is available.'
                : _availability!.message ?? 'That username is unavailable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _error != null ? AppColors.danger : statusColor,
            ),
          ),
        ],
      ],
    );
  }
}
