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
  'JOB_CREATE_ARGS=(' \
  '# queue가 비어 있으면 execution을 0개로 유지합니다.' \
  'az containerapp job create "${JOB_CREATE_ARGS[@]}"' \
  '--trigger-type Event' \
  '--container-name github-actions-runner' \
  '--replica-timeout 900' \
  '--replica-retry-limit 0' \
  '--replica-completion-count 1' \
  '--parallelism 1' \
  '--min-executions 0' \
  '--max-executions 5' \
  '--polling-interval 30' \
  '--scale-rule-type github-runner' \
  'githubApiURL=https://api.github.com' \
  'runnerScope=repo' \
  'labels=aca-runner' \
  'targetWorkflowQueueLength=1' \
  'personalAccessToken=personal-access-token' \
  'GITHUB_PAT=secretref:personal-access-token' \
  'RUNNER_LABELS=aca-runner' \
  '--mi-user-assigned "$UAMI_RID"' \
  '--registry-identity "$UAMI_RID"'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

if grep -F -- '## 4. 파라미터 의미 빠르게 읽기' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 keeps parameter explanations in a separate table" >&2
  exit 1
fi

if grep -F -- 'githubAPIURL=' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 uses invalid KEDA metadata key githubAPIURL" >&2
  exit 1
fi

for text in \
  '--cpu 2.0' \
  '--memory 4Gi'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

printf 'PASS: image build and Event Job docs\n'
