#!/usr/bin/env bash
set -euo pipefail
# Template only — does not create paid Cloud resources.
# Owner fills PROJECT_ID and BUCKET then runs manually when ready.
PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
BUCKET="${BUCKET:?Set BUCKET gs://...}"
echo "Example Firestore export (not executed automatically):"
echo "gcloud firestore export \"$BUCKET\" --project=\"$PROJECT_ID\""
echo "Document restore/rollback rehearsals in docs/BACKUP_RESTORE_DISASTER_RECOVERY.md"
