# Key Vault Module Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Key Vault creation and GitHub App PEM upload into Module 01 step 7, renumber the existing installation authentication to step 8, authenticate with the Key Vault-stored secret, and make Module 02 reuse and harden that Key Vault.

**Architecture:** Module 01 becomes the bootstrap boundary: it creates the shared Resource Group and Key Vault, uploads the PEM from the local workstation, then downloads the stored secret to a protected temporary file to authenticate the App ID and Installation ID. Module 02 restores the Module 01 identifiers, builds the VNet/UAMI resources, and retains only the Key Vault Private Endpoint, DNS, runtime RBAC, public-access lock, and final source-PEM deletion.

**Tech Stack:** Markdown workshop documentation, Bash, Azure CLI, GitHub REST API, OpenSSL, jq, shell-based documentation contract tests.

**Spec:** `docs/superpowers/specs/2026-08-22-key-vault-module-restructure-design.md`

## Global Constraints

- The original GitHub App PEM must never enter Cloud Shell.
- PEM content, Key Vault secret content, and App JWT values must never be printed.
- Module 01 must upload the source PEM with `az keyvault secret set --file`.
- Module 01 step 8 must authenticate with a protected temporary file downloaded from Key Vault, not the source PEM.
- Module 01 step 8 must remove the temporary PEM and JWT on success and failure.
- The source PEM remains on the local workstation until Module 02 verifies Key Vault private networking and access lockdown.
- Key Vault bootstrap access is limited to one workstation IPv4 CIDR and one temporary `Key Vault Secrets Officer` assignment.
- Module 02 removes the bootstrap role and firewall CIDR after Private Endpoint validation.
- Module 02 must reuse the Module 01 `SUFFIX`, `RG`, and actual `KEY_VAULT`; it must not generate a new suffix or create a second Key Vault.
- VNet, Private Endpoint subnet, UAMI creation, Key Vault Private Endpoint, Private DNS, and runtime RBAC remain in Module 02.
- Every new or changed execution Bash block starts with a Korean purpose comment.
- Use the existing test runners only; do not add dependencies.

---

### Task 1: Move Key Vault Bootstrap Into Module 01

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh:180-250`
- Modify: `docs/01-prerequisites-github.md:296-440`

**Interfaces:**
- Consumes: Module 01 step 1 `SUBSCRIPTION_ID`; step 5 GitHub App PEM; step 6 `GITHUB_APP_ID` and `GITHUB_APP_INSTALLATION_ID`.
- Produces: `SUFFIX`, `LOC`, `RG`, `KEY_VAULT`, `GITHUB_APP_KEY_SECRET`, `KEY_VAULT_ID`, `KEY_VAULT_BOOTSTRAP_CIDR`, and `KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID` for Module 02.

- [ ] **Step 1: Replace the Module 01 step 7 contract with separate step 7 and step 8 contracts**

Replace the current `step_seven_section` assertions in `tests/docs/test-prerequisites-foundation.sh` with:

```bash
step_seven_section="$(
  awk '
    /^## 7\. / { in_section=1 }
    /^## 8\. / { exit }
    in_section { print }
  ' "$PREREQ"
)"
for text in \
  '## 7. Key Vault 만들기와 GitHub App private key 업로드' \
  '### 7-C. Cloud Shell: Key Vault bootstrap' \
  'SUFFIX="$(openssl rand -hex 3)"' \
  'RG="rg-acarunner-$SUFFIX"' \
  'KEY_VAULT="kvacarunner$SUFFIX"' \
  'GITHUB_APP_KEY_SECRET="github-app-private-key"' \
  'az group create --name "$RG"' \
  'az keyvault create' \
  '--enable-rbac-authorization true' \
  '--public-network-access Enabled' \
  '--default-action Deny' \
  'KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID=$(az ad signed-in-user show' \
  'KEY_VAULT_BOOTSTRAP_CIDR' \
  'Key Vault Secrets Officer' \
  '### 7-L. Local workstation: GitHub App PEM 업로드' \
  'az keyvault secret set' \
  '--file "$GITHUB_APP_PRIVATE_KEY_FILE"' \
  '--encoding utf-8'; do
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
  '## 8. Key Vault secret으로 GitHub App 설치 연결 검증' \
  'az keyvault secret download' \
  '--name "$GITHUB_APP_KEY_SECRET"' \
  '--encoding utf-8' \
  'mktemp' \
  'trap cleanup EXIT' \
  'openssl dgst -binary -sha256 -sign "$TEMP_PRIVATE_KEY_FILE"' \
  '"https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID"' \
  'select(.app_id == $app_id)' \
  'PASS: Key Vault secret으로 App ID와 Installation ID 연결 확인'; do
  assert_contains "$step_eight_section" "$text" \
    'module 01 step 8 stored-secret authentication missing'
