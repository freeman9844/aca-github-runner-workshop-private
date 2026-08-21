#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"

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

[[ -f "$IMAGE_DOC" ]] || fail "module 03 missing"
[[ -f "$JOB_DOC" ]] || fail "module 04 missing"

IMAGE_TEXT="$(<"$IMAGE_DOC")"
JOB_TEXT="$(<"$JOB_DOC")"
ALL_TEXT="$IMAGE_TEXT
$JOB_TEXT"

for text in \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_ID=$(az storage account show' \
  'PE_SUBNET_ID=$(az network vnet subnet show'; do
  assert_contains "$ALL_TEXT" "$text" 'module 03/04 must restore private-blob variables'
done

for text in \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'Jobs do not support ingress' \
  '10.20.1.0/24'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 private-blob marker missing'
done

for obsolete in \
  'AZURE_SAMPLE_APP' \
  'internal Environment' \
  'same Environment' \
  'internal ingress'; do
  if grep -F -- "$obsolete" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "obsolete sample-app architecture still present: $obsolete"
  fi
done

printf 'PASS: build and deploy docs\n'
