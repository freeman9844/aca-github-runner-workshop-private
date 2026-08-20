#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"
DOC="$ROOT/docs/06-azure-sample-deployment.md"
MODULE05_DOC="$ROOT/docs/05-parallel-scale-validation.md"
GITHUB_WORKFLOWS_SCREENSHOT="$ROOT/docs/images/06-github-workflows-console.png"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$DOC" ]] || fail "Module 06 missing"
[[ -f "$WORKFLOW" ]] || fail "Azure sample deployment workflow missing"
[[ -f "$MODULE05_DOC" ]] || fail "Module 05 missing"
[[ -f "$GITHUB_WORKFLOWS_SCREENSHOT" ]] || fail "Module 06 GitHub workflows screenshot missing"
[[ ! -x "$GITHUB_WORKFLOWS_SCREENSHOT" ]] || fail "Module 06 GitHub workflows screenshot must not be executable"

for heading in \
  '# 06. Azure 샘플 배포와 결과 확인' \
  '## 0. 세션 재연결 시 변수 복구 (선택)' \
  '## 1. 배포 권한 확인과 Container Apps Contributor 부여' \
  '## 2. 샘플 workflow를 GitHub에 생성' \
  '## 3. GitHub Actions에서 배포 실행' \
  '## 4. 같은 ACA Environment 내부에서 internal ingress 앱에 접근할 수 있는 이유' \
  '## 5. 기본 Cloud Shell과 Azure Portal에서 확인' \
  '## 트러블슈팅'; do
  grep -F "$heading" "$DOC" >/dev/null ||
    fail "Module 06 missing heading $heading"
done

details_open_line="$(grep -nF -m1 '<details>' "$DOC" | cut -d: -f1)"
summary_line="$(grep -nF -m1 '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$DOC" | cut -d: -f1)"
details_close_line="$(grep -nF -m1 '</details>' "$DOC" | cut -d: -f1)"
legend_line="$(grep -nF -m1 '## 태그 범례' "$DOC" | cut -d: -f1)"
[[ "$(grep -Fc '<details>' "$DOC")" -eq 2 ]] ||
  fail "Module 06 must contain recovery and workflow details blocks"
[[ "$(grep -Fc '</details>' "$DOC")" -eq 2 ]] ||
  fail "Module 06 must close recovery and workflow details blocks"
[[ -n "$details_open_line" && -n "$summary_line" && -n "$details_close_line" && -n "$legend_line" ]] ||
  fail "Module 06 missing recovery disclosure structure"
(( details_open_line < summary_line && summary_line < details_close_line && details_close_line < legend_line )) ||
  fail "Module 06 recovery details must close before the tag legend"

summary_next_line="$(sed -n "$((summary_line + 1))p" "$DOC")"
details_prev_line="$(sed -n "$((details_close_line - 1))p" "$DOC")"
[[ -z "${summary_next_line//[[:space:]]/}" ]] ||
  fail "Module 06 summary must be followed by a blank line"
[[ -z "${details_prev_line//[[:space:]]/}" ]] ||
  fail "Module 06 details close must be preceded by a blank line"

subscription_prompt_line="$(grep -nF -m1 'read -rp "Saved subscription ID: " SUBSCRIPTION_ID' "$DOC" | cut -d: -f1 || true)"
account_set_line="$(grep -nF -m1 'az account set --subscription "$SUBSCRIPTION_ID"' "$DOC" | cut -d: -f1 || true)"
identity_show_line="$(grep -nF -m1 'UAMI_CLIENT_ID=$(az identity show' "$DOC" | cut -d: -f1 || true)"
[[ -n "$subscription_prompt_line" && -n "$account_set_line" && -n "$identity_show_line" ]] ||
  fail "Module 06 missing saved subscription recovery commands"
(( subscription_prompt_line < account_set_line && account_set_line < identity_show_line )) ||
  fail "Module 06 must restore the saved subscription before az identity show"