done
for text in \
  'GitHub App private key를 Azure Key Vault에 업로드한다.' \
  'Key Vault에 저장된 private key로 App ID와 Installation ID의 실제 연결을 인증한다.'; do
  assert_contains "$PREREQ_TEXT" "$text" \
    'module 01 goals must include Key Vault bootstrap and authentication'
done

if [[ "$step_eight_section" == *'-sign "$GITHUB_APP_PRIVATE_KEY_FILE"'* ]]; then
  fail "module 01 step 8 must authenticate with the Key Vault download, not the source PEM"
fi
```

- [ ] **Step 2: Run the focused documentation contract and verify RED**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: FAIL with `module 01 step 7 Key Vault bootstrap missing`.

- [ ] **Step 3: Add Module 01 step 7 Cloud Shell bootstrap**

Insert `## 7. Key Vault 만들기와 GitHub App private key 업로드` after step 6. Explain that the Cloud Shell portion creates shared Azure identifiers and allows only the local workstation CIDR.

Update the Module 01 summary and goals with:

```markdown
- GitHub App private key를 Azure Key Vault에 업로드한다.
- Key Vault에 저장된 private key로 App ID와 Installation ID의 실제 연결을 인증한다.
```

Use this execution block:

```bash
# Module 01과 이후 Azure 모듈이 함께 사용할 Resource Group과 Key Vault를 준비합니다.
SUFFIX="$(openssl rand -hex 3)"
LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
KEY_VAULT="kvacarunner$SUFFIX"
GITHUB_APP_KEY_SECRET="github-app-private-key"

az group create \
  --name "$RG" \
  --location "$LOC" \
  --output none

az keyvault create \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --location "$LOC" \
  --enable-rbac-authorization true \
  --retention-days 7 \
  --enable-purge-protection false \
  --public-network-access Enabled \
  --default-action Deny \
  --bypass None \
  --output none

KEY_VAULT_ID=$(az keyvault show \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --query id \
  --output tsv)
KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID=$(az ad signed-in-user show \
  --query id \
  --output tsv)
read -rp "Local workstation public IPv4 CIDR (for example 203.0.113.10/32): " \
  KEY_VAULT_BOOTSTRAP_CIDR

az keyvault network-rule add \
  --name "$KEY_VAULT" \
  --ip-address "$KEY_VAULT_BOOTSTRAP_CIDR" \
  --output none

az role assignment create \
  --assignee-object-id "$KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID" \
  --assignee-principal-type User \
  --role "Key Vault Secrets Officer" \
  --scope "$KEY_VAULT_ID" \
  --output none

printf '다음 값을 저장하세요: SUFFIX=%s RG=%s KEY_VAULT=%s\n' \
  "$SUFFIX" "$RG" "$KEY_VAULT"
printf 'KEY_VAULT_BOOTSTRAP_CIDR=%s\nKEY_VAULT_BOOTSTRAP_PRINCIPAL_ID=%s\n' \
  "$KEY_VAULT_BOOTSTRAP_CIDR" "$KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID"
```

State that the participant must save all printed values and that RBAC propagation can take up to two minutes.

- [ ] **Step 4: Add Module 01 step 7 local PEM upload**

