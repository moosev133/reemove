#!/usr/bin/env bash
set -euo pipefail
alias_name="${1:-}"
[[ "$alias_name" =~ ^(development|staging|production)$ ]] || {
  echo "Usage: $0 development|staging|production" >&2
  exit 2
}
command -v firebase >/dev/null
echo "Requested alias: $alias_name"
if [[ "$alias_name" == "production" && "${ALLOW_PROD:-}" != "YES_I_HAVE_APPROVAL" ]]; then
  echo "Production verification requires ALLOW_PROD=YES_I_HAVE_APPROVAL" >&2
  exit 3
fi
cd "$(dirname "$0")/../.."
firebase use "$alias_name"
firebase projects:list >/dev/null
echo "Firebase CLI authentication and project access verified."
