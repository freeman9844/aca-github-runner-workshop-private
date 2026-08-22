# 04. Event Job + KEDA 구성

> Azure Cloud Shell Bash에서 ACR image, GitHub App 식별자, Key Vault private key secret, User-Assigned Managed Identity, KEDA `github-runner` scaler를 연결해 repository-scoped Azure Container Apps Event Job을 배포합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- `github-actions-runner` container를 사용하는 ACA Event Job을 만든다.
- User-Assigned Managed Identity와 Storage 입력 변수를 runner container에 전달한다.
- GitHub repository, GitHub App 식별자, Key Vault secret reference를 KEDA `github-runner` scaler와 runner env에 연결한다.
- scaler의 execution/scale/auth/metadata 값을 이해한다.
- secret 값을 노출하지 않고 Job 설정과 초기 상태를 검증한다.
- Cloud Shell 세션을 재연결한 경우에만 선택적 복구 절차로 Azure 변수와 GitHub 입력을 다시 구성한다.

## 워크숍 네트워크 전제

👁️ **설명**

Task 2에서 만든 foundation은 custom VNet에 붙은 **External ACA Environment**입니다. Storage와 Key Vault의 표준 public endpoint와 DNS 이름은 유지됩니다. ACA delegated
subnet의 `Microsoft.Storage`·`Microsoft.KeyVault` service endpoint가 Azure backbone
경로와 subnet identity를 제공하고, 각 resource firewall은 ACA subnet rule만 허용합니다.

따라서 워크숍 runner와 KEDA는 public outbound로 GitHub API, ACR, Azure identity, ARM, Azure Monitor에 도달해야 합니다. service endpoint DNS 조회 결과는 public service IP가 정상이며 private IP인지 검증하면 안 됩니다. ACA Event Job은 ingress를 지원하지 않으므로 External ACA Environment에서도 runner Job에 public inbound endpoint가 생기지 않습니다. In other words, Jobs do not support ingress.

이 워크숍에는 ACR Private Endpoint, UDR, NSG, Azure Firewall, forced tunneling, NAT Gateway가 포함되지 않으며 모두 production extension입니다. 이 항목들은 production에서 필요 시 별도로 설계하는 out-of-scope extension입니다.

⚠️ **주의**

조직 정책 때문에 custom network policy를 나중에 붙인다면 위 public outbound 대상이 막히지 않는지 먼저 확인하세요. 이 모듈의 명령은 External ACA Environment 자체만으로 outbound를 차단하지 않는다는 전제를 사용합니다.

> ⚠️ **운영자 delivery gate**
> Key Vault `keyvaultref:`가 ACA subnet service endpoint를 통해 resolve되는 경로는 Microsoft 문서화가 제한적입니다.
> Module 04 Key Vault reference synchronization/execution 성공이 acceptance gate입니다.
> workshop delivery 전에 같은 구독·정책 경계에서 live rehearsal로 직접 성공을 확인하세요.
> 이 경로는 저장소 테스트만으로 증명할 수 없습니다.

## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

### Azure 리소스 변수

👁️ **설명**

이 모듈은 모듈 02와 03의 출력값을 모두 사용합니다. Cloud Shell을 다시 열었다면 Module 01에서 저장한 `SUFFIX`와 실제 `KEY_VAULT`, Module 02에서 저장한 실제 `ACR` 이름을 기준으로 Azure 리소스 이름과 조회형 변수들을 다시 채웁니다. `ACR`과 `STORAGE`는 이름 충돌 복구가 있었다면 `SUFFIX`에서 유도되지 않는 별도 값이므로, Module 02에서 저장해 둔 실제 값을 그대로 입력하세요.

🟢 **실행**

