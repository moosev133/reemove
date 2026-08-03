import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/domain/entities/auth_routing_state.dart';
import 'app_routes.dart';
import 'web_initial_location.dart';

/// Reads the browser/deep-link destination even when [matchedPath] is still `/`.
String requestedRouterLocation(String uriString, String matchedPath) {
  final Uri uri = Uri.parse(uriString);
  final String uriPath = uri.path;
  if (uriPath.isNotEmpty && uriPath != AppRoutes.startup) {
    return uri.hasQuery ? uri.toString() : uriPath;
  }
  if (matchedPath.isNotEmpty && matchedPath != AppRoutes.startup) {
    return matchedPath;
  }
  return AppRoutes.startup;
}

String? safeReturnToValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return null;
  }
  final String normalized = AppRoutes.normalizeDeepLinkLocation(uri.toString());
  return AppRoutes.isAuthenticatedLocation(normalized) ? normalized : null;
}

String? resolveReadyRedirect({
  required String matchedPath,
  required String uriString,
  required String? returnTo,
}) {
  String requested = requestedRouterLocation(uriString, matchedPath);
  if (requested == AppRoutes.startup) {
    final String? pending = WebInitialLocation.pendingDeepLink(
      uriString: uriString,
    );
    if (pending != null) {
      requested = pending;
    }
  }
  requested = AppRoutes.normalizeDeepLinkLocation(requested);

  if (AppRoutes.isAuthenticatedLocation(requested)) {
    if (matchedPath == AppRoutes.startup && requested != AppRoutes.startup) {
      return requested;
    }
    return null;
  }

  if (AppRoutes.isAuthenticatedLocation(uriString)) {
    return null;
  }

  final String? safeReturnTo = safeReturnToValue(returnTo);
  if (safeReturnTo != null && safeReturnTo != uriString) {
    return safeReturnTo;
  }
  if (matchedPath == AppRoutes.accountSecurity) {
    return null;
  }
  return AppRoutes.home;
}

String? resolveAuthRedirect({
  required AsyncValue<AuthRoutingState> routing,
  required String matchedPath,
  required String uriString,
  required String? returnTo,
}) {
  if (routing.isLoading) {
    final String requested = requestedRouterLocation(uriString, matchedPath);
    if (matchedPath == AppRoutes.startup) {
      if (requested != AppRoutes.startup &&
          AppRoutes.isAuthenticatedLocation(requested)) {
        return AppRoutes.withReturnTo(
          AppRoutes.startup,
          AppRoutes.normalizeDeepLinkLocation(requested),
        );
      }
      return null;
    }
    if (AppRoutes.isAuthenticatedLocation(requested)) {
      return AppRoutes.withReturnTo(
        AppRoutes.startup,
        AppRoutes.normalizeDeepLinkLocation(requested),
      );
    }
    return AppRoutes.startup;
  }

  if (routing.hasError) {
    return matchedPath == AppRoutes.startup ? null : AppRoutes.startup;
  }

  final String requested = requestedRouterLocation(uriString, matchedPath);
  final String? requestedReturnTo =
      safeReturnToValue(returnTo) ??
      (AppRoutes.isAuthenticatedLocation(requested)
          ? AppRoutes.normalizeDeepLinkLocation(requested)
          : null);
  final AuthDestination destination = routing.requireValue.destination;
  const Set<String> signedOutRoutes = <String>{
    AppRoutes.authWelcome,
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.forgotPassword,
  };

  return switch (destination) {
    AuthDestination.configurationRequired =>
      matchedPath == AppRoutes.authUnavailable ? null : AppRoutes.authUnavailable,
    AuthDestination.signedOut =>
      signedOutRoutes.contains(matchedPath)
          ? null
          : AppRoutes.withReturnTo(AppRoutes.authWelcome, requestedReturnTo),
    AuthDestination.profileRequired =>
      matchedPath == AppRoutes.usernameSetup
          ? null
          : AppRoutes.withReturnTo(AppRoutes.usernameSetup, requestedReturnTo),
    AuthDestination.emailVerificationRequired =>
      matchedPath == AppRoutes.verifyEmail
          ? null
          : AppRoutes.withReturnTo(AppRoutes.verifyEmail, requestedReturnTo),
    AuthDestination.onboardingRequired =>
      matchedPath == AppRoutes.onboarding ||
              matchedPath == AppRoutes.accountSecurity
          ? null
          : AppRoutes.withReturnTo(AppRoutes.onboarding, requestedReturnTo),
    AuthDestination.ready => resolveReadyRedirect(
      matchedPath: matchedPath,
      uriString: uriString,
      returnTo: returnTo,
    ),
    AuthDestination.blocked =>
      matchedPath == AppRoutes.accountBlocked ? null : AppRoutes.accountBlocked,
  };
}
