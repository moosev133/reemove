# Data migration conventions

## Versioning

Every application-owned document carries an integer `schemaVersion`. Phase 2 begins at schema version `1`.

Dataset and migration runs use a separate immutable identifier, for example:

```text
2026-07-13.phase2.v1
```

Each successful migration writes a marker to:

```text
data_migrations/{migrationId}
```

Migration markers include `version`, `type`, `status`, `appliedAt`, and `schemaVersion`.

## Rules

1. Production migrations run only through trusted Admin SDK code.
2. Migration IDs are immutable and never reused.
3. A migration must be idempotent or record sufficient progress to resume safely.
4. Bulk changes are processed in bounded batches below Firestore write limits.
5. Migrations are tested against an emulator export before staging.
6. Backward-compatible reads are deployed before data rewriting begins.
7. Destructive cleanup happens only after all supported app builds understand the new schema.
8. Security Rules and indexes are deployed before clients issue queries that depend on them.
9. Every migration documents rollback behavior and expected document counts.
10. Clients cannot write `data_migrations` or `audit_logs`.

## Recommended rollout

```text
1. Add tolerant DTO reader
2. Deploy rules/indexes
3. Deploy backend writer using the new shape
4. Run staging migration
5. Verify counts and sampled documents
6. Deploy mobile client
7. Run production migration
8. Monitor errors and latency
9. Remove legacy reader in a later release
```

## Seed safety

`functions/src/seed/seedFirestore.ts` refuses to run unless:

- `FIRESTORE_EMULATOR_HOST` is set; and
- the Firebase project ID starts with `demo-`.

This prevents the sample dataset from being written to staging or production.
