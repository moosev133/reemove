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
import '../../features/authentication/presentation/screens/email_verification_screen.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/sign_in_screen.dart';
import '../../features/authentication/presentation/screens/sign_up_screen.dart';
import '../../features/authentication/presentation/screens/username_setup_screen.dart';
import '../../features/create/presentation/screens/create_flow_screen.dart';
import '../../features/create/presentation/screens/create_screen.dart';
import '../../features/discover/presentation/screens/discover_category_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/discover/presentation/screens/discover_search_screen.dart';
import '../../features/home/presentation/screens/activity_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/post_deep_link_screen.dart';
import '../../features/messages/presentation/screens/conversation_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/public_profile_screen.dart';
import '../../features/sports/shared/presentation/screens/sport_hub_screen.dart';
import '../../features/sports/shared/presentation/screens/sports_screen.dart';
import '../../features/startup/presentation/screens/startup_screen.dart';
import '../navigation/app_shell.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'home',
);
final GlobalKey<NavigatorState> _discoverNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'discover');
final GlobalKey<NavigatorState> _sportsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sports',
);
final GlobalKey<NavigatorState> _createNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'create',
);
final GlobalKey<NavigatorState> _messagesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'messages');
final GlobalKey<NavigatorState> _profileNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profile');

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshNotifier refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.startup,
    restorationScopeId: 'reemove_router',
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) =>
        _redirect(ref, state),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.accountSecurity,
        name: AppRouteNames.accountSecurity,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            MaterialPage<void>(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const AccountSecurityScreen(),
            ),
      ),
      ..._aliasRoutes(),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        restorationScopeId: 'main_shell',
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return AppShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            restorationScopeId: 'home_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                name: AppRouteNames.home,
                pageBuilder: _page(const HomeScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'activity',
                    name: AppRouteNames.activity,
                    pageBuilder: _page(const ActivityScreen()),
                  ),
                  GoRoute(
                    path: 'post/:postId',
                    name: AppRouteNames.homePost,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: PostDeepLinkScreen(
                          postId: state.pathParameters['postId'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _discoverNavigatorKey,
            restorationScopeId: 'discover_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.discover,
                name: AppRouteNames.discover,
                pageBuilder: _page(const DiscoverScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'search',
                    name: AppRouteNames.discoverSearch,
                    pageBuilder: _page(const DiscoverSearchScreen()),
                  ),
                  GoRoute(
                    path: 'category/:category',
                    name: AppRouteNames.discoverCategory,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: DiscoverCategoryScreen(
                          category: state.pathParameters['category'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sportsNavigatorKey,
            restorationScopeId: 'sports_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.sports,
                name: AppRouteNames.sports,
                pageBuilder: _page(const SportsScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':sportId',
                    name: AppRouteNames.sportHub,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: SportHubScreen(
                          sportId: state.pathParameters['sportId'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _createNavigatorKey,
            restorationScopeId: 'create_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.create,
                name: AppRouteNames.create,
                pageBuilder: _page(const CreateScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':creationType',
                    name: AppRouteNames.createFlow,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: CreateFlowScreen(
                          creationType:
                              state.pathParameters['creationType'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _messagesNavigatorKey,
            restorationScopeId: 'messages_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.messages,
                name: AppRouteNames.messages,
                pageBuilder: _page(const MessagesScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':conversationId',
                    name: AppRouteNames.conversation,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: ConversationScreen(
                          conversationId:
                              state.pathParameters['conversationId'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            restorationScopeId: 'profile_branch',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                name: AppRouteNames.profile,
                pageBuilder: _page(const ProfileScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'user/:username',
                    name: AppRouteNames.publicProfile,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: PublicProfileScreen(
                          username: state.pathParameters['username'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorPageBuilder: (BuildContext context, GoRouterState state) {
      return MaterialPage<void>(
        key: state.pageKey,
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

List<RouteBase> _aliasRoutes() {
  return <RouteBase>[
    GoRoute(
      path: '/p/:postId',
      name: AppRouteNames.postAlias,
      redirect: (BuildContext context, GoRouterState state) =>
          AppRoutes.homePost(state.pathParameters['postId'] ?? ''),
    ),
    GoRoute(
      path: '/u/:username',
      name: AppRouteNames.profileAlias,
      redirect: (BuildContext context, GoRouterState state) =>
          AppRoutes.publicProfile(state.pathParameters['username'] ?? ''),
    ),
    GoRoute(
      path: '/c/:conversationId',
      name: AppRouteNames.conversationAlias,
      redirect: (BuildContext context, GoRouterState state) =>
          AppRoutes.conversation(state.pathParameters['conversationId'] ?? ''),
    ),
    GoRoute(
      path: '/s/:sportId',
      name: AppRouteNames.sportAlias,
      redirect: (BuildContext context, GoRouterState state) =>
          AppRoutes.sportHub(state.pathParameters['sportId'] ?? ''),
    ),
  ];
}

GoRoute _route({
  required String path,
  required String name,
  required Widget child,
}) {
  return GoRoute(path: path, name: name, pageBuilder: _page(child));
}

Page<void> Function(BuildContext, GoRouterState) _page(Widget child) {
  return (BuildContext context, GoRouterState state) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  };
}

String? _redirect(Ref ref, GoRouterState state) {
  final String location = state.uri.toString();
  final String path = state.matchedLocation;
  final AsyncValue<AuthRoutingState> routing = ref.read(
    authRoutingStateProvider,
  );
  if (routing.isLoading) {
    return path == AppRoutes.startup ? null : AppRoutes.startup;
  }
  if (routing.hasError) {
    // Surface the failure on the startup screen with a retry action.
    return path == AppRoutes.startup ? null : AppRoutes.startup;
  }

  final String? inheritedReturnTo = state.uri.queryParameters['returnTo'];
  final String? requestedReturnTo =
      _safeReturnTo(inheritedReturnTo) ??
      (AppRoutes.isAuthenticatedLocation(location) ? location : null);
  final AuthDestination destination = routing.requireValue.destination;
  final Set<String> signedOutRoutes = <String>{
    AppRoutes.authWelcome,
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.forgotPassword,
  };

  return switch (destination) {
    AuthDestination.configurationRequired =>
      path == AppRoutes.authUnavailable ? null : AppRoutes.authUnavailable,
    AuthDestination.signedOut =>
      signedOutRoutes.contains(path)
          ? null
          : AppRoutes.withReturnTo(AppRoutes.authWelcome, requestedReturnTo),
    AuthDestination.profileRequired =>
      path == AppRoutes.usernameSetup
          ? null
          : AppRoutes.withReturnTo(AppRoutes.usernameSetup, requestedReturnTo),
    AuthDestination.emailVerificationRequired =>
      path == AppRoutes.verifyEmail
          ? null
          : AppRoutes.withReturnTo(AppRoutes.verifyEmail, requestedReturnTo),
    AuthDestination.onboardingRequired =>
      path == AppRoutes.onboarding || path == AppRoutes.accountSecurity
          ? null
          : AppRoutes.withReturnTo(AppRoutes.onboarding, requestedReturnTo),
    AuthDestination.ready => _readyRedirect(
      path: path,
      currentLocation: location,
      returnTo: inheritedReturnTo,
    ),
    AuthDestination.blocked =>
      path == AppRoutes.accountBlocked ? null : AppRoutes.accountBlocked,
  };
}

String? _readyRedirect({
  required String path,
  required String currentLocation,
  required String? returnTo,
}) {
  if (AppRoutes.isAuthenticatedLocation(currentLocation)) {
    return null;
  }
  final String? safeReturnTo = _safeReturnTo(returnTo);
  if (safeReturnTo != null && safeReturnTo != currentLocation) {
    return safeReturnTo;
  }
  if (path == AppRoutes.accountSecurity) {
    return null;
  }
  return AppRoutes.home;
}

String? _safeReturnTo(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return null;
  }
  return AppRoutes.isAuthenticatedLocation(uri.toString())
      ? uri.toString()
      : null;
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
