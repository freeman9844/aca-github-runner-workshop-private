#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"
ORG_REPO_IMAGE="$ROOT/docs/images/01-github-organization-private-repository.png"

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
[[ -f "$ORG_REPO_IMAGE" ]] || fail "module 01 organization repository example image missing"

PREREQ_TEXT="$(<"$PREREQ")"
FOUNDATION_TEXT="$(<"$FOUNDATION")"
ALL_TEXT="$PREREQ_TEXT
$FOUNDATION_TEXT"

architecture_section="$(
  awk '
    /^## 아키텍처 참고$/ { in_section=1 }
    /^## 목표$/ { exit }
    in_section { print }
  ' "$FOUNDATION"
)"

for text in \
  '```mermaid' \
  'flowchart TB' \
  'Resource Group' \
  'Custom VNet' \
  'Delegated ACA subnet' \
  'External ACA Environment' \
  'Non-delegated Private Endpoint subnet' \
  'Blob Private Endpoint' \
  'Key Vault Private Endpoint' \
  'privatelink.blob.core.windows.net' \
  'privatelink.vaultcore.azure.net' \
  'Log Analytics' \
  'Basic ACR' \
  'User-Assigned Managed Identity' \
  'AcrPull' \
  'Storage Blob Data Contributor' \
  'Key Vault Secrets User' \
  'Module 04'; do
  assert_contains "$architecture_section" "$text" 'module 02 architecture diagram missing marker'
done

architecture_line="$(grep -nF '## 아키텍처 참고' "$FOUNDATION" | head -n1 | cut -d: -f1)"
goal_line="$(grep -nF '## 목표' "$FOUNDATION" | head -n1 | cut -d: -f1)"
[[ -n "$architecture_line" && -n "$goal_line" && "$architecture_line" -lt "$goal_line" ]] ||
  fail "module 02 architecture diagram must appear before goals"

for text in \
  'Microsoft.KeyVault' \
  'Organization owner' \
  'GitHub Apps' \
  'aca-runner-lab' \
  'Only select repositories' \
  'Metadata' \
  'Read-only' \
  'Actions' \
  'Administration' \
  'Read and write' \
  '프로필 사진 → **Your organizations** → 대상 organization의 **Settings** → **Developer settings** → **GitHub Apps** → **New GitHub App**' \
  '개인 계정의 **Settings → Applications → Authorized GitHub Apps** 화면에서는 organization-owned App을 만들 수 없습니다.' \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  '/settings/installations/' \
  'Install is prohibited' \
  '로컬 Azure CLI' \
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
  '--scope "$STORAGE_ID"' \
  'KEY_VAULT="kvacarunner$SUFFIX"' \
  'KEY_VAULT_PE="pe-kv-$SUFFIX"' \
  'KEY_VAULT_DNS_ZONE="privatelink.vaultcore.azure.net"' \
  'KEY_VAULT_DNS_LINK="link-kv-$SUFFIX"' \
  'GITHUB_APP_KEY_SECRET="github-app-private-key"' \
  'az keyvault create' \
  '--enable-rbac-authorization true' \
  '--retention-days 7' \
  '--enable-purge-protection false' \
  '--default-action Deny' \
  'Key Vault Secrets Officer' \
  'az keyvault secret set' \
  '--file "$GITHUB_APP_PRIVATE_KEY_FILE"' \
  '--group-id vault' \
  'privatelink.vaultcore.azure.net' \
  'az keyvault update' \
  '--public-network-access Disabled' \
  'Key Vault Secrets User' \
  '--scope "$KEY_VAULT_ID"'; do
  assert_contains "$ALL_TEXT" "$text" 'missing foundation marker'
done

assert_contains \
  "$PREREQ_TEXT" \
  '조직이 소유한 `aca-runner-lab` private repository와 해당 조직이 소유한 GitHub App' \
  'module 01 must require organization-owned repository and app'

