abstract final class ContentLimits {
  static const int postCaptionCharacters = 2200;
  static const int storyCaptionCharacters = 280;
  static const int commentCharacters = 2200;
  static const int maxPostImages = 10;
  static const int maxPostImageBytes = 15 * 1024 * 1024;
  static const int maxVideoBytes = 150 * 1024 * 1024;
  static const Duration maxReelDuration = Duration(seconds: 90);
  static const Duration storyLifetime = Duration(hours: 24);
}
