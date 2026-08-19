#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"
QUEUED_SCREENSHOT="$ROOT/docs/images/05-github-actions-queued-matrix.png"
SUCCESS_SCREENSHOT="$ROOT/docs/images/05-github-actions-successful-matrix.png"
NO_RUNNERS_SCREENSHOT="$ROOT/docs/images/05-github-actions-no-self-hosted-runners.png"
[[ -f "$DOC" ]] || { echo "FAIL: module 05 missing" >&2; exit 1; }
[[ -f "$QUEUED_SCREENSHOT" ]] || { echo "FAIL: module 05 queued screenshot missing" >&2; exit 1; }
[[ -f "$SUCCESS_SCREENSHOT" ]] || { echo "FAIL: module 05 successful matrix screenshot missing" >&2; exit 1; }
[[ -f "$NO_RUNNERS_SCREENSHOT" ]] || { echo "FAIL: module 05 no-runners screenshot missing" >&2; exit 1; }
[[ ! -x "$NO_RUNNERS_SCREENSHOT" ]] || { echo "FAIL: module 05 no-runners screenshot must not be executable" >&2; exit 1; }

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -Fx '## 0. 세션 재연결 시 변수 복구 (선택)' "$DOC" >/dev/null ||
  fail "module 05 missing optional Step 0 recovery heading"
step_numbers="$(sed -nE 's/^## ([0-9]+)\..*/\1/p' "$DOC" | paste -sd ' ' -)"
[[ "$step_numbers" == '0 1 2 3 4 5 6 7 8 9 10' ]] ||
  fail "module 05 numbered steps must run consecutively from 0 through 10"
grep -Fx '## 8. GitHub에서 네 개 Job 성공과 runner hostname 차이 확인' "$DOC" >/dev/null ||
  fail "module 05 missing renumbered Step 8 heading"
grep -Fx '## 9. Running execution이 다시 0으로 돌아오는지 확인' "$DOC" >/dev/null ||
  fail "module 05 missing renumbered Step 9 heading"
grep -Fx '## 10. GitHub Settings에서 permanent online runner가 남지 않았는지 확인' "$DOC" >/dev/null ||
  fail "module 05 missing renumbered Step 10 heading"
if grep -Fx '## 8. runner lifecycle marker를 명시적으로 검증' "$DOC" >/dev/null; then
  fail "module 05 still contains the redundant lifecycle-marker step"
fi
details_open_line="$(grep -nF -m1 '<details>' "$DOC" | cut -d: -f1)"
summary_line="$(grep -nF -m1 '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$DOC" | cut -d: -f1)"
details_close_line="$(grep -nF -m1 '</details>' "$DOC" | cut -d: -f1)"
[[ "$(grep -Fc '<details>' "$DOC")" -eq 1 ]] ||
  fail "module 05 must contain exactly one details block"
[[ "$(grep -Fc '</details>' "$DOC")" -eq 1 ]] ||
  fail "module 05 must close exactly one details block"
[[ -n "$details_open_line" && -n "$summary_line" && -n "$details_close_line" ]] ||
  fail "module 05 missing recovery disclosure structure"
(( details_open_line < summary_line && summary_line < details_close_line )) ||
  fail "module 05 recovery summary must be inside the details block"
summary_next_line="$(sed -n "$((summary_line + 1))p" "$DOC")"
details_prev_line="$(sed -n "$((details_close_line - 1))p" "$DOC")"
[[ -z "${summary_next_line//[[:space:]]/}" ]] ||
  fail "module 05 summary must be followed by a blank line"
[[ -z "${details_prev_line//[[:space:]]/}" ]] ||
  fail "module 05 details close must be preceded by a blank line"

legend_line="$(grep -nF -m1 '## 태그 범례' "$DOC" | cut -d: -f1)"
(( details_close_line < legend_line )) ||
  fail "module 05 recovery details must close before the tag legend"

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
  '기존 workflow가 이미 있으면' \
  '![GitHub Actions에서 네 개 matrix Job이 queued 상태인 화면](images/05-github-actions-queued-matrix.png)' \
  'Worker 1은 성공했고 Worker 4는 아직 진행 중인 중간 상태' \
  '![GitHub Actions Self-hosted runners 목록이 비어 있는 정상 화면](images/05-github-actions-no-self-hosted-runners.png)' \
  '# 수동 실행으로만 scale test를 시작합니다.' \
  'name: ACA Runner Scale Test' \
  'workflow_dispatch:' \
  'runs-on: [aca-runner]' \
  'custom label만 요구합니다.' \
  'timeout-minutes: 10' \
  'fail-fast: false' \
  'worker: [1, 2, 3, 4]' \
  'Hold the runner for scale observation' \
  'sleep 45' \
  'az containerapp job execution list' \
  'properties.status' \
  'job-ghrunner-145945-4vql7  Running   2026-08-19T05:10:51+00:00' \
  'az containerapp job logs show' \
  "Well known directory 'Root': '/home/runner'" \
  "File name: '/usr/bin/bash'" \
  "Working directory: '/home/runner/_work/aca-runner-lab/aca-runner-lab'" \
  'Process started with process id' \
  'Try to upload 2 log files or attachments, success rate: 2/2.' \
  'if [[ -z "$EXECUTION" ]]' \
  'ERROR: Container Apps Job execution이 없습니다.' \
  '--container github-actions-runner' \
  'ContainerAppConsoleLogs' \
  'TimeGenerated > ago(2h)' \
  'summarize Count=count(), LastSeen=max(TimeGenerated)' \
  'job-ghrunner-145945-xh6w5-phfkj  2058' \
  'PrimaryResult' \
  'ContainerGroupName startswith' \
  '5~10분' \
  'job-ghrunner-$SUFFIX-' \
  '다른 Event Job이 같은 repository와 `aca-runner` label' \
  'Runner configured' \
  'Runner process exited' \
  'active execution 수는 0'; do
  grep -F -- "$text" "$DOC" >/dev/null || { echo "FAIL: module 05 missing $text" >&2; exit 1; }
done

[[ "$(grep -Ec '^job-ghrunner-145945-[[:alnum:]]+[[:space:]]+Running' "$DOC")" -eq 4 ]] ||
  fail "module 05 must show four Running execution rows"

if grep -F 'runs-on: [self-hosted, linux, x64, aca-runner]' "$DOC" >/dev/null; then
  fail "module 05 still requires default self-hosted runner labels"
fi

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
grep -Fx 'Module 06은 선택이며, 90분 핵심 경로가 필요하면 [Module 07 정리 문서](07-security-limitations-cleanup.md)로 바로 이동해도 됩니다.' "$DOC" >/dev/null ||
  fail "module 05 missing Module 07 cleanup shortcut link"
if grep -F '현재 정리 문서' "$DOC" >/dev/null; then
  fail "module 05 still contains obsolete cleanup shortcut wording"
fi

printf 'PASS: parallel scale validation doc\n'
