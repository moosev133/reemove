import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';

class NotificationActorDto {
  const NotificationActorDto({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
  });

  factory NotificationActorDto.fromMap(FirestoreMap data) {
    return NotificationActorDto(
      id: FirestoreParser.string(data, 'id', fallback: ''),
      username: FirestoreParser.string(data, 'username', fallback: ''),
      displayName: FirestoreParser.string(
        data,
        'displayName',
        fallback: 'Athlete',
      ),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
    );
  }

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
}

class AppNotificationDto {
  const AppNotificationDto({
    required this.id,
    required this.category,
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.groupKey,
    required this.groupCount,
    required this.actors,
    required this.data,
    required this.createdAt,
    required this.latestAt,
    required this.updatedAt,
    this.entityType,
    this.entityId,
    this.imageUrl,
    this.readAt,
    this.deletedAt,
  });

  factory AppNotificationDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? <String, dynamic>{};
    return AppNotificationDto(
      id: snapshot.id,
      category: FirestoreParser.string(data, 'category', fallback: 'activity'),
      kind: FirestoreParser.string(data, 'kind', fallback: 'unknown'),
      title: FirestoreParser.string(data, 'title', fallback: 'ReeMove'),
      body: FirestoreParser.string(
        data,
        'body',
        fallback: 'You have a new update.',
      ),
      route: FirestoreParser.string(data, 'route', fallback: '/home/activity'),
      groupKey: FirestoreParser.string(data, 'groupKey', fallback: snapshot.id),
      groupCount: FirestoreParser.integer(data, 'groupCount', fallback: 1),
      actors: FirestoreParser.mapList(
        data,
        'actors',
      ).map(NotificationActorDto.fromMap).toList(growable: false),
      data: FirestoreParser.stringMap(data, 'data'),
      entityType: FirestoreParser.nullableString(data, 'entityType'),
      entityId: FirestoreParser.nullableString(data, 'entityId'),
      imageUrl: FirestoreParser.nullableString(data, 'imageUrl'),
      createdAt: FirestoreParser.dateTime(data, 'createdAt'),
      latestAt: FirestoreParser.dateTime(data, 'latestAt'),
      updatedAt: FirestoreParser.dateTime(data, 'updatedAt'),
      readAt: FirestoreParser.nullableDateTime(data, 'readAt'),
      deletedAt: FirestoreParser.nullableDateTime(data, 'deletedAt'),
    );
  }

  final String id;
  final String category;
  final String kind;
  final String title;
  final String body;
  final String route;
  final String groupKey;
  final int groupCount;
  final List<NotificationActorDto> actors;
  final Map<String, String> data;
  final String? entityType;
  final String? entityId;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime latestAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final DateTime? deletedAt;
}
