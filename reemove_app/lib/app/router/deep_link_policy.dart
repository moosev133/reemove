import 'app_routes.dart';

/// Allowed external / universal deep-link policy for ReeMove.
///
/// Supports production hosts (`reemove.app`, `links.reemove.app`) and the
/// `reemove` custom scheme, matching the short aliases used by GoRouter.
abstract final class DeepLinkPolicy {
  static const Set<String> allowedHttpsHosts = <String>{
    'reemove.app',
    'www.reemove.app',
    'links.reemove.app',
  };

  static const Set<String> aliasRoots = <String>{'p', 'u', 'c', 's', 'ch', 'm'};

  /// Returns a parsed [Uri] when [value] is an allowed ReeMove deep link.
  static Uri? parseAllowed(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return null;
    }

    final bool customScheme = uri.scheme == 'reemove';
    final bool httpsScheme = uri.scheme == 'https';
    if (!customScheme && !httpsScheme) {
      return null;
    }
    if (httpsScheme && !allowedHttpsHosts.contains(uri.host)) {
      return null;
    }

    final String? root = _rootSegment(uri);
    if (root == null) {
      return null;
    }
    if (aliasRoots.contains(root)) {
      return uri;
    }

    final String path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    if (AppRoutes.isShellLocation(path) ||
        AppRoutes.isProtectedAlias(path) ||
        path.startsWith(AppRoutes.aiHub) ||
        path.startsWith(AppRoutes.challenges) ||
        path.startsWith(AppRoutes.marketplace) ||
        path.startsWith(AppRoutes.nearby)) {
      return uri;
    }
    return null;
  }

  static String? _rootSegment(Uri uri) {
    if (uri.scheme == 'reemove' && uri.host.isNotEmpty) {
      return uri.host.toLowerCase();
    }
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    return uri.pathSegments.first.toLowerCase();
  }
}
