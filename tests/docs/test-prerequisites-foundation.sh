#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"
PORTAL_SCREENSHOT="$ROOT/docs/images/02-azure-portal-resource-group-resources.png"

fail() {
  echo "FAIL: $*" >&2
  exit 1
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
  '해당 private repository에 대한 HTTPS Git 인증이 이미 설정되어 있어야 합니다.' \
  'git clone https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop' \
  'cd ~/aca-github-runner-workshop' \
  'az extension add --name containerapp --upgrade --only-show-errors' \
  'az provider register -n Microsoft.App --wait' \
  'az provider register -n Microsoft.OperationalInsights --wait' \
  'az provider register -n Microsoft.Insights --wait'; do
  grep -F -- "$text" "$PREREQ" >/dev/null || { echo "FAIL: module 01 missing $text" >&2; exit 1; }
done

if grep -E 'gh auth|gh repo clone|WORKSHOP_REPO(_URL)?' "$PREREQ" >/dev/null; then
  fail "module 01 clone flow is not the requested simple git clone"
fi

for text in \
  'Private workshop source HTTPS 인증·권한 또는 SSO authorization 실패' \
  'https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private/tree/master' \
  '브라우저의 `/tree/master` URL은 접근 확인용이며 clone URL이 아닙니다.' \
  'clone에는 `https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git`을 사용합니다.' \
  '목적지 `~/aca-github-runner-workshop`이 이미 존재하거나 예상과 다른 clone destination' \
  '기존 디렉터리는 삭제하지 마세요.' \
  '정확한 목적지 `~/aca-github-runner-workshop`'; do
  grep -F -- "$text" "$PREREQ" >/dev/null ||
    fail "module 01 missing clone troubleshooting contract: $text"
done

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
  'az identity create' \
  'Contributor만으로는 Azure RBAC 역할을 할당할 수 없습니다.' \
  'Microsoft.Authorization/roleAssignments/write' \
  'Role Based Access Control Administrator' \
  '--role AcrPull' \
  '--assignee-principal-type ServicePrincipal' \
  'ACR="acracarunner$(openssl rand -hex 4)"' \
  '이 시점부터 `ACR`은 더 이상 `SUFFIX`에서 유도되지 않습니다.' \
  '이전에 적어 둔 `ACR` 값은 이 새 값으로 교체하세요.' \
  '다음 모듈 재접속에 대비해 `SUFFIX`와 실제 `ACR` 이름을 각각 별도 값으로 저장해 둔다.' \
  '이미 앞 단계의 RG, workspace, environment를 만들었다면 전체 `SUFFIX`를 바꾸지 마세요.' \
  '리소스 이름을 모두 새 suffix로 통일하려면 기존 실습 리소스를 정리하고 모듈 02의 1단계부터 다시 시작합니다.' \
  'SUFFIX=a1b2c3 RG=rg-acarunner-a1b2c3 ACR=acracarunnera1b2c3'; do
  grep -F -- "$text" "$FOUNDATION" >/dev/null || { echo "FAIL: module 02 missing $text" >&2; exit 1; }
done

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
