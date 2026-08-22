# 06. Private Blob 배포와 결과 확인

> 필수 모듈입니다. Azure Cloud Shell Bash, GitHub 웹 UI, Azure Portal을 함께 사용해 trusted single-job workflow로 private Blob artifact를 업로드·다운로드하고, managed identity와 Private Endpoint 경로가 실제로 사용됐는지 검증합니다. `private repository`와 `trusted workflow authors` 경계를 유지한 채 runner Job의 public outbound와 Blob data-plane private path를 분리해 증명합니다.
> External ACA Job은 ingress를 지원하지 않으므로, 이 workflow는 inbound reachability가 아니라 private Blob data-plane outbound access만 증명합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- `samples/azure-sample-deploy-workflow.yml`을 Cloud Shell에서 검토한 뒤 GitHub 웹 UI에 workflow를 만든다.
- Event Job이 전달한 `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, `AZURE_PRIVATE_ENDPOINT_CIDR`가 어떤 의미인지 설명할 수 있다.
- GitHub Actions에서 managed identity login, private DNS 확인, `az storage blob upload`, `az storage blob download`, `sha256sum` 검증 흐름을 확인한다.
- `privatelink.blob.core.windows.net`과 configured CIDR을 기준으로 private IP 증거를 해석한다.
- Cloud Shell과 Azure Portal에서 Storage network rules, Private Endpoint approval, DNS A record, role assignment를 control-plane으로 교차 확인한다.

## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

👁️ **설명**

같은 Cloud Shell 세션을 계속 사용 중이라면 이 절은 건너뛰어도 됩니다. 세션이 끊겼다면 Module 01에서 저장한 `SUFFIX`를 그대로 사용하고, Module 02에서 이름 충돌 복구로 변경한 실제 ACR 또는 Storage 이름이 있으면 해당 값을 복원합니다. 원래 subscription ID도 다시 입력해 private Blob 검증에 필요한 Azure 식별자를 복구합니다. 여기서 다루는 값은 식별자이며 secret이 아닙니다. 실제 Azure 인증은 이후 GitHub Actions runner 안에서 managed identity로만 수행합니다.

🟢 **실행**

```bash
# 저장한 suffix, 실제 ACR 이름, 원래 workshop subscription ID를 다시 입력합니다.
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved ACR name: " ACR
read -rp "Saved subscription ID: " SUBSCRIPTION_ID

# suffix 기반 이름과 private Blob foundation 값을 다시 구성합니다.
LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
ENV="env-acarunner-$SUFFIX"
VNET="vnet-acarunner-$SUFFIX"
PE_SUBNET="snet-private-endpoints"
STORAGE="stacarunner$SUFFIX"
STORAGE_CONTAINER="runner-artifacts"
STORAGE_PE="pe-blob-$SUFFIX"
STORAGE_DNS_ZONE="privatelink.blob.core.windows.net"
STORAGE_DNS_LINK="link-blob-$SUFFIX"
KEY_VAULT="kvacarunner$SUFFIX"
KEY_VAULT_PE="pe-kv-$SUFFIX"
KEY_VAULT_DNS_ZONE="privatelink.vaultcore.azure.net"
KEY_VAULT_DNS_LINK="link-kv-$SUFFIX"
GITHUB_APP_KEY_SECRET="github-app-private-key"
PRIVATE_ENDPOINT_CIDR="10.20.1.0/24"
UAMI="id-acarunner-$SUFFIX"

# Module 02에서 Storage 이름 충돌 복구가 있었다면 저장해 둔 실제 값을 덮어씁니다.
read -rp "Saved Storage account name if changed (press Enter to keep ${STORAGE}): " SAVED_STORAGE
if [[ -n "$SAVED_STORAGE" ]]; then
  STORAGE="$SAVED_STORAGE"
fi
unset SAVED_STORAGE

