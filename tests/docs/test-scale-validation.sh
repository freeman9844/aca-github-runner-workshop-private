#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"
[[ -f "$DOC" ]] || { echo "FAIL: module 05 missing" >&2; exit 1; }

for text in \
  'samples/parallel-runner-workflow.yml' \
  '.github/workflows/aca-runner-scale-test.yml' \
  'runs-on: [self-hosted, linux, x64, aca-runner]' \
  'worker: [1, 2, 3, 4]' \
  'az containerapp job execution list' \
  'properties.status' \
  'az containerapp job logs show' \
  '--container github-actions-runner' \
  'ContainerAppConsoleLogs' \
  'ContainerGroupName startswith' \
  'Runner configured' \
  'Runner process exited' \
  'active execution 수는 0'; do
  grep -F -- "$text" "$DOC" >/dev/null || { echo "FAIL: module 05 missing $text" >&2; exit 1; }
done

printf 'PASS: parallel scale validation doc\n'
