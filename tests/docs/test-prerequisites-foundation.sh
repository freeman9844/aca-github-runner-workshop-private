#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"
ORG_REPO_IMAGE="$ROOT/docs/images/01-github-organization-private-repository.png"
APP_SETTINGS_IMAGE="$ROOT/docs/images/01-github-app-settings-example.png"
APP_INSTALL_TARGET_IMAGE="$ROOT/docs/images/01-github-app-install-target.png"
APP_SELECT_REPOSITORY_IMAGE="$ROOT/docs/images/01-github-app-select-repository.png"
KEY_VAULT_RESULT_IMAGE="$ROOT/docs/images/01-key-vault-secret-created.png"
GITHUB_APP_KEY_STORE="$ROOT/scripts/store-github-app-private-key.sh"
GITHUB_APP_VERIFIER="$ROOT/scripts/verify-github-app-installation.sh"

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
[[ -f "$APP_SETTINGS_IMAGE" ]] || fail "module 01 GitHub App settings example image missing"
[[ -f "$APP_INSTALL_TARGET_IMAGE" ]] || fail "module 01 GitHub App install target image missing"
[[ -f "$APP_SELECT_REPOSITORY_IMAGE" ]] || fail "module 01 GitHub App repository selection image missing"
[[ -f "$KEY_VAULT_RESULT_IMAGE" ]] || fail "module 01 Key Vault result image missing"
[[ ! -e "$ROOT/docs/images/01-key-vault-secrets-list.png" ]] ||
  fail "obsolete module 01 Key Vault secrets list image must be removed"
[[ ! -e "$ROOT/docs/images/01-key-vault-create-secret.png" ]] ||
  fail "obsolete module 01 Key Vault create secret image must be removed"
[[ -f "$GITHUB_APP_KEY_STORE" ]] || fail "module 01 GitHub App private key store script missing"
[[ -f "$GITHUB_APP_VERIFIER" ]] || fail "module 01 GitHub App verifier missing"

PREREQ_TEXT="$(<"$PREREQ")"
FOUNDATION_TEXT="$(<"$FOUNDATION")"
GITHUB_APP_KEY_STORE_TEXT="$(<"$GITHUB_APP_KEY_STORE")"
GITHUB_APP_VERIFIER_TEXT="$(<"$GITHUB_APP_VERIFIER")"
ALL_TEXT="$PREREQ_TEXT
$FOUNDATION_TEXT
$GITHUB_APP_KEY_STORE_TEXT
$GITHUB_APP_VERIFIER_TEXT"

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
  'Cloud Shell 검증 script' \
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
  'KEY_VAULT_PE="pe-kv-$SUFFIX"' \
  'KEY_VAULT_DNS_ZONE="privatelink.vaultcore.azure.net"' \
  'KEY_VAULT_DNS_LINK="link-kv-$SUFFIX"' \
  'GITHUB_APP_KEY_SECRET="github-app-private-key"' \
  'az keyvault create' \
  '--enable-rbac-authorization true' \
  '--retention-days 7' \
  '--default-action Deny' \
  'Key Vault Secrets Officer' \
  '### 7-L. Azure Portal Cloud Shell: GitHub App PEM file 업로드' \
  '**Objects** → **Secrets**' \
  '**Manage files** → **Upload**' \
  '--name "$GITHUB_APP_KEY_SECRET"' \
  'az keyvault secret set' \
  '--file "$UPLOADED_PEM_FILE"' \
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
  '7-L에서는 Azure Portal Cloud Shell에 PEM을 일시적으로 upload하지만, Key Vault 저장 직후 upload 파일을 자동 삭제합니다.' \
  'module 01 must limit PEM upload to temporary Key Vault ingestion'

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

step_five_section="$(
  awk '
    /^## 5\. / { in_section=1 }
    /^## 6\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
assert_contains \
  "$step_five_section" \
  '![freejava98 organization의 GitHub App 이름과 Homepage URL 설정 예시](images/01-github-app-settings-example.png)' \
  'module 01 step 5 must reference the GitHub App settings example image'
