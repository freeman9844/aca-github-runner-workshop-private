#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"
DOC="$ROOT/docs/06-azure-sample-deployment.md"
MODULE05_DOC="$ROOT/docs/05-parallel-scale-validation.md"
GITHUB_WORKFLOWS_SCREENSHOT="$ROOT/docs/images/06-github-workflows-console.png"
GITHUB_DEPLOYMENT_SCREENSHOT="$ROOT/docs/images/06-github-actions-deployment-success.png"
AZURE_PORTAL_SCREENSHOT="$ROOT/docs/images/06-azure-portal-resource-group-result.png"
APP_RESULT_SCREENSHOT="$ROOT/docs/images/06-container-app-hello-world-result.png"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$DOC" ]] || fail "Module 06 missing"
[[ -f "$WORKFLOW" ]] || fail "Azure sample deployment workflow missing"
[[ -f "$MODULE05_DOC" ]] || fail "Module 05 missing"
[[ -f "$GITHUB_WORKFLOWS_SCREENSHOT" ]] || fail "Module 06 GitHub workflows screenshot missing"
[[ ! -x "$GITHUB_WORKFLOWS_SCREENSHOT" ]] || fail "Module 06 GitHub workflows screenshot must not be executable"
[[ -f "$GITHUB_DEPLOYMENT_SCREENSHOT" ]] || fail "Module 06 deployment success screenshot missing"
[[ ! -x "$GITHUB_DEPLOYMENT_SCREENSHOT" ]] || fail "Module 06 deployment success screenshot must not be executable"
[[ -f "$AZURE_PORTAL_SCREENSHOT" ]] || fail "Module 06 Azure portal screenshot missing"
[[ ! -x "$AZURE_PORTAL_SCREENSHOT" ]] || fail "Module 06 Azure portal screenshot must not be executable"
[[ -f "$APP_RESULT_SCREENSHOT" ]] || fail "Module 06 app result screenshot missing"
[[ ! -x "$APP_RESULT_SCREENSHOT" ]] || fail "Module 06 app result screenshot must not be executable"

for heading in \
  '# 06. Azure 샘플 배포와 결과 확인' \
  '## 0. 세션 재연결 시 변수 복구 (선택)' \
  '## 1. 배포 권한과 실행 흐름 확인' \
  '## 2. 샘플 workflow를 GitHub에 생성' \
  '## 3. GitHub Actions에서 배포 실행' \
  '## 4. 배포 URL과 HTTP 결과 확인' \
  '## 5. Cloud Shell과 Azure Portal에서 확인' \
  '## 트러블슈팅'; do
  grep -F "$heading" "$DOC" >/dev/null ||
    fail "Module 06 missing heading $heading"
done

details_open_line="$(grep -nF -m1 '<details>' "$DOC" | cut -d: -f1)"
summary_line="$(grep -nF -m1 '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$DOC" | cut -d: -f1)"
details_close_line="$(grep -nF -m1 '</details>' "$DOC" | cut -d: -f1)"
legend_line="$(grep -nF -m1 '## 태그 범례' "$DOC" | cut -d: -f1)"
[[ "$(grep -Fc '<details>' "$DOC")" -eq 1 ]] ||
  fail "Module 06 must contain exactly one details block"
[[ "$(grep -Fc '</details>' "$DOC")" -eq 1 ]] ||
  fail "Module 06 must close exactly one details block"
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
  '--assignee-object-id "$UAMI_PID"' \
  '--assignee-principal-type ServicePrincipal' \
  '--role "Container Apps Contributor"' \
  '--scope "$RG_ID"' \
  '--name "$UAMI"' \
  '--query clientId' \
  'az login --identity --client-id' \
  'mcr.microsoft.com/k8se/quickstart:latest' \
  'Actions → ACA Runner Azure Sample Deploy → Run workflow' \
  'APP_URL=https://' \
  'az containerapp show' \
  'https://$FQDN' \
  'Container App' \
  'Azure Portal' \
  'az: command not found' \
  'az extension add --name containerapp --upgrade --only-show-errors' \
  'AuthorizationFailed' \
  'No existing Container App named' \
  'behavior of this command has been altered' \
  'does not exist. Specify a valid environment' \
  '`AcrPull`만 있고' \
  'HTTP verification failed after' \
  'stale runner workflow'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    fail "Module 06 missing $text"
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

step2_expected_line="$(grep -nF -m1 'reviewed sample과 같은 single-job workflow가 저장됩니다.' "$DOC" | cut -d: -f1)"
step3_heading_line="$(grep -nF -m1 '## 3. GitHub Actions에서 배포 실행' "$DOC" | cut -d: -f1)"
workflows_screenshot_line="$(grep -nF -m1 '![GitHub workflows 폴더에 배포 및 스케일 테스트 workflow가 준비된 화면](images/06-github-workflows-console.png)' "$DOC" | cut -d: -f1)"
[[ -n "$step2_expected_line" && -n "$workflows_screenshot_line" && -n "$step3_heading_line" ]] ||
  fail "Module 06 missing Step 2 workflows screenshot placement markers"
