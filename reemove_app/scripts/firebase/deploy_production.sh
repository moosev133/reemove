#!/usr/bin/env bash
set -euo pipefail
# Production Firebase deploy — requires explicit approval. Never invent project IDs.
[[ "${GITHUB_REF_TYPE:-}" == "tag" || "${ALLOW_LOCAL_PROD:-}" == "YES_I_HAVE_APPROVAL" ]] || {
  echo "Production deploy must run from an approved tag or ALLOW_LOCAL_PROD=YES_I_HAVE_APPROVAL." >&2
  exit 3
}
[[ "${RELEASE_APPROVED:-}" == "true" ]] || {
  echo "RELEASE_APPROVED=true is required." >&2
  exit 4
}
cd "$(dirname "$0")/../.."
firebase use production
firebase deploy --config firebase.json --only firestore:indexes,firestore:rules,storage,database,functions,remoteconfig
