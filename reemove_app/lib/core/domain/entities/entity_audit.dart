class EntityAudit {
  const EntityAudit({
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
}
