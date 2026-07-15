enum ContentReportReason {
  spam,
  harassment,
  hate,
  violence,
  dangerousActivity,
  nudity,
  misinformation,
  impersonation,
  intellectualProperty,
  other,
}

class ContentReportRequest {
  const ContentReportRequest({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.details,
  });

  final String targetType;
  final String targetId;
  final ContentReportReason reason;
  final String? details;
}