for text in \
  '### GitHub App 설치와 Installation ID 확인' \
  'Installation ID는 App을 생성한 시점에는 확인할 수 없으며' \
  '**Install App**' \
  '**Only select repositories**' \
  '`aca-runner-lab` 하나를 선택' \
  '/settings/installations/<installation-id>' \
  'https://github.com/organizations/freejava98/settings/installations/155640565' \
  '`155640565`가 Installation ID입니다.' \
  '![freejava98 organization에 GitHub App을 설치할 대상 선택 예시](images/01-github-app-install-target.png)' \
  '![Only select repositories에서 aca-runner-lab을 선택한 GitHub App 설치 예시](images/01-github-app-select-repository.png)'; do
  assert_contains "$step_five_section" "$text" 'module 01 step 5 App installation guidance missing'
done

step_six_section="$(
  awk '
    /^## 6\. / { in_section=1 }
    /^## 7\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
assert_contains \
  "$step_six_section" \
  '# 입력한 식별자를 한 번에 출력해 GitHub 화면의 값과 비교합니다.' \
  'module 01 step 6 must explain identifier output'
assert_contains \
  "$step_six_section" \
  'export GITHUB_OWNER GITHUB_REPO GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID' \
  'module 01 step 6 must export identifiers for the verifier script'

step_seven_section="$(
  awk '
    /^## 7\. / { in_section=1 }
    /^## 8\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
step_seven_cloud_shell="$(
  awk '
    /^### 7-C\. / { in_section=1 }
    /^### 7-L\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
step_seven_portal="$(
  awk '
    /^### 7-L\. / { in_section=1 }
    /^## 8\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
assert_contains \
  "$step_seven_cloud_shell" \
  'set -euo pipefail' \
  'module 01 step 7-C must stop after an Azure command failure'
assert_contains \
  "$step_seven_cloud_shell" \
  'Azure API가 false 명시를 거부하므로 --enable-purge-protection 옵션은 생략합니다.' \
  'module 01 step 7-C must explain why purge protection false is omitted'
assert_contains \
  "$step_seven_cloud_shell" \
  '--default-action Allow' \
  'module 01 step 7-C must temporarily allow public network access for workshop testing'
assert_contains \
  "$step_seven_cloud_shell" \
  'export KEY_VAULT GITHUB_APP_KEY_SECRET' \
  'module 01 step 7-C must export Key Vault identifiers for the verifier script'
if [[ "$step_seven_cloud_shell" == *'--enable-purge-protection false'* ]]; then
  fail 'module 01 step 7-C must not send irreversible purge protection as false'
fi
for forbidden in \
  'KEY_VAULT_BOOTSTRAP_CIDR' \
  'az keyvault network-rule add'; do
  if [[ "$step_seven_cloud_shell" == *"$forbidden"* ]]; then
    fail "module 01 step 7-C must not require a workstation CIDR: $forbidden"
  fi
done
for text in \
  '### 7-L. Azure Portal Cloud Shell: GitHub App PEM file 업로드' \
  '**Manage files** → **Upload**' \
  'cd ~/aca-github-runner-workshop' \
  'bash scripts/store-github-app-private-key.sh "$RG"' \
  '**실제 Key Vault 확인:**' \
  '`kvacarunner<suffix>`' \
  '**Objects** → **Secrets**' \
  'Secret Identifier'; do
  assert_contains "$step_seven_portal" "$text" \
    'module 01 step 7-L Azure Portal secret guidance missing'
done
if [[ "$step_seven_section" == *'!['* ]]; then
  fail 'module 01 step 7 must not include reference images'
fi
for text in \
  'UPLOADED_PEM_FILE="$HOME/$UPLOADED_PEM_NAME"' \
  'openssl pkey -in "$UPLOADED_PEM_FILE" -check -noout' \
  'az keyvault list' \
  '--resource-group "$RG"' \
  'ERROR: Resource Group에서 Key Vault를 정확히 하나 찾지 못했습니다:' \
  'az keyvault secret set' \
  '--name "$GITHUB_APP_KEY_SECRET"' \
  '--file "$UPLOADED_PEM_FILE"' \
  '--content-type "application/x-pem-file"' \
  'rm -f -- "$UPLOADED_PEM_FILE"' \
  'if ! SECRET_ID="$(' \
  'ERROR: Key Vault secret 저장에 실패했습니다.' \
  'PASS: Key Vault secret 저장 완료:'; do
  assert_contains "$GITHUB_APP_KEY_STORE_TEXT" "$text" \
    'module 01 private key store behavior missing'
