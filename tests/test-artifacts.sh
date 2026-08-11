#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$ROOT/runner/Dockerfile"
WORKFLOW="$ROOT/samples/parallel-runner-workflow.yml"

[[ -f "$DOCKERFILE" ]] || { echo "FAIL: runner/Dockerfile missing" >&2; exit 1; }
[[ -f "$WORKFLOW" ]] || { echo "FAIL: workflow sample missing" >&2; exit 1; }

grep -F 'FROM ghcr.io/actions/actions-runner:2.336.0' "$DOCKERFILE" >/dev/null
grep -F 'apt-get install -y --no-install-recommends ca-certificates curl jq' "$DOCKERFILE" >/dev/null
grep -F 'USER runner' "$DOCKERFILE" >/dev/null
grep -F 'ENTRYPOINT ["/home/runner/entrypoint.sh"]' "$DOCKERFILE" >/dev/null

grep -F 'workflow_dispatch:' "$WORKFLOW" >/dev/null
grep -F 'worker: [1, 2, 3, 4]' "$WORKFLOW" >/dev/null
grep -F 'runs-on: [self-hosted, linux, x64, aca-runner]' "$WORKFLOW" >/dev/null
grep -F 'fail-fast: false' "$WORKFLOW" >/dev/null
grep -F 'sleep 45' "$WORKFLOW" >/dev/null

if grep -E '(^|[[:space:]])docker([[:space:]]|$)|services:' "$WORKFLOW" >/dev/null; then
  echo "FAIL: workflow must not depend on Docker" >&2
  exit 1
fi

printf 'PASS: runner image and workflow artifacts\n'