Add `### 7-L. Local workstation: GitHub App PEM 업로드` with:

```bash
# 로컬 PEM 파일을 화면에 출력하지 않고 Module 01에서 만든 Key Vault에 업로드합니다.
set -euo pipefail
az login
read -rp "Azure subscription ID: " SUBSCRIPTION_ID
read -rp "Key Vault name: " KEY_VAULT
read -rp "GitHub App PEM file path: " GITHUB_APP_PRIVATE_KEY_FILE
GITHUB_APP_KEY_SECRET="github-app-private-key"

az account set --subscription "$SUBSCRIPTION_ID"
test -f "$GITHUB_APP_PRIVATE_KEY_FILE"
chmod 600 "$GITHUB_APP_PRIVATE_KEY_FILE"

az keyvault secret set \
  --vault-name "$KEY_VAULT" \
  --name "$GITHUB_APP_KEY_SECRET" \
  --file "$GITHUB_APP_PRIVATE_KEY_FILE" \
  --encoding utf-8 \
  --query "{id:id,enabled:attributes.enabled}" \
  --output yaml
```

Keep the existing metadata-only expected output. State explicitly that the source PEM remains until Module 02 completes private-access verification.

- [ ] **Step 5: Renumber the current step 7 and authenticate with the Key Vault secret**

Replace the current step 7 with `## 8. Key Vault secret으로 GitHub App 설치 연결 검증`.

Use a subshell-backed function so the `EXIT` trap runs immediately when the function completes:

```bash
# Key Vault에 업로드한 private key로 App ID와 Installation ID의 실제 연결을 검증합니다.
verify_key_vault_app_installation() (
  set -euo pipefail

  local SUBSCRIPTION_ID KEY_VAULT GITHUB_APP_KEY_SECRET
  local GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID
  local TEMP_PRIVATE_KEY_FILE now_epoch payload_json signing_input
  local app_jwt installation_owner required_command

  for required_command in az openssl curl jq; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
      printf 'ERROR: required command not found: %s\n' "$required_command" >&2
      return 1
    fi
  done

  read -rp "Azure subscription ID: " SUBSCRIPTION_ID
  read -rp "Key Vault name: " KEY_VAULT
  read -rp "GitHub App ID: " GITHUB_APP_ID
  read -rp "GitHub App Installation ID: " GITHUB_APP_INSTALLATION_ID
  GITHUB_APP_KEY_SECRET="github-app-private-key"

  if [[ ! "$GITHUB_APP_ID" =~ ^[1-9][0-9]*$ ]] ||
    [[ ! "$GITHUB_APP_INSTALLATION_ID" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERROR: App ID and Installation ID must be positive integers.\n' >&2
    return 1
  fi

  az account set --subscription "$SUBSCRIPTION_ID"
  TEMP_PRIVATE_KEY_FILE="$(mktemp)"
  cleanup() {
    rm -f -- "$TEMP_PRIVATE_KEY_FILE"
    unset app_jwt
  }
  trap cleanup EXIT

  az keyvault secret download \
    --vault-name "$KEY_VAULT" \
    --name "$GITHUB_APP_KEY_SECRET" \
    --file "$TEMP_PRIVATE_KEY_FILE" \
    --encoding utf-8 \
    --output none
  chmod 600 "$TEMP_PRIVATE_KEY_FILE"

  base64url_encode() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
  }

  now_epoch="$(date +%s)"
  printf -v payload_json '{"iat":%s,"exp":%s,"iss":%s}' \
    "$((now_epoch - 60))" "$((now_epoch + 540))" "$GITHUB_APP_ID"
  signing_input="$(
    printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url_encode
  ).$(
    printf '%s' "$payload_json" | base64url_encode
  )"
  app_jwt="${signing_input}.$(
    printf '%s' "$signing_input" |
      openssl dgst -binary -sha256 -sign "$TEMP_PRIVATE_KEY_FILE" |
      base64url_encode
  )"

  if ! installation_owner="$(
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $app_jwt" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID" |
      jq -er --argjson app_id "$GITHUB_APP_ID" \
        'select(.app_id == $app_id) | .account.login'
  )"; then
    printf 'ERROR: Key Vault secret, App ID, or Installation ID does not match.\n' >&2
    return 1
  fi

  printf 'PASS: Key Vault secret으로 App ID와 Installation ID 연결 확인: App %s, Installation %s, Owner %s\n' \
    "$GITHUB_APP_ID" "$GITHUB_APP_INSTALLATION_ID" "$installation_owner"
)

verify_key_vault_app_installation &&
  unset -f verify_key_vault_app_installation
```

