#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"

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

assert_contains_multiline() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message"
}

[[ -f "$PREREQ" ]] || fail "module 01 missing"
[[ -f "$FOUNDATION" ]] || fail "module 02 missing"

PREREQ_TEXT="$(<"$PREREQ")"
FOUNDATION_TEXT="$(<"$FOUNDATION")"
ALL_TEXT="$PREREQ_TEXT
$FOUNDATION_TEXT"

for text in \
  'Microsoft.Storage' \
  'PE_SUBNET="snet-private-endpoints"' \
  'PE_SUBNET_ID=$(az network vnet subnet show' \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_PE="pe-blob-$SUFFIX"' \
  'STORAGE_DNS_ZONE="privatelink.blob.core.windows.net"' \
  'STORAGE_DNS_LINK="link-blob-$SUFFIX"' \
  '--address-prefixes 10.20.1.0/24' \
  '--disable-private-endpoint-network-policies true' \
  '--infrastructure-subnet-resource-id "$SUBNET_ID"' \
  'internal:properties.vnetConfiguration.internal' \
  'az storage account create' \
  '--sku Standard_LRS' \
  '--kind StorageV2' \
  '--min-tls-version TLS1_2' \
  '--allow-blob-public-access false' \
  '--allow-shared-key-access false' \
  'defaultAction' \
  'Deny' \
  'az storage container-rm create' \
  '--public-access off' \
  'az network private-endpoint create' \
  '--group-id blob' \
  'az network private-dns zone create' \
  'privatelink.blob.core.windows.net' \
  'az network private-endpoint dns-zone-group create' \
  'networkInterfaces[0].id' \
  'Storage Blob Data Contributor' \
  '--scope "$STORAGE_ID"'; do
  assert_contains "$ALL_TEXT" "$text" 'missing foundation marker'
done

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment create \\\n  --assignee-object-id "$UAMI_PID" \\\n  --assignee-principal-type ServicePrincipal \\\n  --role "Storage Blob Data Contributor" \\\n  --scope "$STORAGE_ID" \\\n  --output none' \
  'module 02 must assign Storage Blob Data Contributor at Storage scope'

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment list \\\n  --assignee "$UAMI_PID" \\\n  --all \\\n  --query "[?scope==\'$ACR_ID\' || scope==\'$STORAGE_ID\'].{role:roleDefinitionName,principalType:principalType,scope:scope}" \\\n  --output table' \
  'module 02 must verify only ACR_ID and STORAGE_ID scopes'

assert_contains \
  "$FOUNDATION_TEXT" \
  '이 워크숍을 처음 실행하는 경우에는 아래 명령으로 새 External custom VNet Environment를 만듭니다.' \
  'missing first-run instruction'

assert_contains \
  "$FOUNDATION_TEXT" \
  '이전 버전의 워크숍에서 만든 기본 네트워크 또는 internal environment가 있는 경우에만 해당합니다.' \
  'missing legacy migration condition'

first_run_line="$(grep -nF '이 워크숍을 처음 실행하는 경우에는 아래 명령으로 새 External custom VNet Environment를 만듭니다.' "$FOUNDATION" | head -n1 | cut -d: -f1)"
legacy_line="$(grep -nF '이전 버전의 워크숍에서 만든 기본 네트워크 또는 internal environment가 있는 경우에만 해당합니다.' "$FOUNDATION" | head -n1 | cut -d: -f1)"

[[ -n "$first_run_line" && -n "$legacy_line" ]] || fail "missing section 4 ordering markers"
[[ "$first_run_line" -lt "$legacy_line" ]] || fail "first-run instruction must appear before legacy migration condition"

if grep -F '이전 버전의 워크숍에서 만든 기본 네트워크 또는 internal environment가 있는 경우에만 해당합니다. 해당 Environment는 현재 External custom VNet foundation으로 변환할 수 없으므로, 이 워크숍을 처음 실행할 때는 아래 명령으로 새 Environment를 만들고 이전 버전에서 이어오는 경우에는 새 workshop suffix로 다시 만듭니다.' "$FOUNDATION" >/dev/null; then
  fail "legacy-only combined paragraph must be split and reordered"
fi

for obsolete in \
  '--internal-only ''true' \
  'az storage account network-rule add' \
  'ENV_DEFAULT_''DOMAIN' \
  'ENV_STATIC_''IP' \
  'az network private-dns record-set a add-record' \
  '--record-set-name "*"' \
  'Container Apps Contributor' \
  'RG scope role verification' \
  'sample app capacity wording' \
  '다음 Module 03~06 재접속과 복구에 대비해' \
  '기본 네트워크로 만든 기존 ACA environment나 이전 internal environment는 현재 foundation으로 변환할 수 없습니다.'; do
  if grep -F -- "$obsolete" "$FOUNDATION" "$PREREQ" >/dev/null; then
    fail "obsolete internal-ACA contract still present: $obsolete"
  fi
done

printf 'PASS: prerequisites and foundation docs\n'
