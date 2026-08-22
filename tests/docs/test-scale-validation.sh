#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"
RUN_WORKFLOW_IMAGE="$ROOT/docs/images/05-github-actions-run-workflow.png"

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

[[ -f "$DOC" ]] || fail "module 05 missing"
[[ -f "$RUN_WORKFLOW_IMAGE" ]] || fail "module 05 GitHub Actions Run workflow image missing"
[[ "$(sha256sum "$RUN_WORKFLOW_IMAGE" | cut -d' ' -f1)" == "8aed85c353ed49ca3e838c8255a0c52e6df6f0f87cb1f324c54aa4e4b71f767b" ]] ||
  fail "module 05 GitHub Actions Run workflow image is not the approved screenshot"

DOC_TEXT="$(<"$DOC")"

step_four="$(
  awk '
    /^## 4\. / { in_section=1 }
    /^## 5\. / { exit }
    in_section { print }
  ' "$DOC"
)"
assert_contains "$step_four" \
  '![GitHub Actions에서 Run workflow 메뉴를 연 화면](images/05-github-actions-run-workflow.png)' \
  'module 05 step 4 Run workflow screenshot missing'
run_workflow_image_line="$(printf '%s\n' "$step_four" | grep -nF 'images/05-github-actions-run-workflow.png' | head -n1 | cut -d: -f1)"
expected_output_line="$(printf '%s\n' "$step_four" | grep -nF '📋 **예상 출력**' | head -n1 | cut -d: -f1)"
[[ -n "$run_workflow_image_line" && -n "$expected_output_line" &&
   "$run_workflow_image_line" -lt "$expected_output_line" ]] ||
  fail "module 05 step 4 Run workflow screenshot must appear immediately after execution guidance"

step_five="$(
  awk '
    /^## 5\. / { in_section=1 }
    /^## 6\. / { exit }
    in_section { print }
  ' "$DOC"
)"
assert_contains \
  "$step_five" \
  $'job-ghrunner-717094-c5jhk  Running   2026-08-22T14:40:22+00:00\njob-ghrunner-717094-db6km  Running   2026-08-22T14:40:22+00:00\njob-ghrunner-717094-jkjx4  Running   2026-08-22T14:40:22+00:00\njob-ghrunner-717094-v2rz4  Running   2026-08-22T14:40:22+00:00' \
  'module 05 step 5 expected output must use the verified four-execution example'

step_seven="$(
  awk '
    /^## 7\. / { in_section=1 }
    /^## 8\. / { exit }
    in_section { print }
  ' "$DOC"
)"
for text in \
  'wait_for_containerapp_console_logs() {' \
  "trap 'log_wait_interrupted=1' INT" \
  'return 130' \
  'if wait_for_containerapp_console_logs; then' \
  'LOG_WAIT_STATUS=$?' \
  'Cloud Shell 세션은 유지됩니다.' \
  'trap - INT' \
  'unset -f wait_for_containerapp_console_logs'; do
  assert_contains "$step_seven" "$text" \
    'module 05 step 7 interruption-safe wait handling missing'
done
if [[ "$step_seven" == *'exit 1'* ]]; then
  fail 'module 05 step 7 must not exit the interactive Cloud Shell session'
fi
job_filter_count="$(printf '%s\n' "$step_seven" | grep -cF "| where JobName == '\$JOB'" || true)"
[[ "$job_filter_count" -eq 3 ]] ||
  fail "module 05 step 7 must apply the same JobName filter to wait, aggregate, and detail queries"
assert_contains "$step_seven" \
  'resource-specific `ContainerAppConsoleLogs`의 `JobName` 열로 현재 ACA Job 로그만 조회합니다.' \
  'module 05 step 7 must explain the resource-specific JobName filter'
if [[ "$step_seven" == *"ContainerGroupName startswith '\$EXECUTION'"* ]]; then
  fail 'module 05 step 7 must not depend on one possibly stale execution prefix'
fi
if [[ "$step_seven" == *'TimeGenerated > ago(30m)'* ]]; then
  fail 'module 05 step 7 detail query must use the same two-hour window as ingestion checks'
fi