```bash
# 저장한 Azure 식별자를 입력해 기존 Environment, ACR, Storage, UAMI와 Job 이름을 복원합니다.
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved ACR name: " ACR

# suffix 기반 이름과 service endpoint foundation 값을 다시 구성합니다.
LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
LOG="log-acarunner-$SUFFIX"
ENV="env-acarunner-$SUFFIX"
VNET="vnet-acarunner-$SUFFIX"
INFRA_SUBNET="snet-aca-infra"
STORAGE="stacarunner$SUFFIX"
STORAGE_CONTAINER="runner-artifacts"
KEY_VAULT="kvacarunner$SUFFIX"
GITHUB_APP_KEY_SECRET="github-app-private-key"
UAMI="id-acarunner-$SUFFIX"
JOB="job-ghrunner-$SUFFIX"
IMAGE="github-actions-runner:2.336.0"

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

# Job 생성에 필요한 workspace, Environment, ACR, Storage, subscription과 identity ID를 다시 조회합니다.
LOG_ID=$(az monitor log-analytics workspace show   --resource-group "$RG"   --workspace-name "$LOG"   --query customerId   --output tsv)
LOG_RID=$(az monitor log-analytics workspace show   --resource-group "$RG"   --workspace-name "$LOG"   --query id   --output tsv)
ENV_ID=$(az containerapp env show   --resource-group "$RG"   --name "$ENV"   --query id   --output tsv)
VNET_ID=$(az network vnet show   --resource-group "$RG"   --name "$VNET"   --query id   --output tsv)
SUBNET_ID=$(az network vnet subnet show   --resource-group "$RG"   --vnet-name "$VNET"   --name "$INFRA_SUBNET"   --query id   --output tsv)
STORAGE_ID=$(az storage account show   --resource-group "$RG"   --name "$STORAGE"   --query id   --output tsv)
ACR_SERVER=$(az acr show --name "$ACR" --query loginServer --output tsv)
ACR_ID=$(az acr show --name "$ACR" --query id --output tsv)
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
RG_ID=$(az group show   --name "$RG"   --query id   --output tsv)
UAMI_RID=$(az identity show   --resource-group "$RG"   --name "$UAMI"   --query id   --output tsv)
UAMI_PID=$(az identity show   --resource-group "$RG"   --name "$UAMI"   --query principalId   --output tsv)
UAMI_CLIENT_ID=$(az identity show   --resource-group "$RG"   --name "$UAMI"   --query clientId   --output tsv)
KEY_VAULT_ID=$(az keyvault show \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --query id \
  --output tsv)
KEY_VAULT_SECRET_URI="https://$KEY_VAULT.vault.azure.net/secrets/$GITHUB_APP_KEY_SECRET"

# 복구한 Azure 변수를 현재 shell에 export하고 핵심 값을 출력해 확인합니다.
export SUFFIX LOC RG LOG ENV VNET INFRA_SUBNET STORAGE STORAGE_CONTAINER KEY_VAULT GITHUB_APP_KEY_SECRET ACR UAMI JOB IMAGE LOG_ID LOG_RID ENV_ID VNET_ID SUBNET_ID STORAGE_ID ACR_SERVER ACR_ID SUBSCRIPTION_ID RG_ID UAMI_RID UAMI_PID UAMI_CLIENT_ID KEY_VAULT_ID KEY_VAULT_SECRET_URI
printf 'JOB=%s ENV=%s STORAGE=%s ACR_SERVER=%s KEY_VAULT=%s\n' "$JOB" "$ENV" "$STORAGE" "$ACR_SERVER" "$KEY_VAULT"
```

📋 **예상 출력**

```text
JOB=job-ghrunner-a1b2c3 ENV=env-acarunner-a1b2c3 STORAGE=stacarunnera1b2c3 ACR_SERVER=acracarunnera1b2c3.azurecr.io KEY_VAULT=kvacarunnera1b2c3
```

`ACR_SERVER`는 입력한 `ACR` 값을 그대로 조회한 결과이므로, 모듈 02에서 이름 충돌 복구를 했다면 다른 registry 이름으로 출력되어야 정상입니다. `STORAGE` 역시 이름 충돌 복구가 있었다면 저장해 둔 실제 값으로 복원되어야 합니다.

### GitHub 인증 변수

👁️ **설명**

Cloud Shell 세션이 재시작되면 GitHub owner/repository와 GitHub App 식별자도 사라집니다. 하지만 private key PEM 자체는 다시 입력하지 않습니다. Module 01에서 만든 Key Vault와 Module 02에서 완성한 service endpoint foundation, `GITHUB_APP_KEY_SECRET`, `KEY_VAULT_SECRET_URI`, `UAMI_RID`를 그대로 사용합니다. 이 모듈에서는 KEDA와 runner bootstrap이 사용할 non-secret 식별자만 복원합니다.

