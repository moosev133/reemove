#!/usr/bin/env bash
set -euo pipefail
alias_name="${1:-staging}"
[[ "$alias_name" =~ ^(development|staging|production)$ ]] || {
  echo "Usage: $0 development|staging|production" >&2
  exit 2
}
cd "$(dirname "$0")/../.."
firebase use "$alias_name"
firebase remoteconfig:get -o "remoteconfig.template.${alias_name}.json" || {
  echo "Remote Config export requires Firebase CLI auth and project access." >&2
  exit 1
}
echo "Exported Remote Config for $alias_name"
