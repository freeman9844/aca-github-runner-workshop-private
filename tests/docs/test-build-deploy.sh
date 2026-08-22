#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"

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

extract_objectives() {
  local doc="$1"
  awk '
    /^## 목표$/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "$doc"
}

[[ -f "$IMAGE_DOC" ]] || fail "module 03 missing"
[[ -f "$JOB_DOC" ]] || fail "module 04 missing"

IMAGE_TEXT="$(<"$IMAGE_DOC")"
JOB_TEXT="$(<"$JOB_DOC")"
ALL_TEXT="$IMAGE_TEXT
$JOB_TEXT"
IMAGE_OBJECTIVES="$(extract_objectives "$IMAGE_DOC")"
JOB_OBJECTIVES="$(extract_objectives "$JOB_DOC")"

[[ -n "$IMAGE_OBJECTIVES" ]] || fail "module 03 missing objective section"
[[ -n "$JOB_OBJECTIVES" ]] || fail "module 04 missing objective section"

for text in \
  'INFRA_SUBNET="snet-aca-infra"' \
  'SUBNET_ID=$(az network vnet subnet show' \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_ID=$(az storage account show'; do
  assert_contains "$ALL_TEXT" "$text" 'module 03/04 service endpoint recovery marker missing'
done

for text in \
  '`runner/Dockerfile`과 `runner/entrypoint.sh`를 검토하고 정적 검사를 실행한다.' \
  'ACR Tasks의 `az acr build`로 runner image를 빌드하고 ACR에 게시한다.'; do
  assert_contains "$IMAGE_OBJECTIVES" "$text" 'missing module 03 objective marker'
done

for text in \
  '`github-actions-runner` container를 사용하는 ACA Event Job을 만든다.' \
  'GitHub repository, GitHub App 식별자, Key Vault secret reference를 KEDA `github-runner` scaler와 runner env에 연결한다.'; do
  assert_contains "$JOB_OBJECTIVES" "$text" 'missing module 04 objective marker'
done

for text in \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'Jobs do not support ingress' \
  'Microsoft.Storage' \
  'Microsoft.KeyVault'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 service endpoint marker missing'
done

assert_contains "$IMAGE_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing module 03 optional recovery heading'
assert_contains "$JOB_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing module 04 optional recovery heading'
assert_contains "$IMAGE_TEXT" 'Module 01에서 저장한 `SUFFIX`와 실제 `KEY_VAULT`, Module 02에서 저장한 실제 `ACR` 이름을 사용해 같은 리소스를 복구합니다.' 'module 03 must preserve Module 01 Key Vault ownership and Module 02 ACR ownership'
assert_contains "$IMAGE_TEXT" '`KEY_VAULT`도 Module 01에서 이름 충돌 복구가 있었다면 저장해 둔 실제 값을 사용하세요.' 'module 03 must keep actual Key Vault collision recovery with Module 01'
assert_contains "$JOB_TEXT" 'Module 01에서 만든 Key Vault와 Module 02에서 완성한 service endpoint foundation, `GITHUB_APP_KEY_SECRET`, `KEY_VAULT_SECRET_URI`, `UAMI_RID`를 그대로 사용합니다.' 'module 04 must describe split Key Vault ownership'
assert_contains "$JOB_TEXT" 'Module 02의 `Microsoft.KeyVault` service endpoint, Key Vault ACA subnet rule, `defaultAction=Deny`, `bypass=None`, `Key Vault Secrets User`' 'module 04 troubleshooting must preserve service endpoint ownership order'

for obsolete in \
  '저장해 둔 `SUFFIX`와 실제 `ACR` 이름으로 모듈 02의 Azure 변수들을 복구한다.'; do
  if grep -F -- "$obsolete" <<<"$IMAGE_OBJECTIVES" >/dev/null; then
    fail "module 03 objective section still contains obsolete wording: $obsolete"
  fi
done

for obsolete in \
  '저장해 둔 `SUFFIX`와 실제 `ACR` 이름으로 Azure 변수들을 복구한다.' \
  '세션이 재시작되었더라도 GitHub owner/repo/Fine-grained PAT를 안전하게 다시 입력한다.' \
  'GitHub repository와 Fine-grained PAT를 KEDA `github-runner` scaler에 연결한다.'; do
  if grep -F -- "$obsolete" <<<"$JOB_OBJECTIVES" >/dev/null; then
    fail "module 04 objective section still contains obsolete wording: $obsolete"
  fi
done

for obsolete in \
  'AZURE_SAMPLE_''APP' \
  'internal ''Environment' \
  'same ''Environment' \
  'internal ''ingress'; do
  if grep -F -- "$obsolete" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "obsolete sample-app architecture still present: $obsolete"
  fi
done

assert_contains "$IMAGE_TEXT" '`bash tests/test-artifacts.sh`는 `PASS: workflow artifacts contract`를 출력합니다.' 'missing module 03 expected output'

for text in \
  'KEY_VAULT_SECRET_URI="https://$KEY_VAULT.vault.azure.net/secrets/$GITHUB_APP_KEY_SECRET"' \
  'applicationID=$GITHUB_APP_ID' \
  'installationID=$GITHUB_APP_INSTALLATION_ID' \
  'appKey=github-app-private-key' \
  'github-app-private-key=keyvaultref:$KEY_VAULT_SECRET_URI,identityref:$UAMI_RID' \
  'GITHUB_APP_ID=$GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key' \
  'triggerParameter: appKey' \
  'secretRef: github-app-private-key'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 GitHub App contract missing'
done

for obsolete in \
  'personalAccessToken' \
  'personal-access-token' \
  'GITHUB_PAT'; do
  if grep -F -- "$obsolete" "$JOB_DOC" >/dev/null; then
    fail "module 04 still contains obsolete PAT contract: $obsolete"
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
  if grep -F -- "$forbidden" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "module 03/04 still contains obsolete Private Link state: $forbidden"
  fi
done

printf 'PASS: build and deploy docs\n'