🟢 **실행**

```bash
# KEDA와 runner bootstrap이 사용할 GitHub App 식별자를 복원합니다.
read -rp "GitHub organization: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rp "GitHub App ID: " GITHUB_APP_ID
read -rp "GitHub App Installation ID: " GITHUB_APP_INSTALLATION_ID
```

📋 **예상 출력**

- 프롬프트는 organization, repository, GitHub App ID, GitHub App Installation ID를 순서대로 요청합니다.
- private key PEM은 다시 묻지 않습니다. scaler와 runner는 `github-app-private-key=keyvaultref:$KEY_VAULT_SECRET_URI,identityref:$UAMI_RID` reference로 같은 Key Vault secret을 사용합니다.

</details>

## 1. 기존 Job과 중복 queue watcher 확인

👁️ **설명**

같은 GitHub repository와 `aca-runner` label을 감시하는 이전 Event Job이 남아
있으면, 새 Job과 동시에 runner를 만들고 queued workflow를 먼저 가져갈 수
있습니다. 그러면 새 execution은 Job을 받지 못한 채 대기하다가
`--replica-timeout 900`에 도달해 `Failed`로 끝날 수 있습니다.

먼저 현재 구독의 Container Apps Job 중 동일한 repository와 label을 감시하는
Job을 찾습니다.

🟢 **실행**

```bash
# 같은 repository와 label을 감시하는 기존 Event Job을 찾아 queue 경쟁을 예방합니다.
az containerapp job list \
  --query "[?properties.configuration.eventTriggerConfig.scale.rules[?metadata.owner=='$GITHUB_OWNER' && metadata.repos=='$GITHUB_REPO' && metadata.labels=='aca-runner']].{Name:name,ResourceGroup:resourceGroup}" \
  --output table
```

📋 **예상 출력**

- 처음 실습하는 repository라면 행이 없어야 합니다.
- 다른 이름 또는 다른 Resource Group의 Job이 보이면 **여기서 중단**합니다.
  동일한 repository와 label을 감시하는 이전 Job을 정리하거나, 새 private
  lab repository를 준비한 뒤 진행하세요.

같은 `$RG`에 현재 `$JOB`이 이미 있다면 새로 만들기 전에 이 워크숍 Job만
삭제합니다.

```bash
if az containerapp job show --name "$JOB" --resource-group "$RG" --output none 2>/dev/null; then
  az containerapp job delete \
    --name "$JOB" \
    --resource-group "$RG" \
    --yes
fi
```

⚠️ **주의**

Job 설정 오류를 복구할 때는 Resource Group 전체를 다시 만들지 말고 이 워크숍 Job만 삭제 후 재생성합니다.

## 2. ACA Event Job 생성

👁️ **설명**

이 워크숍은 queued workflow가 생겼을 때만 runner를 띄우는 Event Job을 사용합니다. runner container 이름은 문서, 검증, 로그 해석을 통일하기 위해 반드시 `github-actions-runner`로 고정합니다. 아래 `AZURE_*` 값은 Azure 리소스를 식별하는 환경 변수이며 credential이 아닙니다. 실제 인증은 workflow가 실행 중 managed-identity endpoint에서 short-lived Azure token을 받아 처리합니다. 이 단계의 image pull과 scaler polling은 workshop의 public outbound 경로를 그대로 사용하고, Blob artifact 경로에는 `AZURE_STORAGE_ACCOUNT=$STORAGE`, `AZURE_STORAGE_CONTAINER=$STORAGE_CONTAINER`를 전달해 Module 06 workflow 입력값을 고정합니다. GitHub queue polling과 runner registration은 PAT 대신 GitHub App ID, Installation ID, Key Vault secret reference를 공유합니다.

🟢 **실행**

