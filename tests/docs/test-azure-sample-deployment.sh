#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/06-azure-sample-deployment.md"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"
RUN_WORKFLOW_IMAGE="$ROOT/docs/images/06-github-actions-run-workflow.png"
WORKFLOW_RESULT_IMAGE="$ROOT/docs/images/06-github-actions-workflow-result.png"

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

[[ -f "$DOC" ]] || fail "module 06 missing"
[[ -f "$WORKFLOW" ]] || fail "sample workflow missing"
[[ -f "$RUN_WORKFLOW_IMAGE" ]] || fail "module 06 GitHub Actions Run workflow image missing"
[[ "$(sha256sum "$RUN_WORKFLOW_IMAGE" | cut -d' ' -f1)" == "b1a2c3b8b635872ff8b4a0287e9870ed58b00e808f60b9d555b6c6d3ec26ed1b" ]] ||
  fail "module 06 GitHub Actions Run workflow image is not the approved screenshot"
[[ -f "$WORKFLOW_RESULT_IMAGE" ]] || fail "module 06 GitHub Actions workflow result image missing"
[[ "$(sha256sum "$WORKFLOW_RESULT_IMAGE" | cut -d' ' -f1)" == "bcefd0392e76ebd7d4df4bf604ead5b08d37dd774f341a6c99843310a273b207" ]] ||
  fail "module 06 GitHub Actions workflow result image is not the approved screenshot"

DOC_TEXT="$(<"$DOC")"
WORKFLOW_TEXT="$(<"$WORKFLOW")"

for heading in \
  '# 06. VNet 제한 Blob 배포와 결과 확인' \
  '## 1. Storage service endpoint, firewall, RBAC 확인' \
  '## 2. VNet 제한 Blob workflow를 GitHub에 생성' \
  '## 3. GitHub Actions에서 Blob artifact 배포 실행'; do
  assert_contains "$DOC_TEXT" "$heading" 'module 06 missing heading'
done
for removed_heading in \
  '## 4. Blob checksum과 network boundary 결과 해석' \
  '## 5. Cloud Shell과 Azure Portal에서 control-plane 확인'; do
  if grep -F -- "$removed_heading" "$DOC" >/dev/null; then
    fail "module 06 still contains redundant heading: $removed_heading"
  fi
done

section_three="$(
  awk '
    /^## 3\. / { in_section=1 }
    /^## 트러블슈팅$/ { exit }
    in_section { print }
  ' "$DOC"
)"
assert_contains "$section_three" \
  '![GitHub Actions에서 VNet 제한 Blob workflow의 Run workflow 메뉴를 연 화면](images/06-github-actions-run-workflow.png)' \
  'module 06 step 3 GitHub Actions screenshot missing'
run_workflow_image_line="$(printf '%s\n' "$section_three" | grep -nF 'images/06-github-actions-run-workflow.png' | head -n1 | cut -d: -f1)"
expected_output_line="$(printf '%s\n' "$section_three" | grep -nF '📋 **예상 출력**' | head -n1 | cut -d: -f1)"
[[ -n "$run_workflow_image_line" && -n "$expected_output_line" &&
   "$run_workflow_image_line" -lt "$expected_output_line" ]] ||
  fail "module 06 step 3 screenshot must appear after execution guidance and before expected output"
assert_contains "$section_three" \
  '![GitHub Actions에서 VNet 제한 Blob workflow가 성공하고 Blob 결과를 출력한 화면](images/06-github-actions-workflow-result.png)' \
  'module 06 step 3 GitHub Actions result screenshot missing'
for text in \
  'DNS 해석 결과는 network proof가 아닙니다.' \
  'Blob data-plane success와 1단계의 control-plane 검증을 함께 확인해야 합니다.' \
  'normal child-environment non-inheritance' \
  'Cloud Shell에서 같은 Blob data-plane 명령을 실행하면 403이 expected입니다.'; do
  assert_contains "$section_three" "$text" \
    'module 06 step 3 must retain essential result interpretation'
done
section_three_last_line="$(printf '%s\n' "$section_three" | awk 'NF { line=$0 } END { print line }')"
[[ "$section_three_last_line" == '![GitHub Actions에서 VNet 제한 Blob workflow가 성공하고 Blob 결과를 출력한 화면](images/06-github-actions-workflow-result.png)' ]] ||
  fail "module 06 GitHub Actions result screenshot must be the final content in step 3"

