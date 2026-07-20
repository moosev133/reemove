/// Resolves the image URL shown for the signed-in member across the app.
///
/// ReeMove profile photos take precedence. When the member has not uploaded one,
/// Firebase Auth provider photos (for example Google) may be used.
String? resolveUserAvatarImageUrl({
  String? profileAvatarUrl,
  String? authPhotoUrl,
}) {
  final String? profileUrl = _normalizedHttpUrl(profileAvatarUrl);
  if (profileUrl != null) {
    return profileUrl;
  }
  return _normalizedHttpUrl(authPhotoUrl);
}

String? _normalizedHttpUrl(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  return trimmed;
}
