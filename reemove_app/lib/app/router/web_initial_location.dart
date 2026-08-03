import 'package:flutter/foundation.dart';

import 'app_routes.dart';
import 'router_diagnostic_log.dart';

/// Captures the browser URL as early as possible during web bootstrap.
abstract final class WebInitialLocation {
  static String? _captured;

  static String? get captured => _captured;

  static void captureFromBrowser() {
    if (!kIsWeb) {
      return;
    }
    final Uri uri = Uri.base;
    RouterDiagnosticLog.record(
      'bootstrap browser uri=${uri.toString()} path=${uri.path} hash=${uri.fragment}',
    );
    final String? resolved = _resolve(uri);
    _captured = resolved;
    if (resolved != null) {
      RouterDiagnosticLog.record('bootstrap captured location=$resolved');
    }
  }

  static String goRouterInitialLocation() {
    if (!kIsWeb) {
      return AppRoutes.startup;
    }
    final String? captured = _captured;
    if (captured != null && captured != AppRoutes.startup) {
      RouterDiagnosticLog.record('goRouter initialLocation=$captured');
      return captured;
    }
    final String? resolved = _resolve(Uri.base);
    if (resolved != null && resolved != AppRoutes.startup) {
      RouterDiagnosticLog.record('goRouter initialLocation(from Uri.base)=$resolved');
      return resolved;
    }
    RouterDiagnosticLog.record('goRouter initialLocation=${AppRoutes.startup}');
    return AppRoutes.startup;
  }

  static String? pendingDeepLink({required String uriString}) {
    final Uri uri = Uri.parse(uriString);
    if (uri.path.isNotEmpty && uri.path != AppRoutes.startup) {
      return null;
    }
    final String? captured = _captured;
    if (captured == null || captured == AppRoutes.startup) {
      return null;
    }
    return captured;
  }

  static void clearAfterUse() {
    _captured = null;
  }

  /// Test-only: seed a captured browser location without touching Uri.base.
  static void debugSetCaptured(String? location) {
    _captured = location;
  }

  static String? _resolve(Uri uri) {
    final String path = uri.path;
    if (path.isNotEmpty && path != AppRoutes.startup) {
      return uri.hasQuery ? uri.toString() : path;
    }
    final String fragment = uri.fragment;
    if (fragment.startsWith('/')) {
      return fragment.split('?').first;
    }
    return null;
  }
}
