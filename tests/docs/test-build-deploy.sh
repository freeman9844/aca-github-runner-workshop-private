#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"
[[ -f "$IMAGE_DOC" ]] || { echo "FAIL: module 03 missing" >&2; exit 1; }
[[ -f "$JOB_DOC" ]] || { echo "FAIL: module 04 missing" >&2; exit 1; }

for text in \
  'bash -n runner/entrypoint.sh' \
  'bash tests/runner/test-entrypoint.sh' \
  'az acr build' \
  '--image "$IMAGE"' \
  './runner' \
  'ghcr.io/actions/actions-runner:2.336.0'; do
  grep -F -- "$text" "$IMAGE_DOC" >/dev/null || { echo "FAIL: module 03 missing $text" >&2; exit 1; }
done

for text in \
  '--trigger-type Event' \
  '--container-name github-actions-runner' \
  '--replica-retry-limit 0' \
  '--replica-completion-count 1' \
  '--parallelism 1' \
  '--min-executions 0' \
  '--max-executions 5' \
  '--polling-interval 30' \
  '--scale-rule-type github-runner' \
  'runnerScope=repo' \
  'labels=aca-runner' \
  'targetWorkflowQueueLength=1' \
  'personalAccessToken=personal-access-token' \
  'GITHUB_PAT=secretref:personal-access-token' \
  'RUNNER_LABELS=aca-runner' \
  '--registry-identity "$UAMI_RID"'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

printf 'PASS: image build and Event Job docs\n'
