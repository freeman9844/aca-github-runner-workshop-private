#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"
PORTAL_SCREENSHOT="$ROOT/docs/images/02-azure-portal-resource-group-resources.png"
PAT_SETTINGS_SCREENSHOT="$ROOT/docs/images/01-github-fine-grained-pat-settings.png"
CLOUD_SHELL_SCREENSHOTS=(
  "$ROOT/docs/images/01-cloudshell-step1-welcome.png"
  "$ROOT/docs/images/01-cloudshell-step2-getting-started.png"
  "$ROOT/docs/images/01-cloudshell-step3-mount-storage.png"
  "$ROOT/docs/images/01-cloudshell-step4-ready.png"
)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains_multiline() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" == *"$needle"* ]] || fail "$message"
}

operational_github_app_pattern='GITHUB_APP_|Developer settings → GitHub Apps|Generate a private key|App ID|installation ID|private key PEM|github-app-private-key'
stdout_pat_print_pattern='^[[:space:]]*(printf|echo|cat)\b.*\$GITHUB_PAT([^[:alnum:]_]|$)'
safe_printf_v_pattern='^[0-9]+:[[:space:]]*printf[[:space:]]+-v\b'

grep_forbidden_pat_stdout_prints() {
  grep -nE "$stdout_pat_print_pattern" "$@" | grep -Ev "$safe_printf_v_pattern"
}

[[ -f "$PREREQ" ]] || { echo "FAIL: module 01 missing" >&2; exit 1; }
[[ -f "$FOUNDATION" ]] || { echo "FAIL: module 02 missing" >&2; exit 1; }
[[ -f "$PORTAL_SCREENSHOT" ]] ||
  fail "module 02 Azure portal screenshot missing"
[[ -f "$PAT_SETTINGS_SCREENSHOT" ]] ||
  fail "module 01 GitHub PAT settings screenshot missing"
PREREQ_TEXT="$(<"$PREREQ")"
FOUNDATION_TEXT="$(<"$FOUNDATION")"
for screenshot in "${CLOUD_SHELL_SCREENSHOTS[@]}"; do
  [[ -f "$screenshot" ]] ||
    fail "module 01 Cloud Shell screenshot missing: $(basename "$screenshot")"
done

if grep -E "$operational_github_app_pattern" <(
  printf '%s\n' 'Enterprise Managed User may be unable to install a GitHub App.'
) >/dev/null; then
  fail "EMU explanatory GitHub App prose should remain allowed"
fi

grep -E "$operational_github_app_pattern" <(
  printf '%s\n' 'Settings → Developer settings → GitHub Apps → New GitHub App'
) >/dev/null || fail "operational GitHub App setup markers must stay rejected"

if grep_forbidden_pat_stdout_prints <(
  printf '%s\n' 'printf -v PAT_AUTH_HEADER '\''%s: %s %s'\'' '\''Authorization'\'' '\''Bearer'\'' "$GITHUB_PAT"'
) >/dev/null; then
  fail "printf -v PAT assignments should remain allowed"
fi

grep_forbidden_pat_stdout_prints <(
  printf '%s\n' 'printf '\''%s\n'\'' "$GITHUB_PAT"'
) >/dev/null || fail "stdout printf PAT output must stay rejected"

for text in \
  'Visibility | **Private**' \
  'Fine-grained personal access token' \
  'Personal access tokens' \
  'Fine-grained tokens' \
  'Generate new token' \
  'Resource owner' \
  'Expiration | **30 days**' \
  'Only select repositories' \
  'Actions | Read-only' \
  'Administration | Read and write' \
  'Metadata | Read-only' \
  'aca-runner-lab' \
  'Enterprise Managed User' \
  'organization approval' \
  'read -rsp "Fine-grained PAT: " GITHUB_PAT' \
  'printf '\''\n'\''' \
  'GITHUB_OWNER' \
  'GITHUB_REPO' \
  'GITHUB_PAT' \
  'X-GitHub-Api-Version: 2026-03-10' \
  '/actions/runs?per_page=1' \
  '/actions/runners/registration-token' \
  'Repository access: OK' \
  'Actions read: OK' \
  'Runner administration: OK' \
  'Public workshop source' \
  '이름에 `private`가 포함되어 있지만 저장소 visibility는 **Public**입니다.' \
  'GitHub CLI login 없이 clone할 수 있습니다.' \
  '## Cloud Shell 최초 준비' \
  'Mount storage account' \
  'No storage account required' \
  'We will create a storage account for you' \
  'Requesting a Cloud Shell.Succeeded.' \
  'Settings(⚙️) → Reset User Settings' \
  '![Cloud Shell Welcome 화면에서 Bash 선택](images/01-cloudshell-step1-welcome.png)' \
  '![Getting started 화면에서 영구 스토리지와 구독 선택](images/01-cloudshell-step2-getting-started.png)' \
  '![Cloud Shell 스토리지 계정 자동 생성 선택](images/01-cloudshell-step3-mount-storage.png)' \
  '![Cloud Shell Bash 프롬프트 준비 완료](images/01-cloudshell-step4-ready.png)' \
  '![GitHub Fine-grained PAT 저장소와 권한 설정 예시](images/01-github-fine-grained-pat-settings.png)' \
  'Public workshop source clone과 lab Fine-grained PAT는 서로 다른 흐름입니다.' \
  'git clone https://github.com/freeman9844/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop' \
  'cd ~/aca-github-runner-workshop' \
  'until [[ -n "$GITHUB_PAT" ]]' \
  'ERROR: Fine-grained PAT cannot be empty. Try again.' \
  'az extension add --name containerapp --upgrade --version 0.3.55 --only-show-errors' \
  'az provider register -n Microsoft.App --wait' \
  'az provider register -n Microsoft.ContainerRegistry --wait' \
  'az provider register -n Microsoft.OperationalInsights --wait' \
  'az provider register -n Microsoft.Insights --wait' \
  '다섯 명령 모두 오류 없이 종료됩니다.'; do
  grep -F -- "$text" "$PREREQ" >/dev/null || { echo "FAIL: module 01 missing $text" >&2; exit 1; }