workflow_block="$(
  awk '
    /<summary>.*yml 전체 내용 보기<\/summary>/ { in_summary=1; next }
    in_summary && /^```yaml$/ { in_yaml=1; next }
    in_yaml && /^```$/ { exit }
    in_yaml { print }
  ' "$DOC"
)"
[[ -n "$workflow_block" ]] || fail "module 06 missing workflow disclosure"
if [[ "$workflow_block" != "$WORKFLOW_TEXT" ]]; then
  fail "module 06 workflow disclosure must byte-match samples/azure-sample-deploy-workflow.yml"
fi

assert_contains "$DOC_TEXT" 'Module 01에서 저장한 `SUFFIX`를 그대로 사용하고, Module 02에서 이름 충돌 복구로 변경한 실제 ACR 또는 Storage 이름이 있으면 해당 값을 복원합니다.' 'module 06 must preserve Module 02 ownership of collision-recovered ACR or Storage names'

section_one="$(
  awk '
    /^## 1\. / { in_section=1 }
    /^## 2\. / { exit }
    in_section { print }
  ' "$DOC"
)"
for text in \
  'UAMI="${UAMI:-id-acarunner-$SUFFIX}"' \
  'STORAGE_ID=$(az storage account show' \
  'UAMI_PID=$(az identity show' \
  'runner UAMI principal ID를 현재 Azure identity에서 다시 조회합니다.'; do
  assert_contains "$section_one" "$text" \
    'module 06 section 1 must restore missing Storage and UAMI identifiers'
done

for text in \
  'Storage Blob Data Contributor' \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY' \
  'ERROR: GitHub App bootstrap variable reached the workflow environment:' \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'Microsoft.Storage' \
  'SUBNET_ID' \
  'virtualNetworkRules' \
  'bypass' \
  'External ACA Job은 ingress를 지원하지 않으며' \
  'inbound reachability를 증명하지 않습니다' \
  'normal child-environment non-inheritance' \
  'malicious code with access to the Job'\''s managed identity/runtime boundary' \
  'az storage blob upload' \
  'az storage blob download' \
  '--auth-mode login' \
  'sha256sum' \
  'Cloud Shell은 control-plane만 확인합니다.' \
  'Cloud Shell에서 같은 Blob data-plane 명령을 실행하면 403' \
  'defaultAction=Allow' \
  'export AZURE_CONFIG_DIR="${RUNNER_TEMP:?RUNNER_TEMP is required}/.azure"' \
  'mkdir -p "$AZURE_CONFIG_DIR"' \
  'printf '\''AZURE_CONFIG_DIR=%s\n'\'' "$AZURE_CONFIG_DIR" >> "$GITHUB_ENV"' \
  'job-level `env`에서는 `${{ runner.temp }}`를 사용할 수 없으므로' \
  '# GitHub Actions 화면에 표시할 workflow 이름입니다.' \
  '# User-Assigned Managed Identity로 Azure에 로그인합니다.' \
  '# VNet으로 제한된 Blob에 artifact를 업로드한 뒤 다시 내려받아 검증합니다.'; do
  assert_contains "$DOC_TEXT" "$text" 'module 06 missing VNet-restricted Blob marker'
done

public_network_expectation='`publicNetworkAccess`는 `Enabled`여야 합니다.'
assert_contains "$section_one" "$public_network_expectation" \
  'module 06 section 1 must state publicNetworkAccess=Enabled'

for old_screenshot in \
  'images/06-azure-portal-resource-group-result.png' \
  'images/06-container-app-hello-world-result.png' \
  'images/06-github-workflows-console.png' \
  'images/06-github-run-workflow-dispatch.png' \
  'images/06-github-deployment-success-details.png'; do
  if grep -F -- "$old_screenshot" "$DOC" >/dev/null; then
    fail "module 06 still references obsolete screenshot: $old_screenshot"
  fi
done

for forbidden in \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'PRIVATE_ENDPOINT_CIDR' \
  'privatelink.blob.core.windows.net' \
  'STORAGE_DNS_ZONE' \
  'PE_SUBNET' \
  'private IP' \
  'Container Apps Contributor' \
  'AZURE_SAMPLE_''APP' \
  'SAMPLE_APP' \
  'hello-''aca' \
  'containerapp create' \
  'internal ''ingress' \
  'same ACA Environment' \
  'APP_URL' \
  'FQDN'; do
  if grep -F -- "$forbidden" "$DOC" "$WORKFLOW" >/dev/null; then
    fail "obsolete sample-app or Private DNS architecture still present: $forbidden"
  fi
done

printf 'PASS: VNet-restricted Blob deployment doc and workflow disclosure\n'