for text in \
  '필수 모듈입니다.' \
  'samples/azure-sample-deploy-workflow.yml' \
  '.github/workflows/aca-runner-azure-deploy.yml' \
  'Container Apps Contributor' \
  'Container Apps Job 권한은 포함하지 않습니다.' \
  'private repository' \
  'trusted workflow authors' \
  '식별자' \
  'credentials' \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved subscription ID: " SUBSCRIPTION_ID' \
  'az account set --subscription "$SUBSCRIPTION_ID"' \
  'RG="rg-acarunner-$SUFFIX"' \
  'ENV="env-acarunner-$SUFFIX"' \
  'UAMI="id-acarunner-$SUFFIX"' \
  'SAMPLE_APP="hello-aca-$SUFFIX"' \
  'UAMI_CLIENT_ID=$(az identity show' \
  'UAMI_PID=$(az identity show' \
  'RG_ID=$(az group show' \
  'ENV_STATE=$(az containerapp env show' \
  'CONTAINER_APPS_ROLE=$(az role assignment list' \
  "--query \"[?roleDefinitionName=='Container Apps Contributor' && scope=='\$RG_ID'].roleDefinitionName | [0]\"" \
  'if [[ "$CONTAINER_APPS_ROLE" != "Container Apps Contributor" ]]' \
  'for role_attempt in $(seq 1 30); do' \
  'Waiting for Container Apps Contributor assignment visibility' \
  'ERROR: Container Apps Contributor was not visible after 30 checks.' \
  '실제 managed identity 권한 전파 완료를 보장하지 않습니다.' \
  '--assignee-object-id "$UAMI_PID"' \
  '--assignee-principal-type ServicePrincipal' \
  '--role "Container Apps Contributor"' \
  '--scope "$RG_ID"' \
  '--name "$UAMI"' \
  '--query clientId' \
  'az login --identity --client-id' \
  'mcr.microsoft.com/k8se/quickstart@sha256:9f41c026ef51e985a271eed474995ea08c0d6a5a4939e65622ed03c3fcc9fb2c' \
  'Actions → ACA Runner Azure Sample Deploy → Run workflow' \
  'APP_URL=https://' \
  'az containerapp show' \
  'https://$FQDN' \
  'Container App' \
  'Azure Portal' \
  'Verify the internal HTTPS endpoint from the runner' \
  'Verified internal endpoint' \
  'externalIngress:properties.configuration.ingress.external' \
  'internal Environment' \
  '기본 Cloud Shell' \
  '같은 ACA Environment' \
  'Private DNS zone' \
  'VNet link' \
  'wildcard A record' \
  'externalIngress=false' \
  'Application Gateway' \
  'VM' \
  'az: command not found' \
  'az extension add --name containerapp --upgrade --version 0.3.55 --only-show-errors' \
  'AuthorizationFailed' \
  'No existing Container App named' \
  'behavior of this command has been altered' \
  'does not exist. Specify a valid environment' \
  '`AcrPull`만 있고' \
  'ERROR: Internal HTTP verification failed after 18 attempts:' \
  'stale runner workflow'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    fail "Module 06 missing $text"
done

for unexpected in \
  'images/06-github-actions-deployment-success.png' \
  'images/06-azure-portal-resource-group-result.png' \
  'images/06-container-app-hello-world-result.png' \
  '브라우저에서 `APP_URL`' \
  '브라우저에서는 sample page가 열리고' \
  'GitHub Actions, 브라우저, Cloud Shell, Portal 네 곳에서 같은 앱 이름과 URL을 가리키면 검증 완료입니다.'; do
  if grep -F -- "$unexpected" "$DOC" >/dev/null; then
    fail "Module 06 must not reference legacy public-access verification: $unexpected"
  fi
done

for assignment in \
  'AZURE_SUBSCRIPTION_ID=' \
  'AZURE_CLIENT_ID=$(az identity show' \
  'AZURE_SAMPLE_APP="hello-aca-$SUFFIX"'; do
  if grep -F "$assignment" "$DOC" >/dev/null; then
    fail "Module 06 must reserve $assignment for the runner environment contract"
  fi
done

[[ "$(grep -Fc 'SAMPLE_APP="hello-aca-$SUFFIX"' "$DOC")" -eq 2 ]] ||
  fail "Module 06 must initialize SAMPLE_APP in recovery and normal-session paths"

role_grant_heading_line="$(grep -nF -m1 '### Container Apps Contributor 권한 부여' "$DOC" | cut -d: -f1 || true)"
role_create_line="$(grep -nF -m1 'az role assignment create \' "$DOC" | cut -d: -f1 || true)"
step2_heading_line="$(grep -nF -m1 '## 2. 샘플 workflow를 GitHub에 생성' "$DOC" | cut -d: -f1)"
mapfile -t role_query_lines < <(
  grep -nF 'CONTAINER_APPS_ROLE=$(az role assignment list' "$DOC" |
    cut -d: -f1
)
[[ -n "$role_grant_heading_line" && -n "$role_create_line" && "${#role_query_lines[@]}" -eq 2 ]] ||
  fail "Module 06 missing explicit role grant and verification flow"
(( role_query_lines[0] < role_grant_heading_line &&
   role_grant_heading_line < role_create_line &&
   role_create_line < role_query_lines[1] &&
   role_query_lines[1] < step2_heading_line )) ||
  fail "Module 06 must check, grant, and recheck the role before Step 2"