# Module 01에서 Key Vault 이름 충돌 복구가 있었다면 저장해 둔 실제 값을 덮어씁니다.
read -rp "Saved Key Vault name if changed (press Enter to keep ${KEY_VAULT}): " SAVED_KEY_VAULT
if [[ -n "$SAVED_KEY_VAULT" ]]; then
  KEY_VAULT="$SAVED_KEY_VAULT"
fi
unset SAVED_KEY_VAULT

# Azure CLI context를 원래 workshop subscription으로 되돌린 뒤 식별자를 조회합니다.
az account set --subscription "$SUBSCRIPTION_ID"
STORAGE_ID=$(az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --query id \
  --output tsv)
UAMI_PID=$(az identity show \
  --resource-group "$RG" \
  --name "$UAMI" \
  --query principalId \
  --output tsv)
UAMI_CLIENT_ID=$(az identity show \
  --resource-group "$RG" \
  --name "$UAMI" \
  --query clientId \
  --output tsv)
PE_SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$PE_SUBNET" \
  --query id \
  --output tsv)
KEY_VAULT_ID=$(az keyvault show \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --query id \
  --output tsv)
KEY_VAULT_SECRET_URI="https://$KEY_VAULT.vault.azure.net/secrets/$GITHUB_APP_KEY_SECRET"

export SUFFIX LOC RG ENV VNET PE_SUBNET STORAGE STORAGE_CONTAINER STORAGE_PE STORAGE_DNS_ZONE STORAGE_DNS_LINK KEY_VAULT KEY_VAULT_PE KEY_VAULT_DNS_ZONE KEY_VAULT_DNS_LINK GITHUB_APP_KEY_SECRET PRIVATE_ENDPOINT_CIDR ACR UAMI SUBSCRIPTION_ID STORAGE_ID UAMI_PID UAMI_CLIENT_ID PE_SUBNET_ID KEY_VAULT_ID KEY_VAULT_SECRET_URI
printf 'RG=%s\nENV=%s\nSTORAGE=%s\nSTORAGE_CONTAINER=%s\nUAMI=%s\nUAMI_CLIENT_ID=%s\nKEY_VAULT=%s\nPRIVATE_ENDPOINT_CIDR=%s\n' \
  "$RG" "$ENV" "$STORAGE" "$STORAGE_CONTAINER" "$UAMI" "$UAMI_CLIENT_ID" "$KEY_VAULT" "$PRIVATE_ENDPOINT_CIDR"
```

📋 **예상 출력**

- `STORAGE`, `STORAGE_CONTAINER`, `UAMI_CLIENT_ID`, `PRIVATE_ENDPOINT_CIDR`가 비어 있지 않아야 합니다.
- `STORAGE`가 Module 02에서 실제로 만든 Storage account 이름과 같아야 합니다. 이름 충돌 복구를 했다면 저장해 둔 실제 값이 출력되어야 합니다.
- `SUBSCRIPTION_ID`는 현재 Cloud Shell 기본값이 아니라 원래 workshop subscription ID여야 합니다.

⚠️ **주의**

- 새 suffix를 만들지 마세요. 기존 Event Job이 전달하는 `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, `AZURE_PRIVATE_ENDPOINT_CIDR` 계약과 달라집니다.
- Cloud Shell이나 GitHub secret에 Storage key, SAS, client secret을 추가하지 마세요. 이 모듈의 Blob data 명령은 모두 `--auth-mode login`만 사용합니다.
- 이후 control-plane 조회도 모두 방금 복구한 `SUBSCRIPTION_ID` context를 기준으로 실행합니다.

</details>

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 권한, 복구 관련 안내 |

## 1. Storage data-plane 권한과 private endpoint 상태 확인

👁️ **설명**