done

assert_contains_multiline \
  "$PREREQ_TEXT" \
  $'GitHub owner: freeman9844\nPrivate repository name: aca-runner-lab\nFine-grained PAT:\nGITHUB_OWNER=freeman9844\nGITHUB_REPO=aca-runner-lab\nGITHUB_PAT=SET' \
  'module 01 step 6 must show the complete safe variable-loading output'

if grep -E 'gh repo clone|WORKSHOP_REPO(_URL)?' "$PREREQ" >/dev/null; then
  fail "module 01 clone flow is not the requested simple git clone"
fi

if grep -E '^[[:space:]]*export[[:space:]].*GITHUB_PAT' "$PREREQ" >/dev/null; then
  fail "module 01 must keep GITHUB_PAT shell-local"
fi

for text in \
  'Public workshop source clone 네트워크 또는 URL 오류' \
  'https://github.com/freeman9844/aca-github-runner-workshop-private/tree/master' \
  '브라우저의 `/tree/master` URL은 접근 확인용이며 clone URL이 아닙니다.' \
  'clone에는 `https://github.com/freeman9844/aca-github-runner-workshop-private.git`을 사용합니다.' \
  '목적지 `~/aca-github-runner-workshop`이 이미 존재하거나 예상과 다른 clone destination' \
  '기존 디렉터리는 삭제하지 마세요.' \
  '정확한 목적지 `~/aca-github-runner-workshop`'; do
  grep -F -- "$text" "$PREREQ" >/dev/null ||
    fail "module 01 missing clone troubleshooting contract: $text"
done

if grep -E 'Private workshop source|private source 접근|gh auth login|gh auth setup-git|gh auth status|SSO authorization' \
  "$PREREQ" >/dev/null; then
  fail "module 01 still requires authentication for the public workshop source"
fi

if grep -E 'rm[[:space:]]+-rf[[:space:]]+("?\$HOME/aca-github-runner-workshop"?|"?~/aca-github-runner-workshop"?)' \
  "$PREREQ" >/dev/null; then
  fail "module 01 must not destructively delete the workshop clone destination"
fi

if grep -Fx '## 8. 검증' "$PREREQ" >/dev/null; then
  fail "module 01 still has a redundant final validation section"
fi

if grep -E "$operational_github_app_pattern" "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 still documents GitHub App authentication' >&2
  exit 1
fi

if grep_forbidden_pat_stdout_prints "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 prints the Fine-grained PAT' >&2
  exit 1
fi

if grep -F '******' "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 contains six-star placeholder auth text' >&2
  exit 1
fi