(( step2_expected_line < workflows_screenshot_line && workflows_screenshot_line < step3_heading_line )) ||
  fail "Module 06 workflows screenshot must follow Step 2 expected output"

step3_expected_line="$(grep -nF -m1 '`Show deployed Azure resource` step에는 새 `Container App` 이름, image, FQDN이 출력됩니다.' "$DOC" | cut -d: -f1)"
deployment_screenshot_line="$(grep -nF -m1 '![GitHub Actions에서 Azure 샘플 Container App 배포가 성공한 화면](images/06-github-actions-deployment-success.png)' "$DOC" | cut -d: -f1)"
step4_heading_line="$(grep -nF -m1 '## 4. 배포 URL과 HTTP 결과 확인' "$DOC" | cut -d: -f1)"
step3_warning_line="$(awk -v start="$step3_heading_line" -v end="$step4_heading_line" \
  'NR > start && NR < end && $0 == "⚠️ **주의**" { print NR; exit }' "$DOC")"
[[ -n "$step3_expected_line" && -n "$deployment_screenshot_line" && -n "$step3_warning_line" ]] ||
  fail "Module 06 missing Step 3 deployment screenshot placement markers"
(( step3_expected_line < deployment_screenshot_line && deployment_screenshot_line < step3_warning_line )) ||
  fail "Module 06 deployment screenshot must follow Step 3 expected output"

step5_expected_line="$(grep -nF -m1 'GitHub Actions, 브라우저, Cloud Shell, Portal 네 곳에서 같은 앱 이름과 URL을 가리키면 검증 완료입니다.' "$DOC" | cut -d: -f1)"
portal_screenshot_line="$(grep -nF -m1 '![Azure Portal에서 워크숍 Resource Group과 배포된 Container App을 확인한 화면](images/06-azure-portal-resource-group-result.png)' "$DOC" | cut -d: -f1)"
app_result_screenshot_line="$(grep -nF -m1 '![브라우저에서 Azure Container Apps Hello World 결과를 확인한 화면](images/06-container-app-hello-world-result.png)' "$DOC" | cut -d: -f1)"
troubleshooting_line="$(grep -nF -m1 '## 트러블슈팅' "$DOC" | cut -d: -f1)"
[[ -n "$step5_expected_line" && -n "$portal_screenshot_line" && -n "$app_result_screenshot_line" && -n "$troubleshooting_line" ]] ||
  fail "Module 06 missing Step 5 result screenshot placement markers"
(( step5_expected_line < portal_screenshot_line && portal_screenshot_line < app_result_screenshot_line && app_result_screenshot_line < troubleshooting_line )) ||
  fail "Module 06 Step 5 screenshots must show the portal before the browser result"

grep -Fx '[다음: Azure 샘플 배포와 결과 확인 →](06-azure-sample-deployment.md)' "$MODULE05_DOC" >/dev/null ||
  fail "Module 05 missing Module 06 navigation link"
grep -Fx 'Module 06은 선택이며, 90분 핵심 경로가 필요하면 [Module 07 정리 문서](07-security-limitations-cleanup.md)로 바로 이동해도 됩니다.' "$MODULE05_DOC" >/dev/null ||
  fail "Module 05 missing Module 07 cleanup note"
grep -Fx '[← 이전: 병렬 실행과 스케일 검증](05-parallel-scale-validation.md) | [다음: 보안·제약·정리 →](07-security-limitations-cleanup.md)' "$DOC" >/dev/null ||
  fail "Module 06 missing Module 07 navigation link"

for text in \
  'name: ACA Runner Azure Sample Deploy' \
  'on:' \
  'workflow_dispatch:' \
  'runs-on: [aca-runner]' \
  'timeout-minutes: 15' \
  'set -euo pipefail' \
  'az login --identity --client-id "$AZURE_CLIENT_ID"' \
  'az account set --subscription "$AZURE_SUBSCRIPTION_ID"' \
  'az containerapp create' \
  'az containerapp delete' \
  'for delete_attempt in $(seq 1 24); do' \
  'Waiting for Container App deletion (attempt %s/24).' \
  'Confirmed existing Container App deletion after %s checks.' \
  'ERROR: Timed out waiting for Container App deletion after 24 checks.' \
  '--image mcr.microsoft.com/k8se/quickstart:latest' \
  '--environment "$AZURE_CONTAINERAPPS_ENVIRONMENT"' \
  '--resource-group "$AZURE_RESOURCE_GROUP"' \
  '--name "$AZURE_SAMPLE_APP"' \
  '--ingress external' \
  '--target-port 80' \
  '--min-replicas 0' \
  '--max-replicas 1' \
  'APP_URL="https://$FQDN"' \
  '>> "$GITHUB_ENV"' \
  'curl --fail --silent --show-error "$APP_URL"' \
  'HTTP verification failed after'; do
  grep -F -- "$text" "$WORKFLOW" >/dev/null ||
    fail "workflow missing $text"
done

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

printf 'PASS: Azure sample deployment workflow and doc\n'
