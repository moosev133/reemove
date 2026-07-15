# Backup, Restore, and Disaster Recovery

## Scope

Backups do not replace Security Rules, version control, or rollback. Define separate recovery procedures for Firestore data, Storage objects, Functions/configuration, Remote Config, signing material, and store records.

## Firestore

- Configure scheduled exports or managed backup/PITR capabilities appropriate to the production plan.
- Store backups in a separate restricted project/bucket where possible.
- Encrypt, retain, and expire backups under an approved policy.
- Test restore into an isolated recovery project, never directly over production during rehearsal.
- Measure recovery point objective and recovery time objective.

## Storage

- Decide whether user originals require versioning/backup based on product and legal needs.
- Separate temporary/derived media from originals.
- Test deletion propagation and restoration limitations.

## Configuration

Version Firestore/Storage rules, indexes, Functions code, Remote Config exports/defaults, and infrastructure scripts. Record all console-only settings in the configuration inventory.

## Signing and ownership

Maintain encrypted, access-controlled backups and recovery documentation for Android upload keys and Apple account/certificate access. Test organizational recovery without exposing key material to the repository.

## Rehearsal evidence

Record date, owner, backup identifier, restore target, restored counts/checksums, validation results, RPO/RTO, issues, and approval.
