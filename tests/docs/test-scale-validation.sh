#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/05-parallel-scale-validation.md"

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

DOC_TEXT="$(<"$DOC")"

recovery_section="$(
  awk '
    BEGIN { in_section = 0 }
    /^## 0\. 세션 재연결 시 변수 복구 \(선택\)$/ { in_section = 1; next }
    /^## 1\./ { if (in_section) exit }
    in_section { print }
  ' "$DOC"
)"

assert_contains "$recovery_section" 'read -rp "Saved GITHUB_APP_ID:' 'module 05 GitHub App ID recovery prompt missing'
assert_contains "$recovery_section" 'read -rp "Saved GITHUB_APP_INSTALLATION_ID:' 'module 05 GitHub App installation ID recovery prompt missing'
assert_contains "$recovery_section" 'GITHUB_APP_ID=' 'module 05 GitHub App ID restore missing'
assert_contains "$recovery_section" 'GITHUB_APP_INSTALLATION_ID=' 'module 05 GitHub App installation ID restore missing'
assert_contains "$recovery_section" 'Module 01에서 저장한 `SUFFIX`를 그대로 사용하고, Module 02에서 이름 충돌 복구로 변경한 실제 ACR 또는 Storage 이름이 있으면 해당 값을 복원합니다.' 'module 05 must preserve Module 02 ownership of collision-recovered ACR or Storage names'

for text in \
  '## 0. 세션 재연결 시 변수 복구 (선택)' \
  'INFRA_SUBNET="snet-aca-infra"' \
  'SUBNET_ID=$(az network vnet subnet show' \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_ID=$(az storage account show' \
  'KEY_VAULT_ID=$(az keyvault show' \
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

assert_contains "$DOC_TEXT" '### Key Vault resolution failure memo' 'module 05 key vault resolution memo missing'
for text in \
  'Module 04 Key Vault reference synchronization/execution 성공이 acceptance gate입니다.' \
  'live rehearsal' \
  '저장소 테스트만으로 증명할 수 없습니다.' \
  '워크숍 delivery를 중단하고 환경별 platform path를 조사하세요.' \
  '`defaultAction=Deny`를 완화하거나 성공처럼 보이는 fallback을 추가하지 마세요.'; do
  assert_contains "$DOC_TEXT" "$text" 'module 05 Key Vault caveat missing'
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
