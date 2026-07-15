import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/reemove_logo.dart';
import '../../../authentication/application/authentication_providers.dart';
import '../../../authentication/domain/entities/auth_routing_state.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthRoutingState> routing = ref.watch(
      authRoutingStateProvider,
    );

    if (routing.hasError) {
      return AppErrorView(
        title: 'Something went wrong',
        message: routing.error.toString(),
        actionLabel: 'Try again',
        onAction: () {
          ref.invalidate(currentAuthUserProvider);
          ref.invalidate(currentUserProfileProvider);
          ref.invalidate(authRoutingStateProvider);
        },
      );
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.surface,
              scheme.primaryContainer.withValues(alpha: 0.42),
              scheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ReeMoveLogo(size: 72),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Move together.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.brandDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