Module 04의 Event Job은 이미 runner에 `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, `AZURE_PRIVATE_ENDPOINT_CIDR`를 전달합니다. 이 모듈은 그 입력을 그대로 사용해 Blob data-plane proof만 수행합니다. 따라서 여기서 확인할 핵심은 세 가지입니다.

External ACA Job은 ingress를 지원하지 않으며, 이 workflow는 runner에 대한 inbound reachability를 증명하지 않습니다. 대신 private Blob data-plane으로의 outbound access만 증명합니다.

1. runner UAMI가 Storage account 범위의 `Storage Blob Data Contributor`를 가지고 있는지,
2. Storage public access가 막혀 있고 shared-key access가 꺼져 있는지,
3. Blob Private Endpoint와 `privatelink.blob.core.windows.net`이 준비되어 있는지입니다.

🟢 **실행**

```bash
# Storage network rule, shared-key 차단, Private Endpoint 상태를 control-plane에서 미리 확인합니다.
az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --query "{name:name,defaultAction:networkRuleSet.defaultAction,publicNetworkAccess:publicNetworkAccess,allowBlobPublicAccess:allowBlobPublicAccess,allowSharedKeyAccess:allowSharedKeyAccess}" \
  --output table

# Blob Private Endpoint 연결 상태와 private IP를 조회합니다.
az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --query "privateEndpointConnections[].{name:name,status:properties.privateLinkServiceConnectionState.status}" \
  --output table
PRIVATE_IP=$(az network private-dns record-set a show \
  --resource-group "$RG" \
  --zone-name "$STORAGE_DNS_ZONE" \
  --name "$STORAGE" \
  --query "aRecords[0].ipv4Address" \
  --output tsv)

# runner UAMI가 Storage Blob Data Contributor를 정확히 Storage account scope에서 갖는지 확인합니다.
az role assignment list \
  --assignee "$UAMI_PID" \
  --scope "$STORAGE_ID" \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{role:roleDefinitionName,scope:scope}" \
  --output table

printf 'Expected private IP from DNS zone: %s\n' "$PRIVATE_IP"
printf 'Workflow inputs: AZURE_STORAGE_ACCOUNT=%s AZURE_STORAGE_CONTAINER=%s AZURE_PRIVATE_ENDPOINT_CIDR=%s\n' \
  "$STORAGE" "$STORAGE_CONTAINER" "$PRIVATE_ENDPOINT_CIDR"
