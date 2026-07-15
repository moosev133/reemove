#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
firebase use staging
firebase deploy --config firebase.json --only firestore:indexes,firestore:rules,storage,database,functions,remoteconfig
