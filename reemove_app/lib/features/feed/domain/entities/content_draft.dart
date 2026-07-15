import '../../../../core/domain/value_objects/content_policy.dart';

enum DraftKind { post, story, reel }

enum DraftMediaKind { image, video }

class DraftMediaSelection {
  const DraftMediaSelection({
    required this.localPath,
    required this.name,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
  });

  final String localPath;
  final String name;
  final DraftMediaKind kind;
  final String contentType;
  final int sizeBytes;
}

class ContentDraft {
  const ContentDraft({
    required this.id,
    required this.kind,
    required this.caption,
    required this.media,
    required this.visibility,
    required this.allowComments,
    required this.createdAt,
    required this.updatedAt,
    this.sportId,
    this.locationLabel,
  });

  factory ContentDraft.empty({required DraftKind kind, required String id}) {
    final DateTime now = DateTime.now().toUtc();
    return ContentDraft(
      id: id,
      kind: kind,
      caption: '',
      media: const <DraftMediaSelection>[],
      visibility: Visibility.public,
      allowComments: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final DraftKind kind;
  final String caption;
  final List<DraftMediaSelection> media;
  final String? sportId;
  final String? locationLabel;
  final Visibility visibility;
  final bool allowComments;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentDraft copyWith({
    String? caption,
    List<DraftMediaSelection>? media,
    String? sportId,
    bool clearSportId = false,
    String? locationLabel,
    bool clearLocationLabel = false,
    Visibility? visibility,
    bool? allowComments,
  }) {
    return ContentDraft(
      id: id,
      kind: kind,
      caption: caption ?? this.caption,
      media: media ?? this.media,
      sportId: clearSportId ? null : sportId ?? this.sportId,
      locationLabel: clearLocationLabel
          ? null
          : locationLabel ?? this.locationLabel,
      visibility: visibility ?? this.visibility,
      allowComments: allowComments ?? this.allowComments,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