```

📋 **예상 출력**

- `defaultAction`은 `Deny`여야 합니다.
- `publicNetworkAccess`는 `Enabled`여야 합니다.
- `allowBlobPublicAccess`는 `False`, `allowSharedKeyAccess`는 `False`여야 합니다.
- Private Endpoint connection 상태는 `Approved`여야 합니다.
- role assignment 표에는 `Storage Blob Data Contributor`가 정확히 `$STORAGE_ID` scope로 표시되어야 합니다.
- `Expected private IP from DNS zone:` 값은 이후 workflow에서 보고하는 private IP와 같아야 합니다.

⚠️ **주의**

- 여기서 role이 보이지 않으면 Module 02 foundation이 incomplete한 상태입니다. 범위를 넓히지 말고 Module 02의 Storage scope role assignment 절차를 다시 확인하세요.
- `defaultAction=Deny`와 `allowSharedKeyAccess=False`는 data-plane을 private endpoint + managed identity 경로로 고정하기 위한 조건입니다.

## 2. Private Blob workflow를 GitHub에 생성

👁️ **설명**

이 단계는 reviewed sample을 그대로 GitHub 기본 브랜치 workflow로 반영하는 단계입니다. repository write는 GitHub 브라우저 세션에서만 수행하고, Cloud Shell에는 추가 git push credential을 두지 않습니다. 저장 경로는 반드시 `.github/workflows/aca-runner-private-blob.yml`이어야 하며, 이 파일을 수정할 사람은 `trusted workflow authors`로 제한해야 합니다.

🟢 **실행**

먼저 Cloud Shell에서 checked-in sample을 그대로 출력합니다.

```bash
# checked-in private Blob workflow sample 전체를 Cloud Shell에서 출력합니다.
cd ~/aca-github-runner-workshop
sed -n '1,220p' samples/azure-sample-deploy-workflow.yml
```

이제 GitHub 웹 UI에서 아래 순서로 진행합니다.

1. `.github/workflows/aca-runner-private-blob.yml`이 없으면 **Add file → Create new file**를 선택합니다.
2. 이미 있으면 파일을 연 뒤 **Edit this file**를 선택합니다.
3. 기존 내용을 일부만 수정하지 말고, 방금 Cloud Shell에 출력한 `samples/azure-sample-deploy-workflow.yml` 전체 내용으로 교체합니다.
4. workflow name이 **ACA Runner Private Blob Deploy**인지 확인하고 기본 브랜치에 commit합니다.
5. 이 repository가 `private repository`인지, 그리고 workflow 편집 권한이 `trusted workflow authors`에게만 있는지 다시 확인합니다.

`Validate runner inputs` step은 Azure 변수 확인보다 먼저 `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`가 workflow environment로 전달되지 않았는지 검사합니다. 하나라도 보이면 `ERROR: GitHub App bootstrap variable reached the workflow environment.` prefix와 함께 즉시 실패해야 합니다.

<details>
<summary>aca-runner-private-blob.yml 전체 내용 보기</summary>

```yaml
name: ACA Runner Private Blob Deploy

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deploy-private-blob:
    runs-on: [aca-runner]
    timeout-minutes: 10
    steps:
      - name: Validate runner inputs
        shell: bash
        run: |
          set -euo pipefail
          for variable_name in \
            GITHUB_APP_ID \
            GITHUB_APP_INSTALLATION_ID \
            GITHUB_APP_PRIVATE_KEY; do
            if [[ -n "${!variable_name:-}" ]]; then
              printf 'ERROR: GitHub App bootstrap variable reached the workflow environment: %s\n' \
                "$variable_name" >&2
              exit 1
            fi
          done

          for variable in \
            AZURE_CLIENT_ID \
            AZURE_SUBSCRIPTION_ID \
            AZURE_RESOURCE_GROUP \
            AZURE_STORAGE_ACCOUNT \
            AZURE_STORAGE_CONTAINER \
            AZURE_PRIVATE_ENDPOINT_CIDR; do
            if [[ -z "${!variable:-}" ]]; then
              printf 'ERROR: %s is required.\n' "$variable" >&2
              exit 1
            fi
          done

      - name: Sign in to Azure with managed identity
        shell: bash
        run: |
          set -euo pipefail
          # The runner UAMI needs Storage Blob Data Contributor on the Storage account.
          az login --identity \
            --client-id "$AZURE_CLIENT_ID" \
            --allow-no-subscriptions \
            --output none
          az account set --subscription "$AZURE_SUBSCRIPTION_ID"
          az account show \
            --query "{subscription:name,subscriptionId:id,user:user.name,type:user.type}" \
            --output table

      - name: Verify Blob DNS resolves to the private endpoint subnet
        shell: bash
        run: |
          set -euo pipefail
          # Blob private DNS is provided by privatelink.blob.core.windows.net.
          STORAGE_BLOB_HOSTNAME="${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net"
          mapfile -t RESOLVED_IPS < <(
            getent ahostsv4 "$STORAGE_BLOB_HOSTNAME" |
              awk '{print $1}' |
              sort -u
          )

          if [[ "${#RESOLVED_IPS[@]}" -eq 0 ]]; then
            printf 'ERROR: %s did not resolve to an IPv4 address.\n' "$STORAGE_BLOB_HOSTNAME" >&2
            exit 1
          fi

          PRIVATE_IP="$(python3 -c 'import ipaddress, sys; network = ipaddress.ip_network(sys.argv[1], strict=True); matches = [str(ipaddress.ip_address(value)) for value in sys.argv[2:] if ipaddress.ip_address(value) in network]; print(matches[0]) if matches else sys.exit(1)' "$AZURE_PRIVATE_ENDPOINT_CIDR" "${RESOLVED_IPS[@]}")" || {
            printf 'ERROR: %s resolved outside private endpoint CIDR %s: %s\n' \
              "$STORAGE_BLOB_HOSTNAME" \
              "$AZURE_PRIVATE_ENDPOINT_CIDR" \
              "${RESOLVED_IPS[*]}" >&2
            exit 1
          }

          printf 'STORAGE_BLOB_HOSTNAME=%s\n' "$STORAGE_BLOB_HOSTNAME" >> "$GITHUB_ENV"
          printf 'STORAGE_PRIVATE_IP=%s\n' "$PRIVATE_IP" >> "$GITHUB_ENV"
          printf 'Resolved %s to private IP %s.\n' \
            "$STORAGE_BLOB_HOSTNAME" "$PRIVATE_IP"

      - name: Upload and download the private Blob artifact
        shell: bash
        run: |
          set -euo pipefail
          ARTIFACT_ROOT="${RUNNER_TEMP:-${GITHUB_WORKSPACE:-$PWD}/.runner-temp}"
          ARTIFACT_DIR="$ARTIFACT_ROOT/private-blob-deploy"
          SOURCE_FILE="$ARTIFACT_DIR/source.txt"
          DOWNLOADED_FILE="$ARTIFACT_DIR/downloaded.txt"
          REPOSITORY_VALUE="${GITHUB_REPOSITORY:-unknown/repository}"
          COMMIT_VALUE="${GITHUB_SHA:-unknown-commit}"
          RUN_ID_VALUE="${GITHUB_RUN_ID:-0}"
          RUN_ATTEMPT_VALUE="${GITHUB_RUN_ATTEMPT:-0}"
          ACTOR_VALUE="${GITHUB_ACTOR:-unknown-actor}"
          BLOB_NAME="github-actions/${RUN_ID_VALUE}-${RUN_ATTEMPT_VALUE}.txt"
          mkdir -p "$ARTIFACT_DIR"

          cat > "$SOURCE_FILE" <<EOF
          repository=$REPOSITORY_VALUE
          commit=$COMMIT_VALUE
          run_id=$RUN_ID_VALUE
          run_attempt=$RUN_ATTEMPT_VALUE
          actor=$ACTOR_VALUE
          EOF

          SOURCE_SHA256="$(sha256sum "$SOURCE_FILE" | awk '{print $1}')"

          az storage blob upload \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --container-name "$AZURE_STORAGE_CONTAINER" \
            --name "$BLOB_NAME" \
            --file "$SOURCE_FILE" \
            --metadata sha256="$SOURCE_SHA256" \
            --auth-mode login \
            --overwrite true \
            --output none

          az storage blob download \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --container-name "$AZURE_STORAGE_CONTAINER" \
            --name "$BLOB_NAME" \
            --file "$DOWNLOADED_FILE" \
            --auth-mode login \
            --overwrite true \
            --output none

          DOWNLOADED_SHA256="$(sha256sum "$DOWNLOADED_FILE" | awk '{print $1}')"
          BLOB_SHA256="$(az storage blob show \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --container-name "$AZURE_STORAGE_CONTAINER" \
            --name "$BLOB_NAME" \
            --auth-mode login \
            --query metadata.sha256 \
            --output tsv)"
          if [[ "$DOWNLOADED_SHA256" != "$SOURCE_SHA256" || "$BLOB_SHA256" != "$SOURCE_SHA256" ]]; then
            printf 'ERROR: Downloaded Blob checksum does not match the uploaded artifact.\n' >&2
            printf 'source=%s downloaded=%s blob=%s\n' \
              "$SOURCE_SHA256" "$DOWNLOADED_SHA256" "$BLOB_SHA256" >&2
            exit 1
          fi

          printf 'BLOB_NAME=%s\n' "$BLOB_NAME" >> "$GITHUB_ENV"
          printf 'SOURCE_SHA256=%s\n' "$SOURCE_SHA256" >> "$GITHUB_ENV"
          printf 'DOWNLOADED_SHA256=%s\n' "$DOWNLOADED_SHA256" >> "$GITHUB_ENV"
          printf 'BLOB_SHA256=%s\n' "$BLOB_SHA256" >> "$GITHUB_ENV"

      - name: Show private deployment result
        shell: bash
        run: |
          set -euo pipefail
          az storage blob show \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --container-name "$AZURE_STORAGE_CONTAINER" \
            --name "$BLOB_NAME" \
            --auth-mode login \
            --query "{name:name,size:properties.contentLength,lastModified:properties.lastModified,sha256:metadata.sha256}" \
            --output table
          printf 'Blob endpoint: %s (%s)\n' \
            "$STORAGE_BLOB_HOSTNAME" "$STORAGE_PRIVATE_IP"
          printf 'SHA-256: %s\n' "$SOURCE_SHA256"
