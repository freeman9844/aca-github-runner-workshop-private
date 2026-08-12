#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/tests/validate-workshop.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$VALIDATOR" ]] || fail "integrated validator is missing"

output="$(bash "$VALIDATOR" 2>&1)" || fail "integrated validator failed:\n$output"
last_line="$(printf '%s\n' "$output" | tail -n 1)"
[[ "$last_line" == 'PASS: complete workshop validation' ]] ||
  fail "unexpected validator result: $last_line"

printf 'PASS: integrated workshop validator\n'
