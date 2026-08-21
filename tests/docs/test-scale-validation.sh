#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message: $needle"
}

[[ -f "$DOC" ]] || fail "module 05 missing"

DOC_TEXT="$(<"$DOC")"

for text in \
  '## 0. 세션 재연결 시 변수 복구 (선택)' \
  'INFRA_SUBNET="snet-aca-infra"' \
  'PE_SUBNET="snet-private-endpoints"' \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_PE="pe-blob-$SUFFIX"' \
  'STORAGE_DNS_ZONE="privatelink.blob.core.windows.net"' \
  'STORAGE_DNS_LINK="link-blob-$SUFFIX"' \
  'PRIVATE_ENDPOINT_CIDR="10.20.1.0/24"' \
  'STORAGE_ID=$(az storage account show' \
  'PE_SUBNET_ID=$(az network vnet subnet show' \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'Jobs do not support ingress'; do
  assert_contains "$DOC_TEXT" "$text" 'module 05 recovery/private-blob marker missing'
done

for obsolete in \
  'AZURE_SAMPLE_APP' \
  'internal Environment' \
  'same Environment' \
  'internal ingress'; do
  if grep -F -- "$obsolete" "$DOC" >/dev/null; then
    fail "obsolete internal-sample-app text still present: $obsolete"
  fi
done

printf 'PASS: scale validation doc\n'
