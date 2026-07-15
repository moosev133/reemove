#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
base="${PUBLIC_STATUS_BASE_URL:?PUBLIC_STATUS_BASE_URL required}"
mkdir -p release_evidence
report="release_evidence/production-smoke-$(date -u +%Y%m%dT%H%M%SZ).txt"
{
  echo "ReeMove production smoke"
  echo "UTC: $(date -u +%FT%TZ)"
  for path in /health /version; do
    echo "Checking ${base%/}${path}"
    curl --fail --silent --show-error --max-time 15 "${base%/}${path}"
    echo
  done
} | tee "$report"
