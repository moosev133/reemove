#!/usr/bin/env bash
set -euo pipefail
# Public health probes. Requires PUBLIC_STATUS_BASE_URL (owner-hosted status page).
base_url="${PUBLIC_STATUS_BASE_URL:?PUBLIC_STATUS_BASE_URL required}"
for path in /health /version; do
  code="$(curl -sS -o /tmp/reemove-smoke.txt -w '%{http_code}' --max-time 15 "${base_url%/}${path}")"
  [[ "$code" == "200" ]] || {
    echo "Smoke failed for $path with HTTP $code" >&2
    cat /tmp/reemove-smoke.txt >&2
    exit 1
  }
done
echo "Production-safe public health checks passed."
