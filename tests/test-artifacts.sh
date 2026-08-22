#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"
GITIGNORE="$ROOT/.gitignore"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$WORKFLOW" ]] || fail "sample deploy workflow missing"
[[ -f "$GITIGNORE" ]] || fail ".gitignore missing"

for ignored_path in \
  '.copilot/' \
  '.superpowers/' \
  'docs/superpowers/'; do
  grep -Fx -- "$ignored_path" "$GITIGNORE" >/dev/null ||
    fail "internal artifact path is not ignored: $ignored_path"
done

TRACKED_IGNORED="$(git -C "$ROOT" ls-files -ci --exclude-standard)"
[[ -z "$TRACKED_IGNORED" ]] ||
  fail $'ignored internal artifacts are still tracked:\n'"$TRACKED_IGNORED"

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