Explain that this verifies the uploaded secret, App ID, and Installation ID as one real GitHub App installation. Do not delete the source PEM here.

- [ ] **Step 6: Move Key Vault creation/upload troubleshooting into Module 01**

Add these Module 01 troubleshooting cases:

```markdown
| `az keyvault create`가 이름 중복 오류를 반환함 | `KEY_VAULT` 이름은 전역 고유인데 이미 사용 중 | `KEY_VAULT="kvacarunner$(openssl rand -hex 5)"`로 vault 이름만 바꾸고 7-C를 다시 실행한 뒤 실제 이름을 저장합니다. |
| local PEM 업로드 또는 step 8 secret download가 `403 Forbidden`으로 실패함 | workstation CIDR이 다르거나 `Key Vault Secrets Officer` RBAC가 아직 전파되지 않음 | 로컬에서 `curl -s https://ifconfig.me`를 확인하고 firewall CIDR을 수정하거나 최대 2분 기다린 뒤 다시 실행합니다. |
| step 8이 GitHub `401` 또는 `404`로 실패함 | App ID, Installation ID, 또는 Key Vault에 저장된 PEM이 서로 다른 GitHub App에 속함 | 5단계 App settings와 installation URL을 다시 확인하고 같은 App의 PEM을 7-L에서 다시 업로드합니다. |
```

Move the Key Vault name collision recovery command block into Module 01 beneath the troubleshooting table.

Use:

```bash
# Key Vault 이름 충돌이 발생한 경우 vault 이름만 새 전역 고유 값으로 바꿉니다.
KEY_VAULT="kvacarunner$(openssl rand -hex 5)"
printf '새 Key Vault 이름을 저장하세요: %s\n' "$KEY_VAULT"
```

State that `SUFFIX`, `RG`, and all other resource names remain unchanged.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: PASS. Defer `test-execution-comments.sh` until Task 2 removes the two original Module 02 bootstrap blocks; the intermediate Task 1 state intentionally contains two additional execution blocks.

- [ ] **Step 8: Commit Module 01 bootstrap**

```bash
git add docs/01-prerequisites-github.md tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: move Key Vault bootstrap to module 01"
```

---

### Task 2: Make Module 02 Reuse and Harden the Module 01 Key Vault

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh:80-285`
- Modify: `docs/02-azure-foundation.md:1-730`

**Interfaces:**
- Consumes: Module 01 `SUFFIX`, `RG`, actual `KEY_VAULT`, `KEY_VAULT_BOOTSTRAP_CIDR`, `KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID`, and uploaded `github-app-private-key`.
- Produces: `KEY_VAULT_SECRET_URI`, private DNS, Key Vault Private Endpoint, UAMI `Key Vault Secrets User`, and a locked-down Key Vault for Modules 04-06.

- [ ] **Step 1: Add failing Module 02 handoff and ownership tests**

Add section extractors and assertions to `tests/docs/test-prerequisites-foundation.sh`:

