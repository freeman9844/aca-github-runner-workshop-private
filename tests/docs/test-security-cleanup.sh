#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/07-security-limitations-cleanup.md"

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

[[ -f "$DOC" ]] || fail "module 07 missing"

DOC_TEXT="$(<"$DOC")"

for text in \
  'Storage public network default deny' \
  'Blob Private Endpoint' \
  'Private DNS zone' \
  'Storage Blob Data Contributor' \
  'delegated ACA subnet과 Private Endpoint subnet을 분리'; do
  assert_contains "$DOC_TEXT" "$text" 'module 07 missing cleanup marker'
done

for obsolete in \
  'sample app' \
  'internal Environment' \
  'same Environment' \
  'internal ingress'; do
  if grep -F -- "$obsolete" "$DOC" >/dev/null; then
    fail "module 07 still uses old internal-ACA language: $obsolete"
  fi
done

printf 'PASS: security cleanup doc\n'
