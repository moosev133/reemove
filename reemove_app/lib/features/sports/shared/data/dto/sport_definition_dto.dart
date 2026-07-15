import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../../core/database/firestore_parser.dart';

class SportDefinitionDto {
  const SportDefinitionDto({
    required this.id,
    required this.slug,
    required this.localizedNames,
    required this.iconKey,
    required this.isEnabled,
    required this.sortOrder,
    required this.supportedFeatures,
    required this.audit,
  });

  factory SportDefinitionDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Sport ${snapshot.id} has no data.');
    }
    return SportDefinitionDto(
      id: snapshot.id,
      slug: FirestoreParser.string(data, 'slug'),
      localizedNames: FirestoreParser.stringMap(data, 'localizedNames'),
      iconKey: FirestoreParser.string(data, 'iconKey'),
      isEnabled: FirestoreParser.boolean(data, 'isEnabled', fallback: true),
      sortOrder: FirestoreParser.integer(data, 'sortOrder', fallback: 0),
      supportedFeatures: FirestoreParser.stringList(data, 'supportedFeatures'),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String slug;
  final Map<String, String> localizedNames;
  final String iconKey;
  final bool isEnabled;
  final int sortOrder;
  final List<String> supportedFeatures;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'slug': slug,
    'localizedNames': localizedNames,
    'iconKey': iconKey,
    'isEnabled': isEnabled,
    'sortOrder': sortOrder,
    'supportedFeatures': supportedFeatures,
    ...audit.toMap(),
  };
}