done
if grep -F 'store_github_app_private_key()' "$PREREQ" >/dev/null; then
  fail 'module 01 step 7-L must not expose the private key store implementation inline'
fi
bash -n "$GITHUB_APP_KEY_STORE" ||
  fail 'module 01 GitHub App private key store script has invalid Bash syntax'
for forbidden in \
  'Value | 로컬 PEM 파일의 전체 내용' \
  '클립보드에 남은 PEM'; do
  if [[ "$step_seven_portal" == *"$forbidden"* ]]; then
    fail "module 01 step 7-L must use the Cloud Shell file upload path: $forbidden"
  fi
done
for forbidden in \
  'az login' \
  'export SUBSCRIPTION_ID=' \
  '로컬 워크스테이션 Bash'; do
  if [[ "$step_seven_section" == *"$forbidden"* ]]; then
    fail "module 01 step 7 must stay in the existing Cloud Shell session: $forbidden"
  fi
done
for text in \
  '## 7. Key Vault 만들기와 GitHub App private key 저장' \
  '### 7-C. Cloud Shell: Key Vault bootstrap' \
  'SUFFIX="${SUFFIX:-$(openssl rand -hex 3)}"' \
  'LOC="${LOC:-koreacentral}"' \
  'RG="${RG:-rg-acarunner-$SUFFIX}"' \
  'KEY_VAULT="${KEY_VAULT:-kvacarunner$SUFFIX}"' \
  'GITHUB_APP_KEY_SECRET="${GITHUB_APP_KEY_SECRET:-github-app-private-key}"' \
  'az group create' \
  '--name "$RG"' \
  'az keyvault create' \
  '--enable-rbac-authorization true' \
  '--public-network-access Enabled' \
  '--default-action Allow' \
  'KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID=$(az ad signed-in-user show' \
  'Key Vault Secrets Officer' \
  '### 7-L. Azure Portal Cloud Shell: GitHub App PEM file 업로드' \
  '# 동일한 이름을 재사용할 수 있도록 공통 Azure 리소스 이름을 변수로 만듭니다.' \
  '# 이후 모든 Azure 리소스를 함께 정리할 Resource Group을 먼저 만듭니다.' \
  '# GitHub App private key를 보관할 RBAC 기반 Key Vault를 만듭니다.' \
  '# RBAC 설정에 필요한 vault와 현재 사용자 식별자를 조회합니다.' \
  '# 현재 사용자에게 PEM 저장에 필요한 임시 secret 관리 권한을 부여합니다.' \
  '# Module 02에서 다시 사용할 bootstrap 값을 화면에 출력해 따로 기록합니다.'; do
  assert_contains "$step_seven_section" "$text" \
    'module 01 step 7 Key Vault bootstrap missing'
done

step_eight_section="$(
  awk '
    /^## 8\. / { in_section=1 }
    /^## 트러블슈팅/ { exit }
    in_section { print }
  ' "$PREREQ"
)"
for text in \
  '## 8. Cloud Shell에서 GitHub App 설치 범위 검증' \
  'cd ~/aca-github-runner-workshop' \
  'bash scripts/verify-github-app-installation.sh "$RG"' \
  'Azure Portal의 Key Vault → **Objects** → **Secrets**' \
  '`github-app-private-key`가 **Enabled** 상태인지 확인할 수 있습니다.' \
  '![Azure Portal에서 생성된 github-app-private-key secret 확인](images/01-key-vault-secret-created.png)'; do
  assert_contains "$step_eight_section" "$text" \
    'module 01 step 8 intuitive script execution missing'