step2_expected_line="$(grep -nF -m1 'reviewed sample과 같은 single-job workflow가 저장됩니다.' "$DOC" | cut -d: -f1)"
step3_heading_line="$(grep -nF -m1 '## 3. GitHub Actions에서 배포 실행' "$DOC" | cut -d: -f1)"
workflows_screenshot_line="$(grep -nF -m1 '![GitHub workflows 폴더에 배포 및 스케일 테스트 workflow가 준비된 화면](images/06-github-workflows-console.png)' "$DOC" | cut -d: -f1)"
[[ -n "$step2_expected_line" && -n "$workflows_screenshot_line" && -n "$step3_heading_line" ]] ||
  fail "Module 06 missing Step 2 workflows screenshot placement markers"
(( step2_expected_line < workflows_screenshot_line && workflows_screenshot_line < step3_heading_line )) ||
  fail "Module 06 workflows screenshot must follow Step 2 expected output"

workflow_summary_line="$(grep -nF -m1 '<summary>aca-runner-azure-deploy.yml 전체 내용 보기</summary>' "$DOC" | cut -d: -f1 || true)"
workflow_details_open_line="$(awk -v summary="$workflow_summary_line" 'NR < summary && $0 == "<details>" { line=NR } END { print line }' "$DOC")"
workflow_details_close_line="$(awk -v summary="$workflow_summary_line" 'NR > summary && $0 == "</details>" { print NR; exit }' "$DOC")"
[[ -n "$workflow_details_open_line" && -n "$workflow_summary_line" && -n "$workflow_details_close_line" ]] ||
  fail "Module 06 Step 2 missing collapsible aca-runner-azure-deploy.yml"
(( step2_heading_line < workflow_details_open_line &&
   workflow_details_open_line < workflow_summary_line &&
   workflow_summary_line < workflow_details_close_line &&
   workflow_details_close_line < step3_heading_line )) ||
  fail "Module 06 workflow details must stay inside Step 2"

if ! cmp -s "$WORKFLOW" <(
  awk '
    $0 == "<summary>aca-runner-azure-deploy.yml 전체 내용 보기</summary>" {
      in_workflow_details=1
      next
    }
    in_workflow_details && $0 == "```yaml" {
      in_workflow_yaml=1
      next
    }
    in_workflow_yaml && $0 == "```" {
      exit
    }
    in_workflow_yaml {
      print
    }
  ' "$DOC"
); then
  fail "Module 06 collapsible workflow must match the reviewed sample exactly"
fi

step4_heading_line="$(grep -nF -m1 '## 4. 같은 ACA Environment 내부에서 internal ingress 앱에 접근할 수 있는 이유' "$DOC" | cut -d: -f1)"
step5_heading_line="$(grep -nF -m1 '## 5. 기본 Cloud Shell과 Azure Portal에서 확인' "$DOC" | cut -d: -f1)"
step5_expected_line="$(grep -nF -m1 '기본 Cloud Shell에서 private endpoint에 바로 닿지 않는 것은 예상된 격리 동작입니다.' "$DOC" | cut -d: -f1 || true)"
troubleshooting_line="$(grep -nF -m1 '## 트러블슈팅' "$DOC" | cut -d: -f1)"
[[ -n "$step4_heading_line" && -n "$step5_heading_line" && -n "$step5_expected_line" && -n "$troubleshooting_line" ]] ||
  fail "Module 06 missing updated internal-ingress verification flow"
(( step3_heading_line < step4_heading_line &&
   step4_heading_line < step5_heading_line &&
   step5_heading_line < step5_expected_line &&
   step5_expected_line < troubleshooting_line )) ||
  fail "Module 06 must explain same-environment access before Cloud Shell isolation checks"

grep -Fx '[다음: Azure 샘플 배포와 결과 확인 →](06-azure-sample-deployment.md)' "$MODULE05_DOC" >/dev/null ||
  fail "Module 05 missing Module 06 navigation link"
grep -Fx 'Module 06은 필수 단계입니다. 위 링크로 이동해 Azure 샘플 배포와 결과 확인을 계속합니다.' "$MODULE05_DOC" >/dev/null ||
  fail "Module 05 must direct participants to required Module 06"
grep -Fx '[← 이전: 병렬 실행과 스케일 검증](05-parallel-scale-validation.md) | [다음: 보안·제약·정리 →](07-security-limitations-cleanup.md)' "$DOC" >/dev/null ||
  fail "Module 06 missing Module 07 navigation link"

