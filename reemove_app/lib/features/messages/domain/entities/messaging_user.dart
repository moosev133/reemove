class MessagingUser {
  const MessagingUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
}