done
for text in \
  '[1/4] 입력값 확인' \
  '[2/4] Key Vault private key 확인' \
  '[3/4] GitHub App 설치와 권한 확인' \
  '[4/4] 접근 repository 확인' \
  'az keyvault secret download' \
  '--name "$GITHUB_APP_KEY_SECRET"' \
  '--encoding utf-8' \
  'mktemp' \
  'rm -f -- "$TEMP_PRIVATE_KEY_FILE"' \
  'trap cleanup EXIT' \
  'unset app_jwt' \
  'unset installation_token' \
  'openssl pkey -in "$TEMP_PRIVATE_KEY_FILE" -check -noout' \
  'openssl dgst -binary -sha256 -sign "$TEMP_PRIVATE_KEY_FILE"' \
  'Authorization: Bearer $app_jwt' \
  '"https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID"' \
  '.repository_selection == "selected"' \
  '.permissions.administration == "write"' \
  '.permissions.actions == "read"' \
  '"https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens"' \
  '"https://api.github.com/installation/repositories?per_page=100"' \
  '.total_count == 1' \
  'PASS: Key Vault secret과 GitHub App 설치 범위 확인' \
  'GITHUB_APP_INSTALLATION_ID; do' \
  'ERROR: required variable is not set:' \
  '# 인증에 필요한 Cloud Shell 명령이 모두 설치되어 있는지 먼저 확인합니다.' \
  '# 앞 단계에서 입력한 Azure와 GitHub 식별자가 현재 Cloud Shell에 있는지 확인합니다.' \
  '# Resource Group의 실제 Key Vault 이름을 조회해 stale KEY_VAULT 값을 사용하지 않습니다.' \
  '# App ID와 Installation ID가 GitHub에서 사용하는 양의 정수 형식인지 검사합니다.' \
  '# 임시 private key 파일을 만들고 script 종료 시 secret과 JWT를 항상 정리합니다.' \
  '# Key Vault secret을 보호된 임시 파일로 내려받아 JWT 서명에 사용합니다.' \
  '# 다운로드한 값이 줄바꿈이 보존된 유효한 PEM private key인지 확인합니다.' \
  '# GitHub App JWT에 사용할 base64url 인코딩 함수를 정의합니다.' \
  '# 현재 시간을 기준으로 10분 이내에 만료되는 GitHub App JWT payload를 만듭니다.' \
  '# Key Vault에서 받은 private key로 JWT에 RS256 서명합니다.' \
  '# JWT로 Installation 정보와 App 권한 및 organization 범위를 확인합니다.' \
  '# Installation token으로 접근 가능한 repository가 실습 저장소 하나뿐인지 확인합니다.'; do
  assert_contains "$GITHUB_APP_VERIFIER_TEXT" "$text" \
    'module 01 GitHub App verifier behavior missing'
done
for forbidden in \
  'read -rp "Azure subscription ID:' \
  'read -rp "Key Vault name:' \
  'read -rp "GitHub App ID:' \
  'read -rp "GitHub App Installation ID:'; do
  if [[ "$step_eight_section" == *"$forbidden"* ]]; then
    fail "module 01 step 8 must reuse existing variables instead of prompting: $forbidden"
  fi
done
if grep -F 'verify_key_vault_app_installation()' "$PREREQ" >/dev/null; then
  fail 'module 01 step 8 must not expose the verifier implementation inline'
fi
bash -n "$GITHUB_APP_VERIFIER" ||
  fail 'module 01 GitHub App verifier has invalid Bash syntax'

store_fake_bin="$(mktemp -d)"
store_fake_home="$(mktemp -d)"
printf '%s\n' 'test private key' >"$store_fake_home/github-app.pem"
cat >"$store_fake_bin/az" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *'keyvault list'* ]]; then
  printf 'kvacarunnera1b2c3\n'
  exit 0
fi
if [[ "$*" == *'keyvault secret set'* ]]; then
  printf 'ERROR: simulated Key Vault DNS failure\n' >&2
  exit 1
fi
exit 0
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$store_fake_bin/openssl"
chmod +x "$store_fake_bin/az" "$store_fake_bin/openssl"

if store_failure_output="$(
  printf 'github-app.pem\n' |
    env -i \
      PATH="$store_fake_bin:/usr/bin:/bin" \
      HOME="$store_fake_home" \
      KEY_VAULT='kvacarunner' \
      bash "$GITHUB_APP_KEY_STORE" 'rg-acarunner-a1b2c3' 2>&1
)"; then
  fail 'module 01 private key store must fail when az keyvault secret set fails'
fi
assert_contains \
  "$store_failure_output" \
  '실제 Key Vault 확인: kvacarunnera1b2c3' \
  'module 01 private key store must resolve the vault from the resource group'
if [[ "$store_failure_output" == *'PASS: Key Vault secret 저장 완료:'* ]]; then
  fail 'module 01 private key store must not print PASS after an Azure CLI failure'
fi
[[ ! -e "$store_fake_home/github-app.pem" ]] ||
  fail 'module 01 private key store must remove the uploaded PEM after failure'

rm -f -- "$store_fake_bin/az" "$store_fake_bin/openssl"
rmdir -- "$store_fake_bin" "$store_fake_home"

