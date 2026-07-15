import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/firestore_parser.dart';

class FeatureFlagDto {
  const FeatureFlagDto({
    required this.id,
    required this.enabled,
    required this.rolloutPercentage,
    required this.allowedPlatforms,
    required this.minimumBuild,
    required this.description,
    required this.audit,
  });

  factory FeatureFlagDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Feature flag ${snapshot.id} has no data.');
    }
    return FeatureFlagDto(
      id: snapshot.id,
      enabled: FirestoreParser.boolean(data, 'enabled', fallback: false),
      rolloutPercentage: FirestoreParser.integer(
        data,
        'rolloutPercentage',
        fallback: 0,
      ),
      allowedPlatforms: FirestoreParser.stringList(data, 'allowedPlatforms'),
      minimumBuild: FirestoreParser.integer(data, 'minimumBuild', fallback: 1),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final bool enabled;
  final int rolloutPercentage;
  final List<String> allowedPlatforms;
  final int minimumBuild;
  final String description;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'enabled': enabled,
    'rolloutPercentage': rolloutPercentage,
    'allowedPlatforms': allowedPlatforms,
    'minimumBuild': minimumBuild,
    'description': description,
    ...audit.toMap(),
  };
}