for text in \
  'name: ACA Runner Azure Sample Deploy' \
  'on:' \
  'workflow_dispatch:' \
  'runs-on: [aca-runner]' \
  'timeout-minutes: 15' \
  '# 신뢰할 수 있는 워크숍 참가자가 수동으로 실행할 때만 시작합니다.' \
  '# 임시 ACA runner에 설정한 사용자 지정 label을 사용합니다.' \
  '# Azure 작업 전에 runner 환경 변수 계약이 완전한지 확인합니다.' \
  '# client secret 없이 runner managed identity로 Azure에 로그인합니다.' \
  '# 반복 실습도 동일한 상태에서 시작하도록 샘플 앱을 다시 생성합니다.' \
  '# 생성된 endpoint를 이후 workflow step과 공유합니다.' \
  '# 프로비저닝 후 internal ingress HTTPS가 runner에서 준비될 때까지 시간이 걸릴 수 있습니다.' \
  '# Azure Portal과 control-plane 조회를 비교할 수 있도록 최종 resource 정보를 출력합니다.' \
  'set -euo pipefail' \
  'az login --identity --client-id "$AZURE_CLIENT_ID"' \
  'az account set --subscription "$AZURE_SUBSCRIPTION_ID"' \
  'az containerapp create' \
  'az containerapp delete' \
  'container_app_exists()' \
  'ResourceNotFound|ContainerAppNotFound' \
  'ERROR: Failed to inspect Container App' \
  'deleted=false' \
  'for delete_attempt in $(seq 1 24); do' \
  'Waiting for Container App deletion (attempt %s/24).' \
  'Confirmed existing Container App deletion after %s checks.' \
  'ERROR: Timed out waiting for Container App deletion after 24 checks.' \
  '--image mcr.microsoft.com/k8se/quickstart@sha256:9f41c026ef51e985a271eed474995ea08c0d6a5a4939e65622ed03c3fcc9fb2c' \
  '--environment "$AZURE_CONTAINERAPPS_ENVIRONMENT"' \
  '--resource-group "$AZURE_RESOURCE_GROUP"' \
  '--name "$AZURE_SAMPLE_APP"' \
  '--ingress internal' \
  '--target-port 80' \
  '--min-replicas 0' \
  '--max-replicas 1' \
  'APP_URL="https://$FQDN"' \
  '>> "$GITHUB_ENV"' \
  'curl --fail --silent --show-error "$APP_URL"' \
  'Verify the internal HTTPS endpoint from the runner' \
  'Verified internal endpoint' \
  'ERROR: Internal HTTP verification failed after 18 attempts:' \
  'externalIngress:properties.configuration.ingress.external'; do
  grep -F -- "$text" "$WORKFLOW" >/dev/null ||
    fail "workflow missing $text"
done

if grep -F -- '--ingress external' "$WORKFLOW" >/dev/null; then
  fail "workflow must not use external ingress"
fi

[[ "$(grep -Fc 'runs-on:' "$WORKFLOW")" -eq 1 ]] ||
  fail "deployment workflow must contain exactly one job"

if ! awk '
  BEGIN { in_on=0; saw_workflow_dispatch=0; invalid_trigger=0 }
  /^on:[[:space:]]*$/ { in_on=1; next }
  in_on && /^[^[:space:]]/ { exit }
  in_on && /^[[:space:]]{2}[[:alnum:]_-]+:/ {
    trigger=$0
    sub(/^[[:space:]]+/, "", trigger)
    sub(/:.*/, "", trigger)
    if (trigger == "workflow_dispatch") {
      saw_workflow_dispatch=1
    } else {
      invalid_trigger=1
    }
  }
  END { exit !(saw_workflow_dispatch && !invalid_trigger) }
' "$WORKFLOW"; then
  fail "workflow must only define the manual workflow_dispatch trigger"
fi

if grep -E 'azure/login|AZURE_CREDENTIALS|client-secret|(^|[[:space:]])docker([[:space:]]|$)|services:|actions/checkout(@|[[:space:]]|$)' \
  "$WORKFLOW" >/dev/null; then
  fail "workflow contains a forbidden credential, checkout action, or Docker dependency"
fi

if grep -F '2>/dev/null' "$WORKFLOW" >/dev/null; then
  fail "workflow must not hide Container App inspection failures"
fi

if grep -F 'quickstart:latest' "$DOC" "$WORKFLOW" >/dev/null; then
  fail "Module 06 must use the immutable quickstart image digest"
fi

if grep -F '선택 모듈입니다.' "$DOC" >/dev/null; then
  fail "Module 06 must not describe itself as optional"
fi

printf 'PASS: Azure sample deployment workflow and doc\n'