```bash
module_two_step_one="$(
  awk '
    /^## 1\. / { in_section=1 }
    /^## 2\. / { exit }
    in_section { print }
  ' "$FOUNDATION"
)"
for text in \
  'Module 01에서 저장한 `SUFFIX`' \
  'read -rp "Saved SUFFIX:' \
  'read -rp "Saved Key Vault name:' \
  'read -rp "Saved Key Vault bootstrap CIDR:' \
  'read -rp "Saved Key Vault bootstrap principal object ID:' \
  'KEY_VAULT_ID=$(az keyvault show'; do
  assert_contains "$module_two_step_one" "$text" \
    'module 02 must restore Module 01 Key Vault values'
done
for text in \
  'Module 01에서 만든 Key Vault를 재사용한다.' \
  'Key Vault Private Endpoint와 runtime RBAC를 완성한다.'; do
  assert_contains "$FOUNDATION_TEXT" "$text" \
    'module 02 goals must describe Key Vault reuse and hardening'
done
if [[ "$module_two_step_one" == *'SUFFIX="$(openssl rand -hex 3)"'* ]]; then
  fail "module 02 must not generate a new suffix"
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
  '--ip-address "$KEY_VAULT_BOOTSTRAP_CIDR"' \
  'KEY_VAULT_SECRET_URI=' \
  '## 8-L. Local workstation: private access 검증 후 원본 PEM 삭제'; do
  assert_contains "$module_two_step_eight" "$text" \
    'module 02 step 8 Key Vault hardening missing'
done
for forbidden in \
  'az keyvault create' \
  'az keyvault secret set' \
  '## 8-L. Local workstation: GitHub App PEM 업로드'; do
  if [[ "$module_two_step_eight" == *"$forbidden"* ]]; then
    fail "module 02 step 8 still owns Module 01 bootstrap behavior: $forbidden"
  fi
done
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: FAIL because Module 02 still generates a new suffix and still contains Key Vault creation/upload.

- [ ] **Step 3: Rewrite Module 02 step 1 to restore Module 01 values**

Change the heading to `## 1. Module 01 공통 변수 복원`.

Update the Module 02 summary, architecture explanation, and goals with:

```markdown
- Module 01에서 만든 Key Vault를 재사용한다.
- Key Vault Private Endpoint와 runtime RBAC를 완성한다.
```

Remove wording that claims Module 02 creates the Key Vault or uploads the GitHub App private key.

Use:

```bash
# Module 01에서 저장한 식별자를 복원하고 나머지 Azure 리소스 이름을 같은 suffix에서 파생합니다.
if [[ -z "${SUFFIX:-}" ]]; then
  read -rp "Saved SUFFIX: " SUFFIX
fi
if [[ -z "${KEY_VAULT:-}" ]]; then
  read -rp "Saved Key Vault name: " KEY_VAULT
fi
if [[ -z "${KEY_VAULT_BOOTSTRAP_CIDR:-}" ]]; then
  read -rp "Saved Key Vault bootstrap CIDR: " KEY_VAULT_BOOTSTRAP_CIDR
fi
if [[ -z "${KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID:-}" ]]; then
  read -rp "Saved Key Vault bootstrap principal object ID: " \
    KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID
fi

LOC="${LOC:-koreacentral}"
RG="${RG:-rg-acarunner-$SUFFIX}"
LOG="log-acarunner-$SUFFIX"
ENV="env-acarunner-$SUFFIX"
VNET="vnet-acarunner-$SUFFIX"
INFRA_SUBNET="snet-aca-infra"
PE_SUBNET="snet-private-endpoints"
ACR="acracarunner$SUFFIX"
STORAGE="stacarunner$SUFFIX"
STORAGE_CONTAINER="runner-artifacts"
STORAGE_PE="pe-blob-$SUFFIX"
STORAGE_DNS_ZONE="privatelink.blob.core.windows.net"
STORAGE_DNS_LINK="link-blob-$SUFFIX"
KEY_VAULT_PE="pe-kv-$SUFFIX"
KEY_VAULT_DNS_ZONE="privatelink.vaultcore.azure.net"
KEY_VAULT_DNS_LINK="link-kv-$SUFFIX"
GITHUB_APP_KEY_SECRET="github-app-private-key"
PRIVATE_ENDPOINT_CIDR="10.20.1.0/24"
UAMI="id-acarunner-$SUFFIX"
JOB="job-ghrunner-$SUFFIX"
IMAGE="github-actions-runner:2.336.0"

KEY_VAULT_ID=$(az keyvault show \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --query id \
  --output tsv)

printf 'SUFFIX=%s RG=%s ACR=%s STORAGE=%s KEY_VAULT=%s\n' \
  "$SUFFIX" "$RG" "$ACR" "$STORAGE" "$KEY_VAULT"
```

