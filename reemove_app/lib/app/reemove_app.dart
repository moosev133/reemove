import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_environment.dart';
import '../core/providers/core_providers.dart';
import '../core/release/maintenance_mode_screen.dart';
import '../core/release/release_providers.dart';
import '../core/release/release_state.dart';
import '../core/release/update_required_screen.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class ReeMoveApp extends ConsumerWidget {
  const ReeMoveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final AsyncValue<ReleaseState> release = ref.watch(releaseStateProvider);
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);

    return release.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, _) => _routedApp(ref, themeMode),
      data: (ReleaseState state) {
        if (state.maintenanceMode) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: MaintenanceModeScreen(
              title: state.maintenanceTitle,
              message: state.maintenanceMessage,
              statusUrl: state.statusUrl,
              supportUrl: state.supportUrl,
              onRetry: () async {
                ref.invalidate(releaseStateProvider);
              },
            ),
          );
        }
        if (state.updateRequirement == UpdateRequirement.required) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: UpdateRequiredScreen(
              storeUrl: _storeUrl(environment),
              supportUrl: state.supportUrl,
            ),
          );
        }
        return _routedApp(ref, themeMode);
      },
    );
  }

  Widget _routedApp(WidgetRef ref, ThemeMode themeMode) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ReeMove',
      restorationScopeId: 'reemove_app',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Uri _storeUrl(AppEnvironment environment) {
    final String? configured = environment.storeUrl;
    if (configured != null && configured.isNotEmpty) {
      return Uri.parse(configured);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse('https://apps.apple.com');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse('https://play.google.com/store');
    }
    return Uri.parse('https://reemove.app');
  }
}
