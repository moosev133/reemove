import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_error_view.dart';
import '../../features/startup/presentation/screens/startup_screen.dart';
import 'app_routes.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.startup,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.startup,
        name: AppRouteNames.startup,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: StartupScreen());
        },
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