```bash
# Event Job의 container, KEDA scaler, secret, identity와 resource 설정을 하나의 인자 배열로 구성합니다.
JOB_CREATE_ARGS=(
  # Job 이름과 배포할 Resource Group, Container Apps Environment를 지정합니다.
  --name "$JOB"
  --resource-group "$RG"
  --environment "$ENV"

  # schedule이 아니라 queued workflow 이벤트를 감시하는 Event Job을 만듭니다.
  --trigger-type Event

  # runner는 최대 900초 실행하며, 실패 시 ACA가 replica를 자동 재시도하지 않습니다.
  --replica-timeout 900
  --replica-retry-limit 0

  # replica 1개가 완료되면 execution을 완료하고, execution마다 runner 1개만 실행합니다.
  --replica-completion-count 1
  --parallelism 1

  # 로그와 상태에서 확인할 container 이름과 모듈 03에서 만든 ACR image를 지정합니다.
  --container-name github-actions-runner
  --image "$ACR_SERVER/$IMAGE"

  # queue가 비어 있으면 execution을 0개로 유지합니다.
  --min-executions 0

  # 동시에 최대 5개 execution까지 scale-out하고 GitHub queue를 30초마다 확인합니다.
  --max-executions 5
  --polling-interval 30

  # GitHub Actions queue 전용 KEDA scaler와 식별 이름을 지정합니다.
  --scale-rule-name github-runner
  --scale-rule-type github-runner

  # GitHub.com API에서 지정한 private repository와 aca-runner custom label만 감시합니다.
  --scale-rule-metadata \
  "githubApiURL=https://api.github.com"
  "owner=$GITHUB_OWNER"
  "runnerScope=repo"
  "repos=$GITHUB_REPO"
  "labels=aca-runner"
  "noDefaultLabels=true"

  # queued workflow job 1개당 execution 1개가 필요하다고 계산합니다.
  "targetWorkflowQueueLength=1"
  "applicationID=$GITHUB_APP_ID"
  "installationID=$GITHUB_APP_INSTALLATION_ID"

  # scaler와 runner bootstrap은 Key Vault의 GitHub App private key secret을 함께 사용합니다.
  --scale-rule-auth "appKey=github-app-private-key"
  --secrets \
  "github-app-private-key=keyvaultref:$KEY_VAULT_SECRET_URI,identityref:$UAMI_RID"

  # entrypoint는 같은 private key로 GitHub App JWT와 runner registration token을 발급합니다.
  --env-vars
  "GITHUB_APP_ID=$GITHUB_APP_ID"
  "GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID"
  "GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key"
  "AZURE_CLIENT_ID=$UAMI_CLIENT_ID"
  "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
  "AZURE_RESOURCE_GROUP=$RG"
  "AZURE_CONTAINERAPPS_ENVIRONMENT=$ENV"
  "AZURE_STORAGE_ACCOUNT=$STORAGE"
  "AZURE_STORAGE_CONTAINER=$STORAGE_CONTAINER"
  "GH_URL=https://github.com/$GITHUB_OWNER/$GITHUB_REPO"
  "RUNNER_LABELS=aca-runner"
  "RUNNER_NAME_PREFIX=aca"

  # Job에 UAMI를 연결하고 같은 identity의 AcrPull 권한으로 ACR image를 가져옵니다.
  --registry-server "$ACR_SERVER"
  --mi-user-assigned "$UAMI_RID"
  --registry-identity "$UAMI_RID"

  # execution 하나가 사용할 고정 CPU와 memory 크기입니다.
  --cpu 2.0
  --memory 4Gi

  # 성공 시 별도 JSON을 출력하지 않습니다.
  --output none
)

# 검토한 인자 배열로 Event Job을 만들고 GitHub App 설정이 저장됐는지 확인합니다.
az containerapp job create "${JOB_CREATE_ARGS[@]}"
unset JOB_CREATE_ARGS
```

📋 **예상 출력**

- 명령은 `--output none` 때문에 정상 시 별도 JSON 없이 종료됩니다.
- 실패 없이 반환되면 Event Job 정의가 저장된 것입니다. 실제 execution은 workflow가 queued 되기 전까지 생성되지 않을 수 있습니다.

🟢 **실행**

배포 직후 Job configuration과 초기 execution 상태를 같은 흐름에서 확인합니다. `job show`는 Key Vault에서 resolve된 secret 값을 조회하지 않으므로 PEM이 다시 출력되지 않습니다. 대신 scaler auth가 `appKey -> github-app-private-key`로 연결됐는지와 GitHub App metadata가 의도한 값인지 확인합니다.