recovery_section="$(
  awk '
    BEGIN { in_section = 0 }
    /^## 0\. 세션 재연결 시 변수 복구 \(선택\)$/ { in_section = 1; next }
    /^## 1\./ { if (in_section) exit }
    in_section { print }
  ' "$DOC"
)"

assert_contains "$recovery_section" 'read -rp "Saved GITHUB_APP_ID:' 'module 05 GitHub App ID recovery prompt missing'
assert_contains "$recovery_section" 'read -rp "Saved GITHUB_APP_INSTALLATION_ID:' 'module 05 GitHub App installation ID recovery prompt missing'
assert_contains "$recovery_section" 'GITHUB_APP_ID=' 'module 05 GitHub App ID restore missing'
assert_contains "$recovery_section" 'GITHUB_APP_INSTALLATION_ID=' 'module 05 GitHub App installation ID restore missing'
assert_contains "$recovery_section" 'Module 01에서 저장한 `SUFFIX`를 그대로 사용하고, Module 02에서 이름 충돌 복구로 변경한 실제 ACR 또는 Storage 이름이 있으면 해당 값을 복원합니다.' 'module 05 must preserve Module 02 ownership of collision-recovered ACR or Storage names'

for text in \
  '## 0. 세션 재연결 시 변수 복구 (선택)' \
  'INFRA_SUBNET="snet-aca-infra"' \
  'SUBNET_ID=$(az network vnet subnet show' \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_ID=$(az storage account show' \
  'KEY_VAULT_ID=$(az keyvault show' \
  'Microsoft.Storage' \
  'Microsoft.KeyVault' \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'Jobs do not support ingress'; do
  assert_contains "$DOC_TEXT" "$text" 'module 05 recovery/service-endpoint marker missing'
done

for text in \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  'applicationID' \
  'installationID' \
  'appKey' \
  'GitHub App installation' \
  'Key Vault' \
  'identityref' \
  'Key Vault Secrets User' \
  'publicNetworkAccess' \
  'defaultAction=Deny' \
  'bypass=None' \
  '401' \
  '403'; do
  assert_contains "$DOC_TEXT" "$text" 'module 05 GitHub App failure marker missing'
done

assert_contains "$DOC_TEXT" '### Key Vault resolution failure memo' 'module 05 key vault resolution memo missing'
for text in \
  'Module 04 Key Vault reference synchronization/execution 성공이 acceptance gate입니다.' \
  'live rehearsal' \
  '저장소 테스트만으로 증명할 수 없습니다.' \
  '워크숍 delivery를 중단하고 환경별 platform path를 조사하세요.' \
  '`defaultAction=Deny`를 완화하거나 성공처럼 보이는 fallback을 추가하지 마세요.'; do
  assert_contains "$DOC_TEXT" "$text" 'module 05 Key Vault caveat missing'
done
assert_contains "$DOC_TEXT" '`Runner configured`' 'module 05 configured lifecycle marker missing'
assert_contains "$DOC_TEXT" '`Runner process exited`' 'module 05 exit lifecycle marker missing'

if grep -F -- 'Requesting registration token' "$DOC" >/dev/null; then
  fail "module 05 references a lifecycle marker that entrypoint does not emit"
fi

for obsolete in \
  'Fine-grained PAT' \
  'GITHUB_PAT' \
  'personalAccessToken' \
  'personal-access-token'; do
  if grep -F -- "$obsolete" "$DOC" >/dev/null; then
    fail "obsolete PAT guidance still present: $obsolete"
  fi
done

for obsolete in \
  'AZURE_SAMPLE_''APP' \
  'internal ''Environment' \
  'same ''Environment' \
  'internal ''ingress'; do
  if grep -F -- "$obsolete" "$DOC" >/dev/null; then
    fail "obsolete internal-sample-app text still present: $obsolete"
  fi
done

for forbidden in \
  'PE_SUBNET' \
  'STORAGE_PE' \
  'KEY_VAULT_PE' \
  'STORAGE_DNS_ZONE' \
  'KEY_VAULT_DNS_ZONE' \
  'PRIVATE_ENDPOINT_CIDR' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'privatelink.'; do
  if grep -F -- "$forbidden" "$DOC" >/dev/null; then
    fail "module 05 still contains obsolete Private Link state: $forbidden"
  fi
done

printf 'PASS: scale validation doc\n'