fake_bin="$(mktemp -d)"
for fake_command in az openssl curl jq; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$fake_bin/$fake_command"
  chmod +x "$fake_bin/$fake_command"
done

if missing_variable_output="$(
  env -i \
    PATH="$fake_bin:/usr/bin:/bin" \
    HOME="${HOME:-/tmp}" \
    bash "$GITHUB_APP_VERIFIER" 'rg-acarunner-a1b2c3' 2>&1
)"; then
  fail 'module 01 GitHub App verifier must reject missing variables'
fi
assert_contains \
  "$missing_variable_output" \
  'ERROR: required variable is not set: SUBSCRIPTION_ID' \
  'module 01 GitHub App verifier must identify the first missing variable'

if invalid_id_output="$(
  env -i \
    PATH="$fake_bin:/usr/bin:/bin" \
    HOME="${HOME:-/tmp}" \
    SUBSCRIPTION_ID='00000000-1111-2222-3333-444444444444' \
    KEY_VAULT='kvacarunnertest' \
    GITHUB_OWNER='contoso' \
    GITHUB_REPO='aca-runner-lab' \
    GITHUB_APP_ID='not-a-number' \
    GITHUB_APP_INSTALLATION_ID='12345678' \
    bash "$GITHUB_APP_VERIFIER" 'rg-acarunner-a1b2c3' 2>&1
)"; then
  fail 'module 01 GitHub App verifier must reject invalid App IDs'
fi
assert_contains \
  "$invalid_id_output" \
  'ERROR: App ID and Installation ID must be positive integers.' \
  'module 01 GitHub App verifier must explain the identifier format'

for fake_command in az openssl curl jq; do
  rm -f -- "$fake_bin/$fake_command"
done
rmdir -- "$fake_bin"
for forbidden in \
  'az login' \
  'export SUBSCRIPTION_ID=' \
  '로컬 워크스테이션'; do
  if [[ "$step_eight_section" == *"$forbidden"* ]]; then
    fail "module 01 step 8 must run directly in the existing Cloud Shell session: $forbidden"
  fi
done
for text in \
  'GitHub App private key를 Azure Portal Cloud Shell의 file upload로 Key Vault secret에 저장한다.' \
  'Key Vault에 저장된 private key로 App ID, Installation ID, 권한과 repository 범위를 인증한다.'; do
  assert_contains "$PREREQ_TEXT" "$text" \
    'module 01 goals must include Key Vault bootstrap and authentication'
done

assert_contains \
  "$PREREQ_TEXT" \
  'RBAC 전파에는 최대 10분이 걸릴 수 있습니다.' \
  'module 01 must allow sufficient time for Azure RBAC propagation'
assert_contains \
  "$PREREQ_TEXT" \
  'export SUBSCRIPTION_ID' \
  'module 01 must export the selected subscription for the verifier script'
if [[ "$PREREQ_TEXT" == *'최대 2분'* ]]; then
  fail 'module 01 must not claim Azure RBAC propagation is limited to two minutes'
fi
for text in \
  "Failed to resolve 'kvacarunner.vault.azure.net'" \
  'PASS: Key Vault secret 저장 완료:' \
  'git pull --ff-only' \
  'bash scripts/store-github-app-private-key.sh "$RG"'; do
  assert_contains "$PREREQ_TEXT" "$text" \
    'module 01 troubleshooting must cover stale Key Vault names and false PASS output'
done
if [[ "$step_five_section" == *'다음 모듈에서는 Cloud Shell의 비밀이 아닌 식별자와 로컬 워크스테이션에만 남겨 둔'* ]]; then
  fail 'module 01 step 5 must not claim the next module directly creates the installation token'
fi

if [[ "$step_eight_section" == *'-sign "$GITHUB_APP_PRIVATE_KEY_FILE"'* ]]; then
  fail "module 01 step 8 must authenticate with the Key Vault download, not the source PEM"
fi

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

