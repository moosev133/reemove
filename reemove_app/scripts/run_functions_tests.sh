#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v npm >/dev/null || { echo "npm is required" >&2; exit 2; }
if [[ ! -d functions ]]; then echo "functions directory not found" >&2; exit 2; fi
npm --prefix functions ci
npm --prefix functions run build
npm --prefix functions run test:unit
