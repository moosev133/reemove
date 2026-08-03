import 'user_profile.dart';

enum ProfileConnectionType { followers, following, requests, sentRequests }

class ProfileConnectionCursor {
  const ProfileConnectionCursor({
    required this.documentId,
    required this.createdAt,
  });

  final String documentId;
  final DateTime createdAt;
}

class ProfileConnectionPage {
  const ProfileConnectionPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<UserProfile> items;
  final bool hasMore;
  final ProfileConnectionCursor? nextCursor;
}

/// Thrown when a viewer is not allowed to open a connection list.
class ProfileConnectionsRestricted implements Exception {
  const ProfileConnectionsRestricted([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'This connection list is private.';
}
