#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/tests/validate-workshop.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$VALIDATOR" ]] || fail "integrated validator is missing"

grep -F 'GITHUB_PAT' "$VALIDATOR" >/dev/null ||
  fail 'integrated validator must reject GITHUB_PAT operational guidance in core workshop paths'
grep -F 'scripts/verify-github-app-installation.sh' "$VALIDATOR" >/dev/null ||
  fail 'integrated validator must include the Module 01 GitHub App verifier'
grep -F 'scripts/store-github-app-private-key.sh' "$VALIDATOR" >/dev/null ||
  fail 'integrated validator must include the Module 01 private key store script'

output="$(bash "$VALIDATOR" 2>&1)" || fail "integrated validator failed:\n$output"
last_line="$(printf '%s\n' "$output" | tail -n 1)"
[[ "$last_line" == 'PASS: complete workshop validation' ]] ||
  fail "unexpected validator result: $last_line"

printf 'PASS: integrated workshop validator\n'
