#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"
RUN_WORKFLOW_IMAGE="$ROOT/docs/images/05-github-actions-run-workflow.png"
REMOVED_RUNNERS_IMAGE="$ROOT/docs/images/05-github-actions-no-self-hosted-runners.png"

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
[[ ! -e "$REMOVED_RUNNERS_IMAGE" ]] ||
  fail "module 05 obsolete no-self-hosted-runners screenshot must be removed"

DOC_TEXT="$(<"$DOC")"
for removed_section in \
  '## GitHub App 실패 검증 메모' \
  '### KEDA authentication failure memo' \
  '### Key Vault resolution failure memo' \
  '### Runner registration failure memo' \
  '## 10. GitHub Settings에서 permanent online runner가 남지 않았는지 확인'; do
  if grep -F -- "$removed_section" "$DOC" >/dev/null; then
    fail "module 05 still contains removed section: $removed_section"
  fi
done
if grep -F -- 'images/05-github-actions-no-self-hosted-runners.png' "$DOC" >/dev/null; then
  fail "module 05 still references the removed no-self-hosted-runners screenshot"
fi

step_three="$(
  awk '
    /^## 3\. / { in_section=1 }
    /^## 4\. / { exit }
    in_section { print }
  ' "$DOC"
)"
assert_contains "$step_three" \
  '![GitHub Actions에서 Run workflow 메뉴를 연 화면](images/05-github-actions-run-workflow.png)' \
  'module 05 step 3 Run workflow screenshot missing'
run_workflow_image_line="$(printf '%s\n' "$step_three" | grep -nF 'images/05-github-actions-run-workflow.png' | head -n1 | cut -d: -f1)"
expected_output_line="$(printf '%s\n' "$step_three" | grep -nF '📋 **예상 출력**' | head -n1 | cut -d: -f1)"
[[ -n "$run_workflow_image_line" && -n "$expected_output_line" &&
   "$run_workflow_image_line" -lt "$expected_output_line" ]] ||
  fail "module 05 step 3 Run workflow screenshot must appear immediately after execution guidance"

step_four="$(
  awk '
    /^## 4\. / { in_section=1 }
    /^## 5\. / { exit }
    in_section { print }
  ' "$DOC"
)"
assert_contains \
  "$step_four" \
  $'job-ghrunner-717094-c5jhk  Running   2026-08-22T14:40:22+00:00\njob-ghrunner-717094-db6km  Running   2026-08-22T14:40:22+00:00\njob-ghrunner-717094-jkjx4  Running   2026-08-22T14:40:22+00:00\njob-ghrunner-717094-v2rz4  Running   2026-08-22T14:40:22+00:00' \
  'module 05 step 4 expected output must use the verified four-execution example'

step_six="$(
  awk '
    /^## 6\. / { in_section=1 }
    /^## 7\. / { exit }
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
  assert_contains "$step_six" "$text" \
    'module 05 step 6 interruption-safe wait handling missing'
done
if [[ "$step_six" == *'exit 1'* ]]; then
  fail 'module 05 step 6 must not exit the interactive Cloud Shell session'
fi
job_filter_count="$(printf '%s\n' "$step_six" | grep -cF "| where JobName == '\$JOB'" || true)"
[[ "$job_filter_count" -eq 3 ]] ||
  fail "module 05 step 6 must apply the same JobName filter to wait, aggregate, and detail queries"
assert_contains "$step_six" \
  'resource-specific `ContainerAppConsoleLogs`의 `JobName` 열로 현재 ACA Job 로그만 조회합니다.' \
  'module 05 step 6 must explain the resource-specific JobName filter'
if [[ "$step_six" == *"ContainerGroupName startswith '\$EXECUTION'"* ]]; then
  fail 'module 05 step 6 must not depend on one possibly stale execution prefix'
fi
if [[ "$step_six" == *'TimeGenerated > ago(30m)'* ]]; then
  fail 'module 05 step 6 detail query must use the same two-hour window as ingestion checks'
fi

recovery_section="$(
  awk '
    BEGIN { in_section = 0 }
    /^## 0\. 세션 재연결 시 변수 복구 \(선택\)$/ { in_section = 1; next }
    /^## 1\./ { if (in_section) exit }
    in_section { print }
  ' "$DOC"
)"

for text in \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'RG="rg-acarunner-$SUFFIX"' \
  'LOG="log-acarunner-$SUFFIX"' \
  'JOB="job-ghrunner-$SUFFIX"' \
  'LOG_ID=$(az monitor log-analytics workspace show'; do
  assert_contains "$recovery_section" "$text" \
    'module 05 minimal recovery contract missing'
done

for removed_text in \
  'Saved ACR name' \
  'Saved GITHUB_APP_ID' \
  'Saved GITHUB_APP_INSTALLATION_ID' \
  'Saved Storage account name if changed' \
  'Saved Key Vault name if changed' \
  'STORAGE_ID=$(az storage account show' \
  'KEY_VAULT_ID=$(az keyvault show'; do
  if printf '%s\n' "$recovery_section" | grep -F -- "$removed_text" >/dev/null; then
    fail "module 05 recovery still restores unused state: $removed_text"
  fi
done

for heading in \
  '## 1. 샘플 workflow를 Cloud Shell에서 열고 GitHub 웹 UI로 생성' \
  '## 2. 실행 전 baseline 이력과 active execution 0 상태 확인' \
  '## 3. GitHub Actions에서 `ACA Runner Scale Test`를 수동 실행' \
  '## 4. 첫 30~90초 동안 Running execution만 반복 조회' \
  '## 5. 가장 최근 execution을 잡아 CLI 로그 확인' \
  '## 6. Log Analytics에서 resource-specific `ContainerAppConsoleLogs`를 KQL로 확인' \
  '## 7. GitHub에서 네 개 Job 성공과 runner hostname 차이 확인' \
  '## 8. Running execution이 다시 0으로 돌아오는지 확인'; do
  assert_contains "$DOC_TEXT" "$heading" 'module 05 compact heading sequence missing'
done

if grep -F -- '## 2. matrix 4 Job 전체 YAML 확인' "$DOC" >/dev/null; then
  fail 'module 05 still duplicates the checked-in workflow YAML'
fi

for text in \
  '## 0. 세션 재연결 시 변수 복구 (선택)' \
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