```

</details>

📋 **예상 출력**

- GitHub 기본 브랜치의 `.github/workflows/aca-runner-private-blob.yml`이 sample과 byte-for-byte로 같아야 합니다.
- workflow는 single job이며 `runs-on: [aca-runner]`만 사용합니다.
- Blob data 명령에는 모두 `--auth-mode login`이 들어 있어야 합니다.

## 3. GitHub Actions에서 private artifact 배포 실행

👁️ **설명**

이 workflow는 `workflow_dispatch`만 사용하므로 trusted participant가 GitHub UI에서 직접 실행해야 합니다. runner는 Event Job이 만든 ephemeral self-hosted runner이고, Azure 인증은 managed identity login만 사용합니다. 업로드되는 Blob 경로는 `github-actions/<run-id>-<run-attempt>.txt`입니다.

🟢 **실행**

1. GitHub repository에서 **Actions → ACA Runner Private Blob Deploy**로 이동합니다.
2. **Run workflow**를 눌러 기본 브랜치에서 실행합니다.
3. run summary에서 아래 step 이름이 순서대로 성공하는지 확인합니다.
   - `Validate runner inputs`
   - `Sign in to Azure with managed identity`
   - `Verify Blob DNS resolves to the private endpoint subnet`
   - `Upload and download the private Blob artifact`
   - `Show private deployment result`

📋 **예상 출력**

다음 값들은 참가자와 실행 시점마다 달라지므로 placeholder로 비교합니다.

```text
Resolved stacarunner<suffix>.blob.core.windows.net to private IP 10.20.1.4.