assert_contains \
  "$PREREQ_TEXT" \
  'private key PEM 파일은 로컬 워크스테이션에만 보관하고 Cloud Shell에 업로드하거나 Git에 commit하지 않습니다.' \
  'module 01 must forbid PEM upload or commit'

for text in \
  '### 일반 GitHub 무료 계정 사용자의 경우' \
  '**Organization 소유 Private repository**와 **Organization 소유 GitHub App**' \
  '프로필 → **Your organizations** → **New organization**' \
  '무료 플랜을 선택합니다.' \
  '`my-aca-runner-lab`' \
  '본인을 Organization owner로 유지합니다.' \
  'App owner | 개인 계정이 아닌 GitHub Organization' \
  'Selected repository | `aca-runner-lab`'; do
  assert_contains "$PREREQ_TEXT" "$text" 'module 01 free-account organization guide missing'
done

step_five_line="$(grep -nF '## 5. 조직 GitHub App 만들기' "$PREREQ" | head -n1 | cut -d: -f1)"
free_account_line="$(grep -nF '### 일반 GitHub 무료 계정 사용자의 경우' "$PREREQ" | head -n1 | cut -d: -f1)"
step_five_explanation_line="$(
  awk '
    /^## 5\. 조직 GitHub App 만들기$/ { in_step=1; next }
    in_step && /^👁️ \*\*설명\*\*$/ { print NR; exit }
  ' "$PREREQ"
)"
[[ -n "$step_five_line" && -n "$free_account_line" && -n "$step_five_explanation_line" ]] ||
  fail "module 01 step 5 free-account guide ordering markers missing"
[[ "$step_five_line" -lt "$free_account_line" && "$free_account_line" -lt "$step_five_explanation_line" ]] ||
  fail "module 01 free-account guide must appear at the start of step 5"

step_three_section="$(
  awk '
    /^## 3\. / { in_section=1 }
    /^## 4\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
assert_contains \
  "$step_three_section" \
  '![freejava98 organization의 Private aca-runner-lab 저장소 예시](images/01-github-organization-private-repository.png)' \
  'module 01 step 3 must reference the organization repository example image'

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment create \\\n  --assignee-object-id "$UAMI_PID" \\\n  --assignee-principal-type ServicePrincipal \\\n  --role "Storage Blob Data Contributor" \\\n  --scope "$STORAGE_ID" \\\n  --output none' \
  'module 02 must assign Storage Blob Data Contributor at Storage scope'

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az role assignment list \\\n  --assignee "$UAMI_PID" \\\n  --all \\\n  --query "[?scope==\'$ACR_ID\' || scope==\'$STORAGE_ID\' || scope==\'$KEY_VAULT_ID\'].{role:roleDefinitionName,principalType:principalType,scope:scope}" \\\n  --output table' \
  'module 02 must verify ACR_ID, STORAGE_ID, and KEY_VAULT_ID scopes'

assert_contains_multiline \
  "$FOUNDATION_TEXT" \
  $'az network private-dns record-set a show \\\n  --resource-group "$RG" \\\n  --zone-name "$KEY_VAULT_DNS_ZONE" \\\n  --name "$KEY_VAULT" \\\n  --query "aRecords[].ipv4Address" \\\n  --output tsv' \
  'module 02 must validate the Key Vault private DNS A record before PEM deletion'

for forbidden in \
  '--value "$GITHUB_APP_PRIVATE_KEY"'; do
  if grep -F -- "$forbidden" "$FOUNDATION" >/dev/null; then
    fail "PEM value must not appear in module 02: $forbidden"
  fi
done

last_public_network_access="$(grep -oE -- '--public-network-access (Enabled|Disabled)' "$FOUNDATION" | tail -n1 || true)"
[[ "$last_public_network_access" == '--public-network-access Disabled' ]] || \
  fail "final --public-network-access occurrence must be Disabled"

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
  'Fine-grained personal access token' \
  'GITHUB_PAT' \
  'Personal access tokens' \
  '01-github-fine-grained-pat-settings.png' \
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
