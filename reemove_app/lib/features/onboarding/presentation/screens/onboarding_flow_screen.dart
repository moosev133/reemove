import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/presentation/widgets/auth_feedback.dart';
import '../../application/onboarding_providers.dart';
import '../../application/onboarding_view_state.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../widgets/onboarding_navigation.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_step_content.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  bool _checkedLostAvatar = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OnboardingViewState> state = ref.watch(
      onboardingControllerProvider,
    );
    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: AppErrorView(
          title: 'Onboarding could not load',
          message: error.toString(),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(onboardingControllerProvider),
        ),
      ),
      data: (OnboardingViewState value) {
        if (!_checkedLostAvatar) {
          _checkedLostAvatar = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              ref
                  .read(onboardingControllerProvider.notifier)
                  .recoverLostAvatar(),
            );
          });
        }
        final OnboardingController controller = ref.read(
          onboardingControllerProvider.notifier,
        );
        return OnboardingScaffold(
          step: value.draft.currentStep,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (value.failure != null) ...<Widget>[
                AuthErrorBanner(error: value.failure!),
                const SizedBox(height: AppSpacing.lg),
              ],
              OnboardingStepContent(
                viewState: value,
                controller: controller,
                onChooseAvatar: () => _showAvatarSource(controller),
              ),
            ],
          ),
          navigation: OnboardingNavigation(
            step: value.draft.currentStep,
            busy: value.isBusy,
            onBack: controller.goBack,
            onContinue: value.draft.currentStep == OnboardingStep.review
                ? controller.complete
                : controller.continueToNextStep,
          ),
        );
      },
    );
  }

  Future<void> _showAvatarSource(OnboardingController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Choose profile photo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Photo library'),
                  subtitle: const Text('Choose an existing image'),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(controller.chooseAvatar(camera: false));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a new photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(controller.chooseAvatar(camera: true));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
