#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"

[[ -f "$PREREQ" ]] || { echo "FAIL: module 01 missing" >&2; exit 1; }
[[ -f "$FOUNDATION" ]] || { echo "FAIL: module 02 missing" >&2; exit 1; }

for text in \
  'Visibility | **Private**' \
  'GitHub Apps' \
  'Webhook | **Inactive**' \
  'Actions | Read-only' \
  'Administration | Read and write' \
  'Metadata | Read-only' \
  'Where can this GitHub App be installed? | **Only on this account**' \
  'Only select repositories' \
  'aca-runner-lab' \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY_PATH' \
  'GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"' \
  'openssl dgst -sha256' \
  'printf -v APP_AUTH_HEADER '\''%s: %s %s'\'' '\''Authorization'\'' '\''Bearer'\'' "$APP_JWT"' \
  'printf -v INSTALLATION_AUTH_HEADER '\''%s: %s %s'\''' \
  '/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens' \
  '--header "$APP_AUTH_HEADER"' \
  '--header "$INSTALLATION_AUTH_HEADER"' \
  'X-GitHub-Api-Version: 2026-03-10' \
  'read -rp "Workshop repository URL: " WORKSHOP_REPO_URL' \
  'git clone "$WORKSHOP_REPO_URL" ~/aca-github-runner-workshop' \
  'az extension add --name containerapp --upgrade --only-show-errors' \
  'az provider register -n Microsoft.App --wait' \
  'az provider register -n Microsoft.OperationalInsights --wait' \
  'az provider register -n Microsoft.Insights --wait'; do
  grep -F -- "$text" "$PREREQ" >/dev/null || { echo "FAIL: module 01 missing $text" >&2; exit 1; }
done

if grep -E 'Fine-grained PAT|GITHUB_PAT|personal access token' "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 still documents PAT authentication' >&2
  exit 1
fi

if grep -nE '^[[:space:]]*(printf|echo|cat)\b.*\$GITHUB_APP_PRIVATE_KEY([^[:alnum:]_]|$)' "$PREREQ" | \
  grep -v '\${GITHUB_APP_PRIVATE_KEY:+SET}' >/dev/null; then
  echo 'FAIL: module 01 prints the raw GitHub App private key' >&2
  exit 1
fi

if grep -F '******' "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 contains six-star placeholder auth text' >&2
  exit 1
fi

for text in \
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

if grep -F 'RANDOM % 100000' "$FOUNDATION" >/dev/null; then
  echo 'FAIL: module 02 still uses low-entropy RANDOM suffixes' >&2
  exit 1
fi

if grep -F 'SUFFIX 블록을 다시 실행해 새 값을 만든 뒤 `az acr create`부터 다시 수행합니다.' "$FOUNDATION" >/dev/null; then
  echo 'FAIL: module 02 still tells readers to rerun the entire suffix block for ACR collisions' >&2
  exit 1
fi

printf 'PASS: prerequisites and foundation docs\n'
