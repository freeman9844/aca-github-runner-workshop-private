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
  'name: ACA Runner VNet-Restricted Blob Deploy' \
  'deploy-vnet-restricted-blob:' \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY' \
  'ERROR: GitHub App bootstrap variable reached the workflow environment:' \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'az storage blob upload' \
  'az storage blob download' \
  '--auth-mode login' \
  'sha256sum'; do
  grep -F -- "$text" "$WORKFLOW" >/dev/null || fail "workflow missing VNet-restricted Blob marker: $text"
done

for forbidden in \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'privatelink.blob.core.windows.net' \
  'private IP' \
  'Verify Blob DNS resolves to the private endpoint subnet' \
  'containerapp create' \
  '--ingress internal' \
  'AZURE_SAMPLE_''APP'; do
  if grep -F -- "$forbidden" "$WORKFLOW" >/dev/null; then
    fail "workflow still contains obsolete behavior: $forbidden"
  fi
done

printf 'PASS: workflow artifacts contract\n'
