#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/03-runner-image.md"
DOCKERFILE="$ROOT/runner/Dockerfile"
ENTRYPOINT="$ROOT/runner/entrypoint.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

extract_code_block() {
  local begin_marker="$1"
  awk -v begin_marker="$begin_marker" '
    $0 == begin_marker { in_block=1; next }
    in_block && /^```/ {
      if (in_code) exit
      in_code=1
      next
    }
    in_code { print }
  ' "$DOC"
}

[[ -f "$DOC" ]] || fail "module 03 missing"
[[ -f "$DOCKERFILE" ]] || fail "runner/Dockerfile missing"
[[ -f "$ENTRYPOINT" ]] || fail "runner/entrypoint.sh missing"

dockerfile_block="$(extract_code_block '<!-- BEGIN RUNNER_DOCKERFILE -->')"
entrypoint_block="$(extract_code_block '<!-- BEGIN RUNNER_ENTRYPOINT -->')"

[[ -n "$dockerfile_block" ]] || fail "module 03 Dockerfile disclosure missing"
[[ -n "$entrypoint_block" ]] || fail "module 03 entrypoint disclosure missing"
[[ "$dockerfile_block" == "$(<"$DOCKERFILE")" ]] ||
  fail "module 03 Dockerfile disclosure must byte-match runner/Dockerfile"
[[ "$entrypoint_block" == "$(<"$ENTRYPOINT")" ]] ||
  fail "module 03 entrypoint disclosure must byte-match runner/entrypoint.sh"

printf 'PASS: runner image doc disclosures\n'
