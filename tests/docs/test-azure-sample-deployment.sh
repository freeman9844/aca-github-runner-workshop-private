#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/06-azure-sample-deployment.md"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"

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

DOC_TEXT="$(<"$DOC")"
WORKFLOW_TEXT="$(<"$WORKFLOW")"

for heading in \
  '# 06. VNet 제한 Blob 배포와 결과 확인' \
  '## 1. Storage service endpoint, firewall, RBAC 확인' \
  '## 2. VNet 제한 Blob workflow를 GitHub에 생성' \
  '## 3. GitHub Actions에서 Blob artifact 배포 실행' \
  '## 4. Blob checksum과 network boundary 결과 해석' \
  '## 5. Cloud Shell과 Azure Portal에서 control-plane 확인'; do
  assert_contains "$DOC_TEXT" "$heading" 'module 06 missing heading'
done

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
  'defaultAction=Allow'; do
  assert_contains "$DOC_TEXT" "$text" 'module 06 missing VNet-restricted Blob marker'
done

section_one="$(
  awk '
    /^## 1\. / { in_section=1 }
    /^## 2\. / { exit }
    in_section { print }
  ' "$DOC"
)"
section_five="$(
  awk '
    /^## 5\. / { in_section=1 }
    /^## 트러블슈팅$/ { exit }
    in_section { print }
  ' "$DOC"
)"
public_network_expectation='`publicNetworkAccess`는 `Enabled`여야 합니다.'
assert_contains "$section_one" "$public_network_expectation" \
  'module 06 section 1 must state publicNetworkAccess=Enabled'
assert_contains "$section_five" "$public_network_expectation" \
  'module 06 section 5 must state publicNetworkAccess=Enabled'

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