Explain that a missing Key Vault means Module 01 is incomplete and that a new suffix must not be generated.

- [ ] **Step 4: Change Module 02 step 2 to verify the Resource Group**

Rename the heading to `## 2. Resource Group 확인과 Log Analytics workspace 만들기`.

Replace `az group create` with:

```bash
# Module 01에서 만든 Resource Group을 확인하고 이후 조회에 사용할 ID를 저장합니다.
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
RG_ID=$(az group show \
  --name "$RG" \
  --query id \
  --output tsv)
```

Keep the existing Log Analytics creation and lookup commands.

- [ ] **Step 5: Reduce Module 02 step 8 to private networking and runtime access**

Replace the section heading and introductory text with:

```markdown
## 8. Key Vault private network와 runtime access 완성

Module 01에서 만든 Key Vault와 업로드한 secret을 그대로 사용합니다. 이 단계에서는
Module 02에서 준비한 Private Endpoint subnet과 UAMI를 연결하고 bootstrap public
access를 제거합니다.
```

Keep the current Private Endpoint, Private DNS, UAMI `Key Vault Secrets User`, public-access disable, control-plane validation, and `KEY_VAULT_SECRET_URI` commands.

Replace role deletion by stored assignment ID with:

```bash
az role assignment delete \
  --assignee "$KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KEY_VAULT_ID"
```

Keep firewall removal with `KEY_VAULT_BOOTSTRAP_CIDR`, then:

```bash
unset KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID KEY_VAULT_BOOTSTRAP_CIDR
```

Delete the Key Vault create block and the local secret upload subsection entirely.

- [ ] **Step 6: Make final source-PEM deletion self-contained**

Rename the subsection to `## 8-L. Local workstation: private access 검증 후 원본 PEM 삭제` and prompt for the original file path so a new local shell works:

```bash
# Module 02의 private access 검증 후 원본 GitHub App PEM 파일을 삭제합니다.
set -euo pipefail
read -rp "Original GitHub App PEM file path: " GITHUB_APP_PRIVATE_KEY_FILE
test -f "$GITHUB_APP_PRIVATE_KEY_FILE"
rm -- "$GITHUB_APP_PRIVATE_KEY_FILE"
unset GITHUB_APP_PRIVATE_KEY_FILE
```

- [ ] **Step 7: Remove Module 02 bootstrap troubleshooting and recovery**

Delete the Module 02 rows for:

- `az keyvault create` name collisions;
- local `secret set --file` failures;
- the Key Vault name collision recovery subsection.

Keep and rename references for:

- Private Endpoint pending;
- public network access not disabled;
- UAMI secret read failure.

Replace references to `8-C` with `8단계`.

- [ ] **Step 8: Run focused tests and verify GREEN**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-execution-comments.sh
```

Expected: both PASS and the execution Bash block count remains 41.

- [ ] **Step 9: Commit Module 02 handoff and hardening**

```bash
git add docs/02-azure-foundation.md tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: reuse module 01 Key Vault foundation"
```

---

### Task 3: Update Downstream Module Ownership References

**Files:**
- Modify: `tests/docs/test-build-deploy.sh:65-90`
- Modify: `tests/docs/test-scale-validation.sh:15-35`
- Modify: `tests/docs/test-azure-sample-deployment.sh:15-40`
- Modify: `docs/03-runner-image.md:20-125`
- Modify: `docs/04-event-job-keda.md:40-140,370-390`
- Modify: `docs/05-parallel-scale-validation.md:15-30`
- Modify: `docs/06-azure-sample-deployment.md:15-35`

**Interfaces:**
- Consumes: Module 01 owns `SUFFIX`, Resource Group, Key Vault, secret upload, and GitHub App installation authentication.
- Produces: Accurate recovery and troubleshooting references for Modules 03-06.

- [ ] **Step 1: Add failing ownership wording tests**

In `tests/docs/test-build-deploy.sh`, assert:

```bash
assert_contains "$IMAGE_TEXT" \
  'Module 01에서 저장한 `SUFFIX`' \
  'module 03 must identify Module 01 as the suffix source'
