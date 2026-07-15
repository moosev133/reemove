import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_error_view.dart';
import '../../features/authentication/application/authentication_providers.dart';
import '../../features/authentication/domain/entities/auth_routing_state.dart';
import '../../features/authentication/presentation/screens/account_blocked_screen.dart';
import '../../features/authentication/presentation/screens/account_security_screen.dart';
import '../../features/authentication/presentation/screens/auth_unavailable_screen.dart';
import '../../features/authentication/presentation/screens/auth_welcome_screen.dart';
import '../../features/authentication/presentation/screens/authenticated_home_handoff_screen.dart';
import '../../features/authentication/presentation/screens/email_verification_screen.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/sign_in_screen.dart';
import '../../features/authentication/presentation/screens/sign_up_screen.dart';
import '../../features/authentication/presentation/screens/username_setup_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../../features/startup/presentation/screens/startup_screen.dart';
import 'app_routes.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshNotifier refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      return _redirect(ref, state.matchedLocation);
    },
    routes: <RouteBase>[
      _route(
        path: AppRoutes.startup,
        name: AppRouteNames.startup,
        child: const StartupScreen(),
      ),
      _route(
        path: AppRoutes.authUnavailable,
        name: AppRouteNames.authUnavailable,
        child: const AuthUnavailableScreen(),
      ),
      _route(
        path: AppRoutes.authWelcome,
        name: AppRouteNames.authWelcome,
        child: const AuthWelcomeScreen(),
      ),
      _route(
        path: AppRoutes.signIn,
        name: AppRouteNames.signIn,
        child: const SignInScreen(),
      ),
      _route(
        path: AppRoutes.signUp,
        name: AppRouteNames.signUp,
        child: const SignUpScreen(),
      ),
      _route(
        path: AppRoutes.forgotPassword,
        name: AppRouteNames.forgotPassword,
        child: const ForgotPasswordScreen(),
      ),
      _route(
        path: AppRoutes.verifyEmail,
        name: AppRouteNames.verifyEmail,
        child: const EmailVerificationScreen(),
      ),
      _route(
        path: AppRoutes.usernameSetup,
        name: AppRouteNames.usernameSetup,
        child: const UsernameSetupScreen(),
      ),
      _route(
        path: AppRoutes.accountBlocked,
        name: AppRouteNames.accountBlocked,
        child: const AccountBlockedScreen(),
      ),
      _route(
        path: AppRoutes.onboarding,
        name: AppRouteNames.onboarding,
        child: const OnboardingFlowScreen(),
      ),
      _route(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        child: const AuthenticatedHomeHandoffScreen(),
      ),
      _route(
        path: AppRoutes.accountSecurity,
        name: AppRouteNames.accountSecurity,
        child: const AccountSecurityScreen(),
      ),
    ],
    errorPageBuilder: (BuildContext context, GoRouterState state) {
      return MaterialPage<void>(
        child: AppErrorView(
          title: 'This route is unavailable',
          message:
              state.error?.toString() ??
              'The requested destination could not be opened.',
          actionLabel: 'Return to ReeMove',
          onAction: () => context.go(AppRoutes.startup),
        ),
      );
    },
  );
});

GoRoute _route({
  required String path,
  required String name,
  required Widget child,
}) {
  return GoRoute(
    path: path,
    name: name,
    pageBuilder: (BuildContext context, GoRouterState state) {
      return NoTransitionPage<void>(child: child);
    },
  );
}

String? _redirect(Ref ref, String location) {
  final AsyncValue<AuthRoutingState> routing = ref.read(
    authRoutingStateProvider,
  );
  if (routing.isLoading || routing.hasError) {
    return location == AppRoutes.startup ? null : AppRoutes.startup;
  }

  final AuthDestination destination = routing.requireValue.destination;
  final Set<String> signedOutRoutes = <String>{
    AppRoutes.authWelcome,
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.forgotPassword,
  };

  return switch (destination) {
    AuthDestination.configurationRequired =>
      location == AppRoutes.authUnavailable ? null : AppRoutes.authUnavailable,
    AuthDestination.loading =>
      location == AppRoutes.startup ? null : AppRoutes.startup,
    AuthDestination.signedOut =>
      signedOutRoutes.contains(location) ? null : AppRoutes.authWelcome,
    AuthDestination.profileRequired =>
      location == AppRoutes.usernameSetup ? null : AppRoutes.usernameSetup,
    AuthDestination.emailVerificationRequired =>
      location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail,
    AuthDestination.onboardingRequired =>
      location == AppRoutes.onboarding || location == AppRoutes.accountSecurity
          ? null
          : AppRoutes.onboarding,
    AuthDestination.ready =>
      location == AppRoutes.home || location == AppRoutes.accountSecurity
          ? null
          : AppRoutes.home,
    AuthDestination.blocked =>
      location == AppRoutes.accountBlocked ? null : AppRoutes.accountBlocked,
  };
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthRoutingState>>(authRoutingStateProvider, (
      AsyncValue<AuthRoutingState>? previous,
      AsyncValue<AuthRoutingState> next,
    ) {
      notifyListeners();
    });
  }
}