```bash
# 생성된 Job의 trigger, timeout, scale rule과 image가 의도한 값인지 확인합니다.
az containerapp job show \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "{
    triggerType:properties.configuration.triggerType,
    replicaTimeout:properties.configuration.replicaTimeout,
    minExecutions:properties.configuration.eventTriggerConfig.scale.minExecutions,
    maxExecutions:properties.configuration.eventTriggerConfig.scale.maxExecutions,
    pollingInterval:properties.configuration.eventTriggerConfig.scale.pollingInterval,
    rules:properties.configuration.eventTriggerConfig.scale.rules,
    image:properties.template.containers[0].image
  }" \
  --output yaml

# workflow queue 전이므로 초기 execution이 없거나 0개인 정상 상태를 확인합니다.
az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --output table
```

📋 **예상 출력**

`az containerapp job show` 결과는 다음과 같은 형식으로 출력됩니다.

```yaml
image: acracarunner09fa08.azurecr.io/github-actions-runner:2.336.0
maxExecutions: 5
minExecutions: 0
pollingInterval: 30
replicaTimeout: 900
rules:
- auth:
  - secretRef: github-app-private-key
    triggerParameter: appKey
  metadata:
    applicationID: '12345'
    githubApiURL: https://api.github.com
    installationID: '67890'
    labels: aca-runner
    noDefaultLabels: 'true'
    owner: freeman9844
    repos: aca-runner-lab
    runnerScope: repo
    targetWorkflowQueueLength: '1'
  name: github-runner
  type: github-runner
triggerType: Event
```

`image`의 ACR 이름과 `metadata.owner`, `metadata.repos`, `metadata.applicationID`, `metadata.installationID`는 참가자가 만든 리소스와 GitHub 입력값에 따라 달라집니다. `auth.secretRef`는 `github-app-private-key`, `auth.triggerParameter`는 `appKey`여야 하며 나머지 값도 위 예시와 일치해야 합니다.

`az containerapp job execution list`는 workflow를 아직 queue에 넣지 않았다면 실제 테스트처럼 아무 행도 출력되지 않을 수 있습니다. **배포 직후 active execution이 없는 것이 정상**입니다.

참고로 Azure Portal 관리 콘솔에서 해당 Resource Group의 **Overview**를 열면 `job-ghrunner-<suffix>` 리소스가 **Container App Job** 유형으로 생성된 것을 확인할 수 있습니다.