assert_contains "$JOB_TEXT" \
  'Module 01에서 만든 Key Vault와 Module 02에서 완성한 private access' \
  'module 04 must describe split Key Vault ownership'
```

In `tests/docs/test-scale-validation.sh`, assert:

```bash
assert_contains "$recovery_section" \
  'Module 01에서 저장한 `SUFFIX`' \
  'module 05 must identify Module 01 as the suffix source'
```

In `tests/docs/test-azure-sample-deployment.sh`, assert:

```bash
assert_contains "$DOC_TEXT" \
  'Module 01에서 저장한 `SUFFIX`' \
  'module 06 must identify Module 01 as the suffix source'
```

- [ ] **Step 2: Run the three tests and verify RED**

Run:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-azure-sample-deployment.sh
```

Expected: FAIL on the new Module 01 ownership wording.

- [ ] **Step 3: Update Module 03 recovery wording**

Change Module 03 to say:

```markdown
Cloud Shell 세션이 끊기면 Module 01에서 저장한 `SUFFIX`와 실제 `KEY_VAULT`,
Module 02에서 저장한 실제 `ACR` 이름을 사용해 같은 리소스를 복구합니다.
```

Keep `STORAGE` collision handling attributed to Module 02.

- [ ] **Step 4: Update Module 04 recovery and troubleshooting wording**

Replace the Key Vault ownership sentence with:

```markdown
Module 01에서 만든 Key Vault와 Module 02에서 완성한 private access,
`GITHUB_APP_KEY_SECRET`, `KEY_VAULT_SECRET_URI`, `UAMI_RID`를 그대로 사용합니다.
```

Change the Key Vault resolution troubleshooting reference to:

```markdown
Module 01의 secret 업로드와 Module 02의 Key Vault Private Endpoint,
Private DNS, `Key Vault Secrets User` 역할을 순서대로 확인합니다.
```

- [ ] **Step 5: Update Modules 05 and 06 recovery wording**

Use this ownership statement in both modules:

```markdown
Module 01에서 저장한 `SUFFIX`를 그대로 사용하고, Module 02에서 이름 충돌 복구로
변경한 실제 ACR 또는 Storage 이름이 있으면 해당 값을 복원합니다.
```

- [ ] **Step 6: Run focused tests and verify GREEN**

Run:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-azure-sample-deployment.sh
```

Expected: all PASS.

- [ ] **Step 7: Commit downstream reference updates**

```bash
git add \
  docs/03-runner-image.md \
  docs/04-event-job-keda.md \
  docs/05-parallel-scale-validation.md \
  docs/06-azure-sample-deployment.md \
  tests/docs/test-build-deploy.sh \
  tests/docs/test-scale-validation.sh \
  tests/docs/test-azure-sample-deployment.sh
