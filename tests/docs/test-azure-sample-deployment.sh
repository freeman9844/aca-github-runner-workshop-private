#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"
DOC="$ROOT/docs/06-azure-sample-deployment.md"
MODULE05_DOC="$ROOT/docs/05-parallel-scale-validation.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$DOC" ]] || fail "Module 06 missing"
[[ -f "$WORKFLOW" ]] || fail "Azure sample deployment workflow missing"
[[ -f "$MODULE05_DOC" ]] || fail "Module 05 missing"

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

for text in \
  'samples/azure-sample-deploy-workflow.yml' \
  '.github/workflows/aca-runner-azure-deploy.yml' \
  'Container Apps Contributor' \
  'Container Apps Job 권한은 포함하지 않습니다.' \
  'private repository' \
  'trusted workflow authors' \
  '식별자' \
  'credentials' \
  'SUFFIX="<your-saved-suffix>"' \
  'RG="rg-acarunner-$SUFFIX"' \
  'ENV="env-acarunner-$SUFFIX"' \
  'UAMI="id-acarunner-$SUFFIX"' \
  'AZURE_SAMPLE_APP="hello-aca-$SUFFIX"' \
  'AZURE_CLIENT_ID=$(az identity show' \
  '--name "$UAMI"' \
  '--query clientId' \
  'AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)' \
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
  'HTTP verification failed after' \
  'stale runner workflow'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    fail "Module 06 missing $text"
done

grep -Fx '[다음: Azure 샘플 배포와 결과 확인 →](06-azure-sample-deployment.md)' "$MODULE05_DOC" >/dev/null ||
  fail "Module 05 missing Module 06 navigation link"
grep -Fx 'Module 06은 선택이며, 90분 핵심 경로가 필요하면 cleanup용 Module 07을 바로 사용해도 됩니다.' "$MODULE05_DOC" >/dev/null ||
  fail "Module 05 missing optional Module 06 note"

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