module_two_step_one="$(
  awk '
    /^## 1\. / { in_section=1 }
    /^## 2\. / { exit }
    in_section { print }
  ' "$FOUNDATION"
)"
for text in \
  'Module 01에서 저장한 `SUFFIX`' \
  'if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then' \
  'read -rp "Saved SUFFIX:' \
  'read -rp "Saved subscription ID:' \
  'read -rp "Saved Key Vault bootstrap principal object ID:' \
  'az account set --subscription "$SUBSCRIPTION_ID"' \
  'az keyvault list' \
  '--resource-group "$RG"' \
  'KEY_VAULT="${VAULT_NAMES[0]}"' \
  'KEY_VAULT_ID=$(az keyvault show'; do
  assert_contains "$module_two_step_one" "$text" \
    'module 02 must restore Module 01 Key Vault values'
done
subscription_set_line="$(printf '%s\n' "$module_two_step_one" | grep -nF 'az account set --subscription "$SUBSCRIPTION_ID"' | head -n1 | cut -d: -f1)"
keyvault_list_line="$(printf '%s\n' "$module_two_step_one" | grep -nF 'az keyvault list' | head -n1 | cut -d: -f1)"
keyvault_show_line="$(printf '%s\n' "$module_two_step_one" | grep -nF 'KEY_VAULT_ID=$(az keyvault show' | head -n1 | cut -d: -f1)"
[[ -n "$subscription_set_line" && -n "$keyvault_list_line" && -n "$keyvault_show_line" &&
  "$subscription_set_line" -lt "$keyvault_list_line" && "$keyvault_list_line" -lt "$keyvault_show_line" ]] ||
  fail 'module 02 must select the subscription and resolve the actual vault before az keyvault show'
for text in \
  'Module 01에서 만든 Key Vault를 재사용한다.' \
  'Key Vault Private Endpoint와 runtime RBAC를 완성한다.'; do
  assert_contains "$FOUNDATION_TEXT" "$text" \
    'module 02 goals must describe Key Vault reuse and hardening'
done
if [[ "$module_two_step_one" == *'SUFFIX="$(openssl rand -hex 3)"'* ]]; then
  fail "module 02 must not generate a new suffix"
fi
if [[ "$module_two_step_one" == *'KEY_VAULT_BOOTSTRAP_CIDR'* ]]; then
  fail 'module 02 must not restore a Key Vault bootstrap CIDR'
fi
if [[ "$module_two_step_one" == *'read -rp "Saved Key Vault name:'* ]]; then
  fail 'module 02 must not prompt for a stale Key Vault name'
fi

module_two_step_two="$(
  awk '
    /^## 2\. / { in_section=1 }
    /^## 3\. / { exit }
    in_section { print }
  ' "$FOUNDATION"
)"
assert_contains "$module_two_step_two" 'az group show' \
  'module 02 step 2 must verify the Module 01 resource group'
if [[ "$module_two_step_two" == *'az group create'* ]]; then
  fail "module 02 must not recreate the Module 01 resource group"
fi

module_two_step_eight="$(
  awk '
    /^## 8\. / { in_section=1 }
    /^## 트러블슈팅/ { exit }
    in_section { print }
  ' "$FOUNDATION"
)"
for text in \
  '## 8. Key Vault private network와 runtime access 완성' \
  '--group-id vault' \
  'privatelink.vaultcore.azure.net' \
  'Key Vault Secrets User' \
  '--public-network-access Disabled' \
  '--assignee "$KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID"' \
  '--role "Key Vault Secrets Officer"' \
  'KEY_VAULT_SECRET_URI=' \
  '## 8-L. Local workstation: private access 검증 후 원본 PEM 삭제'; do
  assert_contains "$module_two_step_eight" "$text" \
    'module 02 step 8 Key Vault hardening missing'
done
for forbidden in \
  'KEY_VAULT_BOOTSTRAP_CIDR' \
  'az keyvault network-rule remove'; do
  if [[ "$module_two_step_eight" == *"$forbidden"* ]]; then
    fail "module 02 step 8 must not remove a nonexistent CIDR rule: $forbidden"
  fi
done
for forbidden in \
  'az keyvault create' \
  'az keyvault secret set' \
  '## 8-L. Local workstation: GitHub App PEM 업로드'; do
  if [[ "$module_two_step_eight" == *"$forbidden"* ]]; then
    fail "module 02 step 8 still owns Module 01 bootstrap behavior: $forbidden"
  fi
done
for forbidden in \
  'az keyvault create' \
  'az keyvault secret set'; do
  if grep -F -- "$forbidden" "$FOUNDATION" >/dev/null; then
    fail "module 02 must not duplicate Module 01 Key Vault bootstrap anywhere: $forbidden"
  fi
done

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
