#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$WORKFLOW" ]] || fail "sample deploy workflow missing"

for text in \
  'Storage Blob Data Contributor' \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'privatelink.blob.core.windows.net' \
  'private IP' \
  'az storage blob upload' \
  'az storage blob download' \
  '--auth-mode login' \
  'sha256sum'; do
  grep -F -- "$text" "$WORKFLOW" >/dev/null || fail "workflow missing private Blob artifact marker: $text"
done

for forbidden in \
  'containerapp create' \
  '--ingress internal' \
  'AZURE_SAMPLE_''APP'; do
  if grep -F -- "$forbidden" "$WORKFLOW" >/dev/null; then
    fail "workflow still contains obsolete sample-app behavior: $forbidden"
  fi
done

printf 'PASS: workflow artifacts contract\n'