Name                                      Size  Last Modified          Sha256
----------------------------------------  ----  ---------------------  ----------------------------------------------------------------
github-actions/<run-id>-<run-attempt>.txt <bytes> <modified-timestamp> <64-hex-sha256>

Blob endpoint: stacarunner<suffix>.blob.core.windows.net (10.20.1.4)
SHA-256: <64-hex-sha256>
```

- `private IP`는 `AZURE_PRIVATE_ENDPOINT_CIDR=10.20.1.0/24` 안에 있어야 합니다.
- Blob name은 반드시 `github-actions/<run-id>-<run-attempt>.txt` 형식이어야 합니다.
- `SHA-256`은 source, downloaded file, blob metadata가 모두 같은 값이어야 합니다.

## 4. Private DNS와 Blob checksum 결과 해석

👁️ **설명**

runner는 `AZURE_STORAGE_ACCOUNT.blob.core.windows.net`를 조회하지만, 실제 이름 해석은 `privatelink.blob.core.windows.net` Private DNS zone을 통해 private IP로 돌아와야 합니다. workflow는 `getent ahostsv4`로 모든 IPv4를 수집한 뒤 Python `ipaddress`로 `AZURE_PRIVATE_ENDPOINT_CIDR` 포함 여부를 검사합니다. shell prefix 비교를 쓰지 않는 이유는 CIDR이 `/24` 외 다른 크기로 바뀌어도 같은 검증을 유지하기 위해서입니다.

같은 step은 Azure 입력값을 보기 전에 `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`의 부재도 확인합니다. 이 검증이 증명하는 범위는 normal child-environment non-inheritance입니다. 즉 runner bootstrap에서 unset한 GitHub App 값이 일반 workflow step까지 자동 상속되지 않음을 보여 줍니다. 반대로 malicious code with access to the Job's managed identity/runtime boundary까지 격리해 준다고 주장하면 안 됩니다.

업로드 artifact 내용에는 run identity가 들어갑니다.

- `repository=$GITHUB_REPOSITORY`
- `commit=$GITHUB_SHA`
- `run_id=$GITHUB_RUN_ID`
- `run_attempt=$GITHUB_RUN_ATTEMPT`
- `actor=$GITHUB_ACTOR`

이 파일은 `az storage blob upload --auth-mode login`으로만 올라가고, 곧바로 `az storage blob download --auth-mode login`으로 다시 받아 `sha256sum`을 비교합니다. workflow는 upload 시점의 SHA-256을 blob metadata에도 저장한 뒤 `az storage blob show --auth-mode login`으로 다시 읽어 local checksum과 일치하는지 확인합니다.

📋 **예상 출력**

- DNS step이 성공했다면 `Resolved ... to private IP ...` 한 줄이 남고, 그 IP는 section 1의 DNS A record와 같아야 합니다.
- checksum이 다르면 workflow는 즉시 실패하며 `ERROR: Downloaded Blob checksum does not match the uploaded artifact.`를 출력해야 합니다.
- shared key 또는 public blob URL 접근 없이 managed identity + Storage Blob Data Contributor만으로 read/write가 끝나야 합니다.

## 5. Cloud Shell과 Azure Portal에서 control-plane 확인

👁️ **설명**

Cloud Shell은 control-plane만 확인합니다. 실제 data-plane private proof는 GitHub Actions runner 안에서만 수행해야 합니다.

🟢 **실행**

```bash
# 1) Storage network rules와 shared-key 차단 상태를 다시 확인합니다.
az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --query "{name:name,defaultAction:networkRuleSet.defaultAction,publicNetworkAccess:publicNetworkAccess,allowBlobPublicAccess:allowBlobPublicAccess,allowSharedKeyAccess:allowSharedKeyAccess}" \
  --output table

