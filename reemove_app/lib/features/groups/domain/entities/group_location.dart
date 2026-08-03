class GroupLocation {
  const GroupLocation({
    this.locality,
    this.administrativeArea,
    this.countryCode,
    this.text,
  });

  static const GroupLocation empty = GroupLocation();

  final String? locality;
  final String? administrativeArea;
  final String? countryCode;
  final String? text;

  bool get isEmpty =>
      (locality == null || locality!.isEmpty) &&
      (administrativeArea == null || administrativeArea!.isEmpty) &&
      (countryCode == null || countryCode!.isEmpty) &&
      (text == null || text!.isEmpty);

  /// A short human-readable summary, preferring free-form [text] and
  /// falling back to locality/area/country parts.
  String get displayLabel {
    final String? trimmedText = text?.trim();
    if (trimmedText != null && trimmedText.isNotEmpty) {
      return trimmedText;
    }
    final List<String> parts = <String>[
      if (locality != null && locality!.trim().isNotEmpty) locality!.trim(),
      if (administrativeArea != null && administrativeArea!.trim().isNotEmpty)
        administrativeArea!.trim(),
      if (countryCode != null && countryCode!.trim().isNotEmpty)
        countryCode!.trim(),
    ];
    return parts.join(', ');
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (locality != null) 'locality': locality,
    if (administrativeArea != null) 'administrativeArea': administrativeArea,
    if (countryCode != null) 'countryCode': countryCode,
    if (text != null) 'text': text,
  };
}