git commit -m "docs: align Key Vault ownership references"
```

---

### Task 4: Update README Module Scope and Timing

**Files:**
- Modify: `tests/docs/test-overview.sh:75-82`
- Modify: `README.md:130-145`

**Interfaces:**
- Consumes: Final Module 01 and Module 02 responsibilities.
- Produces: Accurate workshop overview and unchanged 120-minute total schedule.

- [ ] **Step 1: Change the README contract first**

Replace the Module 01 and Module 02 expectations in `tests/docs/test-overview.sh` with:

```bash
require '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | GitHub App 설치, Key Vault private key 업로드와 실제 installation 인증 | 30분 |' 'README Module 01 row mismatch'
require '| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | Custom VNet ACA Environment, Blob·Key Vault Private Endpoint·Private DNS와 runtime RBAC | 30분 |' 'README Module 02 row mismatch'
```

- [ ] **Step 2: Run the overview test and verify RED**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: FAIL with `README Module 01 row mismatch`.

- [ ] **Step 3: Update the README module table**

Use exactly:

```markdown
| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | GitHub App 설치, Key Vault private key 업로드와 실제 installation 인증 | 30분 |
| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | Custom VNet ACA Environment, Blob·Key Vault Private Endpoint·Private DNS와 runtime RBAC | 30분 |
```

Keep the overall `120분 일정` because the two module estimates still total 60 minutes.

- [ ] **Step 4: Run the overview test and verify GREEN**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: PASS.

- [ ] **Step 5: Commit README scope changes**

```bash
git add README.md tests/docs/test-overview.sh
git commit -m "docs: update module scope and timing"
```

---

### Task 5: Verify the Complete Restructured Workshop

**Files:**
- Verify: `README.md`
- Verify: `docs/01-prerequisites-github.md`
- Verify: `docs/02-azure-foundation.md`
- Verify: `docs/03-runner-image.md`
- Verify: `docs/04-event-job-keda.md`
- Verify: `docs/05-parallel-scale-validation.md`
- Verify: `docs/06-azure-sample-deployment.md`
- Verify: `tests/docs/*.sh`

**Interfaces:**
- Consumes: All prior task outputs.
- Produces: A review-ready branch with no duplicate Key Vault bootstrap flow and passing workshop contracts.

- [ ] **Step 1: Verify the moved command ownership**

Run:

```bash
test "$(grep -cF 'az keyvault create' docs/01-prerequisites-github.md)" -eq 1
test "$(grep -cF 'az keyvault create' docs/02-azure-foundation.md)" -eq 0
test "$(grep -cF 'az keyvault secret set' docs/01-prerequisites-github.md)" -eq 1
test "$(grep -cF 'az keyvault secret set' docs/02-azure-foundation.md)" -eq 0
grep -F 'az keyvault secret download' docs/01-prerequisites-github.md
grep -F -- '--group-id vault' docs/02-azure-foundation.md
grep -F -- '--public-network-access Disabled' docs/02-azure-foundation.md
```

Expected: all commands exit 0.

- [ ] **Step 2: Verify the Module 01 step 8 Bash block syntax**

Extract the step 8 code block and syntax-check it:

```bash
awk '
  /^## 8\. / { in_section=1 }
  in_section && /^```bash$/ { in_code=1; next }
  in_code && /^```$/ { exit }
  in_code { print }
' docs/01-prerequisites-github.md | bash -n
```

Expected: exit 0 with no output.

- [ ] **Step 3: Run all focused documentation tests**

Run:

```bash
bash tests/docs/test-overview.sh
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-runner-image.sh
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-azure-sample-deployment.sh
bash tests/docs/test-security-cleanup.sh
bash tests/docs/test-execution-comments.sh
```

Expected: every test prints `PASS`.

- [ ] **Step 4: Run complete workshop validation sequentially**

Do not run the integrated validators in parallel because runner fixture directories are shared.

```bash
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
python3 tests/test-workflow-yaml.py
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Review the final diff for security regressions**

Run:

```bash
git --no-pager diff --check
git --no-pager diff --stat
git --no-pager diff -- \
  README.md \
  docs/01-prerequisites-github.md \
  docs/02-azure-foundation.md \
  docs/03-runner-image.md \
  docs/04-event-job-keda.md \
  docs/05-parallel-scale-validation.md \
  docs/06-azure-sample-deployment.md \
  tests/docs
```

Confirm:

- no PEM value is echoed or passed through `--value`;
- no App JWT is printed;
- temporary downloaded PEM cleanup is registered before JWT creation;
- Module 02 does not create or upload to Key Vault;
- Module 02 removes both bootstrap access grants;
- source PEM deletion occurs only after private network validation.

- [ ] **Step 6: Commit any validation-only corrections**

If validation required corrections, commit only those corrections:

```bash
git add README.md docs tests
git commit -m "docs: finalize Key Vault module restructure"
```

If no corrections were needed, do not create an empty commit.