# 2) Blob Private Endpoint approval 상태를 확인합니다.
az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --query "privateEndpointConnections[].{name:name,status:properties.privateLinkServiceConnectionState.status,description:properties.privateLinkServiceConnectionState.description}" \
  --output table

# 3) Private DNS A record가 Storage account 이름으로 생성되었는지 확인합니다.
az network private-dns record-set a show \
  --resource-group "$RG" \
  --zone-name "$STORAGE_DNS_ZONE" \
  --name "$STORAGE" \
  --query "{fqdn:fqdn,ipv4:aRecords[0].ipv4Address}" \
  --output table

# 4) runner UAMI role assignment가 Storage scope에 유지되는지 확인합니다.
az role assignment list \
  --assignee "$UAMI_PID" \
  --scope "$STORAGE_ID" \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor'].{role:roleDefinitionName,scope:scope}" \
  --output table
```

Azure Portal에서는 아래 네 위치를 같은 실행 직후에 교차 확인합니다.

1. **Storage account → Networking**: public network access와 firewall 기본 동작이 문서와 같은지 확인
2. **Storage account → Private endpoint connections**: Blob connection이 `Approved`인지 확인
3. **Private DNS zone → privatelink.blob.core.windows.net**: Storage account 이름으로 A record가 있는지 확인
4. **Storage account → Access control (IAM)**: runner UAMI에 `Storage Blob Data Contributor`가 Storage scope로 있는지 확인

📋 **예상 출력**

- Storage network rule 조회는 `defaultAction=Deny`와 `allowSharedKeyAccess=False`를 보여야 합니다.
- `publicNetworkAccess`는 `Enabled`여야 합니다.
- Private Endpoint 상태는 `Approved`여야 합니다.
- DNS A record의 IPv4는 workflow가 보고한 private IP와 같아야 합니다.
- role assignment 표에는 `Storage Blob Data Contributor` 한 줄이 보여야 합니다.

## 트러블슈팅

### DNS

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| DNS step이 `resolved outside private endpoint CIDR`로 실패함 | runner가 받은 이름 해석 결과에 `AZURE_PRIVATE_ENDPOINT_CIDR` 안의 IPv4가 없음 | Module 02의 `privatelink.blob.core.windows.net` zone, VNet link, Private Endpoint DNS zone group, A record를 다시 확인하고 section 5의 DNS A record 조회를 재실행합니다. |
| `did not resolve to an IPv4 address`가 발생함 | Private DNS record가 아직 없거나 잘못된 Storage account 이름을 사용함 | `AZURE_STORAGE_ACCOUNT` 값과 `az network private-dns record-set a show` 결과가 같은지 확인하고, 이름 충돌 복구가 있었다면 saved Storage name으로 다시 실행합니다. |

### 네트워크/방화벽

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `az storage blob upload` 또는 `az storage blob download`가 403/timeout으로 실패함 | Storage firewall/Private Endpoint 구성 불일치 또는 DNS가 public path를 가리킴 | `defaultAction=Deny`, Private Endpoint `Approved`, DNS A record의 private IP를 함께 다시 확인합니다. Blob data-plane 명령은 모두 `--auth-mode login`으로 유지하고 shared key를 추가하지 마세요. |
| workflow가 오래 대기하다가 실패함 | Event Job runner가 뜨지 않았거나 stale workflow가 queue를 잡고 있음 | Module 04~05의 Event Job/KEDA 검증을 다시 확인하고, 같은 `aca-runner` label을 쓰는 오래된 queued run을 취소한 뒤 다시 실행합니다. |

### RBAC

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `AuthorizationPermissionMismatch` 또는 `AuthorizationFailure`가 발생함 | runner UAMI에 Storage scope의 `Storage Blob Data Contributor`가 없거나 아직 전파되지 않음 | section 1과 section 5의 role assignment 조회를 다시 실행합니다. scope를 Resource Group으로 넓히지 말고 Storage account scope assignment만 복구한 뒤 1~5분 기다리고 재시도합니다. |
| checksum step 전까지는 성공하지만 blob show가 실패함 | upload/download는 캐시되었지만 metadata 조회 권한 전파가 늦음 | 같은 role assignment가 보이는지 확인하고 잠시 기다린 뒤 workflow를 다시 실행합니다. |

### Public outbound

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `az login` 또는 `az account show` 전에 workflow가 실패함 | runner의 public outbound에서 Azure identity 또는 ARM으로 나가지 못함 | 이 워크숍은 Blob data-plane만 private path를 사용합니다. GitHub, ARM, Entra ID, Azure Monitor와 Basic ACR은 public outbound를 사용하므로 custom NSG/UDR/Firewall 정책이 이 대상들을 막지 않는지 확인합니다. |
| runner가 GitHub queue를 처리하지 못함 | GitHub API outbound 또는 PAT approval 문제 | Module 04~05의 GitHub scaler/PAT troubleshooting을 먼저 따라간 뒤, 이후 다시 private Blob workflow를 실행합니다. |

---

[← 이전: 병렬 실행과 스케일 검증](05-parallel-scale-validation.md)
[다음: 보안·제약·정리 →](07-security-limitations-cleanup.md)

Module 06은 필수 단계입니다. 위 링크로 이동해 private Blob 배포와 결과 확인을 계속 진행하세요.
