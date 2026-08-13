#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"
QUEUED_SCREENSHOT="$ROOT/docs/images/05-github-actions-queued-matrix.png"
SUCCESS_SCREENSHOT="$ROOT/docs/images/05-github-actions-successful-matrix.png"
[[ -f "$DOC" ]] || { echo "FAIL: module 05 missing" >&2; exit 1; }
[[ -f "$QUEUED_SCREENSHOT" ]] || { echo "FAIL: module 05 queued screenshot missing" >&2; exit 1; }
[[ -f "$SUCCESS_SCREENSHOT" ]] || { echo "FAIL: module 05 successful matrix screenshot missing" >&2; exit 1; }

for text in \
  '같은 Cloud Shell 세션을 계속 사용 중이라면' \
  '원래 저장해 둔 SUFFIX' \
  'SUFFIX="<your-saved-suffix>"' \
  'RG="rg-acarunner-$SUFFIX"' \
  'LOG="log-acarunner-$SUFFIX"' \
  'JOB="job-ghrunner-$SUFFIX"' \
  'LOG_ID=$(az monitor log-analytics workspace show' \
  '--resource-group "$RG"' \
  '--workspace-name "$LOG"' \
  '--query customerId' \
  '--output tsv' \
  'samples/parallel-runner-workflow.yml' \
  '.github/workflows/aca-runner-scale-test.yml' \
  '![GitHub Actions에서 네 개 matrix Job이 queued 상태인 화면](images/05-github-actions-queued-matrix.png)' \
  'Worker 1은 성공했고 Worker 4는 아직 진행 중인 중간 상태' \
  '# 수동 실행으로만 scale test를 시작합니다.' \
  'name: ACA Runner Scale Test' \
  'workflow_dispatch:' \
  'runs-on: [self-hosted, linux, x64, aca-runner]' \
  'timeout-minutes: 10' \
  'fail-fast: false' \
  'worker: [1, 2, 3, 4]' \
  'Hold the runner for scale observation' \
  'sleep 45' \
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

for text in \
  'Fine-grained PAT' \
  'GITHUB_PAT' \
  'personal-access-token' \
  'token approval' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    { echo "FAIL: module 05 missing $text" >&2; exit 1; }
done

if grep -E 'GitHub App|GITHUB_APP_|KEDA GitHub App credential|private key' \
  "$DOC" >/dev/null; then
  echo "FAIL: module 05 still contains GitHub App guidance" >&2
  exit 1
fi

! grep -F -- '네 개 matrix Job이 성공한 화면' "$DOC" >/dev/null || { echo "FAIL: module 05 still describes screenshot as four-job success" >&2; exit 1; }

printf 'PASS: parallel scale validation doc\n'