for text in \
  '## 참고: Azure 관리 포털에서 생성된 리소스 확인' \
  '선택 참고' \
  'Resource groups' \
  '`$RG`' \
  'Overview' \
  'Resources' \
  'Azure Container Registry' \
  'Container Apps Environment' \
  'Managed Identity' \
  'Log Analytics workspace' \
  '![Azure Portal 리소스 그룹 Overview에서 Module 02 생성 리소스를 확인하는 화면](images/02-azure-portal-resource-group-resources.png)' \
  'LOC=koreacentral' \
  'SUFFIX="$(openssl rand -hex 3)"' \
  'ACR="acracarunner$SUFFIX"' \
  'az containerapp env create' \
  '--logs-destination azure-monitor' \
  'az monitor diagnostic-settings create' \
  '"categoryGroup":"allLogs"' \
  'az acr create' \
  '--admin-enabled false' \
  'az acr config authentication-as-arm update' \
  '`MissingSubscriptionRegistration`' \
  '`Microsoft.ContainerRegistry` provider가 등록되지 않음' \
  '뒤의 ACR `resource not found` 오류는 첫 실패에 따른 연쇄 오류' \
  'provider 등록이 완료되면 4단계 전체를 처음부터 다시 실행합니다.' \
  'az identity create' \
  'SUBSCRIPTION_ID=$(az account show' \
  'RG_ID=$(az group show' \
  'printf '\''다음 값을 저장하세요: SUFFIX=%s ACR=%s SUBSCRIPTION_ID=%s\n'\''' \
  'Module 06을 Cloud Shell 재접속 후 이어가려면 위에서 출력한 `SUBSCRIPTION_ID`를 `SUFFIX`, 실제 `ACR` 이름과 함께 저장해 둡니다.' \
  '다음 값을 저장하세요: SUFFIX=a1b2c3 ACR=acracarunnera1b2c3 SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000' \
  'UAMI_CLIENT_ID=$(az identity show' \
  '--query clientId' \
  'Contributor만으로는 Azure RBAC 역할을 할당할 수 없습니다.' \
  'Microsoft.Authorization/roleAssignments/write' \
  'Role Based Access Control Administrator' \
  '`Container Apps Contributor`는 Container App을 관리하지만 Container Apps Job 권한은 포함하지 않습니다.' \
  'ACR="acracarunner$(openssl rand -hex 4)"' \
  '이 시점부터 `ACR`은 더 이상 `SUFFIX`에서 유도되지 않습니다.' \
  '이전에 적어 둔 `ACR` 값은 이 새 값으로 교체하세요.' \
  '다음 모듈 재접속과 Module 06 복구에 대비해 `SUFFIX`, 실제 `ACR` 이름, 원래 `SUBSCRIPTION_ID`를 각각 별도 값으로 저장해 둔다.' \
  '이미 앞 단계의 RG, workspace, environment를 만들었다면 전체 `SUFFIX`를 바꾸지 마세요.' \
  '리소스 이름을 모두 새 suffix로 통일하려면 기존 실습 리소스를 정리하고 모듈 02의 1단계부터 다시 시작합니다.' \
  'SUFFIX=a1b2c3 RG=rg-acarunner-a1b2c3 ACR=acracarunnera1b2c3'; do
  grep -F -- "$text" "$FOUNDATION" >/dev/null || { echo "FAIL: module 02 missing $text" >&2; exit 1; }
done

[[ "$(grep -Fc 'Container Apps Job 권한은 포함하지 않습니다.' "$FOUNDATION")" -eq 1 ]] ||
  fail "module 02 must explain the Container Apps Job boundary exactly once"

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment create \\\n  --assignee-object-id "$UAMI_PID" \\\n  --assignee-principal-type ServicePrincipal \\\n  --role AcrPull \\\n  --scope "$ACR_ID" \\\n  --output none' \
  'module 02 must keep AcrPull assigned at the ACR scope'

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment create \\\n  --assignee-object-id "$UAMI_PID" \\\n  --assignee-principal-type ServicePrincipal \\\n  --role "Container Apps Contributor" \\\n  --scope "$RG_ID" \\\n  --output none' \
  'module 02 must keep Container Apps Contributor assigned at the resource-group scope'

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment list \\\n  --assignee "$UAMI_PID" \\\n  --query "[?scope==\'$ACR_ID\' || scope==\'$RG_ID\'].{role:roleDefinitionName,principalType:principalType,scope:scope}" \\\n  --output table' \
  'module 02 must verify both RBAC scopes while showing role names'

grep -Fx -- '- `AcrPull`, `Container Apps Contributor`, `ServicePrincipal`이 보이는 표가 출력됩니다.' \
  "$FOUNDATION" >/dev/null ||
  fail "module 02 missing RBAC verification output for both roles"

portal_reference_line="$(
  grep -nF -m1 '## 참고: Azure 관리 포털에서 생성된 리소스 확인' \
    "$FOUNDATION" | cut -d: -f1
)"
troubleshooting_line="$(
  grep -nF -m1 '## 트러블슈팅' "$FOUNDATION" | cut -d: -f1
)"
(( portal_reference_line < troubleshooting_line )) ||
  fail "module 02 portal reference must appear before troubleshooting"

if grep -Fx '## 6. 검증' "$FOUNDATION" >/dev/null; then
  fail "module 02 still has a standalone validation section"
fi

for text in \
  'az acr show \' \
  'adminUserEnabled:adminUserEnabled' \
  'az acr config authentication-as-arm show \' \
  'az role assignment list \' \
  'roleDefinitionName'; do
  grep -F -- "$text" "$FOUNDATION" >/dev/null ||
    fail "module 02 lost safety check: $text"
done

if grep -F 'RANDOM % 100000' "$FOUNDATION" >/dev/null; then
  echo 'FAIL: module 02 still uses low-entropy RANDOM suffixes' >&2
  exit 1
fi

if grep -F 'SUFFIX 블록을 다시 실행해 새 값을 만든 뒤 `az acr create`부터 다시 수행합니다.' "$FOUNDATION" >/dev/null; then
  echo 'FAIL: module 02 still tells readers to rerun the entire suffix block for ACR collisions' >&2
  exit 1
fi

printf 'PASS: prerequisites and foundation docs\n'