![Azure Portal에서 생성된 Container Apps Job 확인](images/04-azure-portal-container-app-job.png)

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| workflow가 계속 queued이고 execution이 안 생김 | KEDA queue polling 단계에서 App이 해당 repository에 설치되지 않았거나 scaler metadata/auth 매핑이 틀림 | GitHub App이 선택한 `aca-runner-lab` repository에 실제로 설치되어 있는지 확인하고, `az containerapp job show --name "$JOB" --resource-group "$RG" --query "properties.configuration.eventTriggerConfig.scale.rules"`에서 `githubApiURL=https://api.github.com`, `owner`, `runnerScope=repo`, `repos=$GITHUB_REPO`, `labels=aca-runner`, `noDefaultLabels=true`, `targetWorkflowQueueLength=1`, `applicationID`, `installationID`, `appKey -> github-app-private-key`가 모두 정확한지 다시 확인합니다. |
| GitHub API에서 403이 나오고 execution이 생기지 않음 | App 권한을 바꾼 뒤 installation approval이 아직 갱신되지 않았음 | GitHub App 설정에서 필요한 권한 변경 후 organization 또는 repository owner가 installation approval을 다시 완료했는지 확인합니다. approval 전에는 scaler가 queue를 읽지 못합니다. |
| `job show`의 rule은 보이는데 scale이 안 됨 | 잘못된 App ID 또는 Installation ID | 모듈 01에서 확인한 `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`를 다시 대조하고, App settings 화면과 `/settings/installations/` URL의 숫자가 문서 입력과 일치하는지 확인한 뒤 Job을 다시 만듭니다. |
| execution은 생겼는데 GitHub job이 runner를 못 잡음 | workflow label과 runner label 불일치 | workflow의 `runs-on`에 `aca-runner`가 들어 있는지, Job env가 `RUNNER_LABELS=aca-runner`인지 동시에 확인합니다. |
| workflow는 성공했지만 현재 execution이 900초 뒤 `Failed`가 됨 | 다른 Event Job이 동일한 repository와 `aca-runner` label을 감시하며 workflow Job을 먼저 가져감 | 1단계의 `az containerapp job list` query를 다시 실행합니다. 다른 Job이 보이면 해당 이전 실습 Job을 정리하거나 새 lab repository를 사용한 뒤 현재 Job을 다시 만듭니다. |
| execution이 바로 실패하며 image pull 오류가 남 | UAMI의 `AcrPull` 전파 지연 또는 registry identity 설정 누락 | `az role assignment list --assignee "$UAMI_PID" --scope "$ACR_ID" --query "[].roleDefinitionName" --output tsv`로 `AcrPull`을 확인하고, Job 정의에 `--mi-user-assigned "$UAMI_RID"`와 `--registry-identity "$UAMI_RID"`가 모두 들어갔는지 다시 봅니다. |
| execution이 곧바로 인증 오류로 끝남 | runner registration 단계에서 private key PEM이 손상되었거나 disabled/deleted key를 참조함 | `github-app-private-key` secret이 현재 GitHub App의 활성 private key와 일치하는지 확인합니다. PEM을 새 secret version으로 다시 저장했다면 이 워크숍 Job만 삭제 후 재생성해 Key Vault reference를 새 값으로 다시 resolve합니다. |
| execution 시작 직후 Key Vault reference 오류가 남거나 secret을 읽지 못함 | UAMI의 Key Vault secret get 권한, subnet rule, 또는 Key Vault reference authorization 문제 | `identityref:$UAMI_RID`가 현재 Job에 연결되어 있는지, UAMI에 `Key Vault Secrets User`가 `$KEY_VAULT_ID` scope로 부여되어 있는지, `snet-aca-infra`에 `Microsoft.KeyVault` service endpoint가 있는지, Key Vault에 `$SUBNET_ID` subnet rule이 있는지, `publicNetworkAccess=Enabled`, `defaultAction=Deny`, `bypass=None`, `KEY_VAULT_SECRET_URI`가 모두 맞는지 순서대로 다시 확인합니다. Module 02의 `Microsoft.KeyVault` service endpoint, Key Vault ACA subnet rule, `defaultAction=Deny`, `bypass=None`, `Key Vault Secrets User` foundation도 함께 대조하세요. 모든 identity/service endpoint/subnet rule/firewall 점검이 통과했는데도 reference synchronization이 실패하면 워크숍 delivery를 중단하고 환경별 platform path를 조사하세요. `defaultAction=Deny`를 완화하거나 성공처럼 보이는 fallback을 추가하지 마세요. |
| execution은 생기지만 registration token 발급 또는 runner 등록에서 401/404가 남 | GitHub App queue polling은 성공했지만 runner bootstrap이 repository registration 단계에서 실패함 | `az containerapp job execution list --name "$JOB" --resource-group "$RG" --output table`로 execution 생성 여부를 먼저 확인해 KEDA polling 성공 여부를 분리하고, 그 뒤 execution log에서 runner registration API 오류를 확인합니다. 이 경우 `GH_URL`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY` env 연결을 다시 검토합니다. |
| `unrecognized arguments` 또는 help와 문서가 다름 | Cloud Shell의 containerapp extension 버전이 워크숍 기준과 다름 | 모듈 01의 `az extension add --name containerapp --upgrade --version 0.3.55 --only-show-errors`를 다시 실행하고 `az version`으로 버전을 확인한 뒤 명령을 재시도합니다. |
| 사용자 지정 NSG/UDR/Firewall 적용 후 execution이 생성되지 않거나 image pull/log 조회가 동시에 실패함 | GitHub API, ACR, Azure identity, ARM, Azure Monitor로 가는 public outbound가 차단됨 | 워크숍 기본값은 outbound를 열어 둔 External ACA Environment입니다. 조직 정책으로 NSG, UDR, Azure Firewall, forced tunneling, ACR Private Endpoint를 추가했다면 GitHub API, ACR, Azure identity, ARM, Azure Monitor 대상이 허용되는지 먼저 검증하고 다시 시도합니다. |

---

[← 이전: Runner image 빌드](03-runner-image.md) | [다음: 병렬 실행과 스케일 검증 →](05-parallel-scale-validation.md)
