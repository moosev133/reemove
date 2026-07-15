import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/entity_audit.dart';
import '../firestore_parser.dart';

class EntityAuditDto {
  const EntityAuditDto({
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  factory EntityAuditDto.fromMap(FirestoreMap data) => EntityAuditDto(
    createdAt: FirestoreParser.dateTime(data, 'createdAt'),
    updatedAt: FirestoreParser.dateTime(data, 'updatedAt'),
    schemaVersion: FirestoreParser.integer(data, 'schemaVersion', fallback: 1),
  );

  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  EntityAudit toDomain() => EntityAudit(
    createdAt: createdAt,
    updatedAt: updatedAt,
    schemaVersion: schemaVersion,
  );

  FirestoreMap toMap() => <String, Object?>{
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
    'schemaVersion': schemaVersion,
  };
}
