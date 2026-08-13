# 02. Azure 기반 리소스 준비

> Azure Cloud Shell Bash에서 리소스 그룹, Log Analytics workspace, Azure Container Apps environment, Azure Monitor diagnostic settings, Azure Container Registry, User-Assigned Managed Identity를 만들고 `AcrPull` RBAC를 연결합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- `koreacentral`에 실습용 리소스 그룹과 공통 이름 변수를 만든다.
- Log Analytics와 ACA environment를 Azure Monitor 로그 대상으로 연결한다.
- ACR을 관리자 계정 없이 만들고 ARM authentication을 활성화한다.
- UAMI를 만들고 ACR 범위에 `AcrPull` 역할을 부여한다.
- 다음 모듈에서 사용할 `LOG_ID`, `LOG_RID`, `ENV_ID`, `ACR_SERVER`, `ACR_ID`, `UAMI_RID`, `UAMI_PID`를 확보한다.
- 다음 모듈 재접속에 대비해 `SUFFIX`와 실제 `ACR` 이름을 각각 별도 값으로 저장해 둔다.

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## 1. 공통 변수 재설정

👁️ **설명**

각 참가자가 충돌 없이 리소스를 만들 수 있도록 6자리 소문자 16진수 `SUFFIX`를 붙입니다. `ACR` 이름은 전역 고유해야 하므로 이 블록을 그대로 사용하세요. `RG`, `LOG`, `ENV`, `UAMI`, `JOB`은 항상 `SUFFIX`에서 그대로 유도되지만, `ACR`은 이름 충돌 복구가 일어나면 `SUFFIX`와 별개의 값으로 바뀔 수 있는 **독립적인 실습 값**입니다. 따라서 `SUFFIX`뿐 아니라 실제 `ACR` 이름도 반드시 별도로 적어 두세요.

🟢 **실행**

```bash
SUFFIX="$(openssl rand -hex 3)"
LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
LOG="log-acarunner-$SUFFIX"
ENV="env-acarunner-$SUFFIX"
ACR="acracarunner$SUFFIX"
UAMI="id-acarunner-$SUFFIX"
JOB="job-ghrunner-$SUFFIX"
IMAGE="github-actions-runner:2.336.0"
printf 'SUFFIX=%s RG=%s ACR=%s\n' "$SUFFIX" "$RG" "$ACR"
```

📋 **예상 출력**

```text
SUFFIX=a1b2c3 RG=rg-acarunner-a1b2c3 ACR=acracarunnera1b2c3
```

⚠️ **주의**

`SUFFIX`와 함께 위 출력의 `ACR` 값을 지금 별도로 저장하세요. 모듈 03과 04를 Cloud Shell 재접속 후 진행한다면 두 값을 각각 다시 입력해야 합니다.

## 2. Resource group과 Log Analytics workspace 만들기

👁️ **설명**

Log Analytics는 runner 등록/실행/정리 로그를 한곳에서 확인하는 기준이 됩니다. `LOG_ID`는 workspace customer ID이고, `LOG_RID`는 Azure Monitor diagnostic setting에서 사용할 resource ID입니다.

🟢 **실행**

```bash
az group create --name "$RG" --location "$LOC" --output none

az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "$LOG" \
  --location "$LOC" \
  --output none

LOG_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RG" \
  --workspace-name "$LOG" \
  --query customerId \
  --output tsv)
LOG_RID=$(az monitor log-analytics workspace show \
  --resource-group "$RG" \
  --workspace-name "$LOG" \
  --query id \
  --output tsv)
```

📋 **예상 출력**

- 명령은 출력 없이 끝나고, `LOG_ID`와 `LOG_RID`가 셸 변수에 저장됩니다.
- `LOG_RID`는 `/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/...` 형식입니다.

## 3. ACA environment와 Azure Monitor 로그 연결

👁️ **설명**

이 워크숍은 Log Analytics Shared Key를 쓰지 않고, ACA environment 자체를 Azure Monitor에 연결한 뒤 resource-based diagnostic setting으로 로그를 보냅니다.

🟢 **실행**

```bash
az containerapp env create \
  --resource-group "$RG" \
  --name "$ENV" \
  --location "$LOC" \
  --logs-destination azure-monitor \
  --output none

ENV_ID=$(az containerapp env show \
  --resource-group "$RG" \
  --name "$ENV" \
  --query id \
  --output tsv)

az monitor diagnostic-settings create \
  --name aca-runner-logs \
  --resource "$ENV_ID" \
  --workspace "$LOG_RID" \
  --logs '[{"categoryGroup":"allLogs","enabled":true}]' \
  --output none
```

📋 **예상 출력**

- `ENV_ID`가 ACA environment의 전체 resource ID로 저장됩니다.
- diagnostic setting은 `aca-runner-logs` 이름으로 생성되고 `"categoryGroup":"allLogs"`가 포함됩니다.

## 4. ACR 만들기와 ARM authentication 활성화

👁️ **설명**

runner image는 ACR에 저장하고, Job은 관리자 계정이 아니라 UAMI + RBAC로 이미지를 pull합니다. 따라서 `--admin-enabled false`를 유지하고 ARM authentication을 켭니다.

🟢 **실행**

```bash
az acr create \
  --resource-group "$RG" \
  --name "$ACR" \
  --location "$LOC" \
  --sku Basic \
  --admin-enabled false \
  --output none

az acr config authentication-as-arm update \
  --registry "$ACR" \
  --status enabled \
  --output none

ACR_SERVER=$(az acr show --name "$ACR" --query loginServer --output tsv)
ACR_ID=$(az acr show --name "$ACR" --query id --output tsv)
```

📋 **예상 출력**

- `ACR_SERVER`는 `<registry>.azurecr.io` 형식입니다.
- ACR 설정 검증 시 `adminUserEnabled`는 `false`여야 합니다.

## 5. UAMI 만들기와 `AcrPull` RBAC 연결

👁️ **설명**

Azure Container Apps Job은 이 UAMI를 통해 ACR 이미지를 pull합니다. `UAMI_RID`는 Job identity 연결에, `UAMI_PID`는 RBAC 할당과 조회에 사용합니다.

🟢 **실행**

```bash
az identity create \
  --resource-group "$RG" \
  --name "$UAMI" \
  --output none

UAMI_RID=$(az identity show \
  --resource-group "$RG" \
  --name "$UAMI" \
  --query id \
  --output tsv)
UAMI_PID=$(az identity show \
  --resource-group "$RG" \
  --name "$UAMI" \
  --query principalId \
  --output tsv)
```

⚠️ **주의**

Contributor만으로는 Azure RBAC 역할을 할당할 수 없습니다. 아래 `az role assignment create`를 실행하려면 ACR 범위 이상에서 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. 일반적으로 `Role Based Access Control Administrator`, `User Access Administrator`, `Owner` 중 하나가 해당합니다.

```bash
az role assignment create \
  --assignee-object-id "$UAMI_PID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID" \
  --output none
```

📋 **예상 출력**

- `UAMI_RID`는 `/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/...` 형식입니다.
- `UAMI_PID`는 GUID 형식입니다.
- `AcrPull` 역할 할당은 성공 후 별도 출력 없이 종료될 수 있습니다.

⚠️ **주의**

RBAC 전파에는 몇 분이 걸릴 수 있습니다. 다음 모듈에서 image pull 관련 오류가 보이면 즉시 다시 만들지 말고 역할 할당 조회를 먼저 확인하세요.

## 6. 검증

🟢 **실행**

리소스 목록을 먼저 확인합니다.

```bash
az resource list \
  --resource-group "$RG" \
  --query "[].{name:name,type:type,location:location}" \
  --output table
```

ACA environment diagnostic setting을 확인합니다.

```bash
az monitor diagnostic-settings show \
  --name aca-runner-logs \
  --resource "$ENV_ID" \
  --query "{name:name,workspaceId:workspaceId,logs:logs}" \
  --output json
```

ACR의 관리자 계정과 로그인 서버를 확인합니다.

```bash
az acr show \
  --name "$ACR" \
  --query "{loginServer:loginServer,adminUserEnabled:adminUserEnabled}" \
  --output json
```

ARM authentication 상태를 확인합니다.

```bash
az acr config authentication-as-arm show \
  --registry "$ACR" \
  --query status \
  --output tsv
```

`AcrPull` 역할 할당을 확인합니다.

```bash
az role assignment list \
  --assignee "$UAMI_PID" \
  --scope "$ACR_ID" \
  --query "[].{role:roleDefinitionName,principalType:principalType,scope:scope}" \
  --output table
```

📋 **예상 출력**

- resource list에는 최소한 `Microsoft.OperationalInsights/workspaces`, `Microsoft.App/managedEnvironments`, `Microsoft.ContainerRegistry/registries`, `Microsoft.ManagedIdentity/userAssignedIdentities`가 보여야 합니다.
- diagnostic setting JSON에는 `aca-runner-logs`와 `allLogs`가 보여야 합니다.
- ACR JSON에는 `"adminUserEnabled": false`가 보여야 합니다.
- ARM authentication 조회 결과는 `enabled`여야 합니다.
- role assignment 표에는 `AcrPull`과 `ServicePrincipal`이 보여야 합니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `az acr create`가 이름 중복 오류를 반환함 | `ACR` 이름은 전역 고유인데 이미 다른 구독에서 사용 중 | 아래 복구 절차에 따라 ACR 이름만 바꾸고, 바뀐 실제 `ACR` 이름을 새로 저장한 뒤 다시 시도합니다. |
| ACA environment 또는 workspace 생성이 provider 오류로 실패함 | `Microsoft.App`, `Microsoft.OperationalInsights`, `Microsoft.Insights` 등록이 끝나지 않음 | [모듈 01](01-prerequisites-github.md)의 provider 등록 명령을 다시 실행하고 `--wait`가 끝날 때까지 기다립니다. |
| `az monitor diagnostic-settings create`가 권한 오류를 반환함 | 현재 구독/리소스 그룹에서 diagnostic setting을 만들 권한이 없음 | Contributor 이상 권한인지 확인하고, 잘못된 구독에 배포했다면 `az account show`로 현재 구독을 다시 확인합니다. |
| role assignment는 성공했는데 image pull이 아직 실패함 | RBAC propagation 지연 | 몇 분 기다린 뒤 `az role assignment list --assignee "$UAMI_PID" --scope "$ACR_ID" --query "[].roleDefinitionName" -o tsv`로 `AcrPull`을 확인하고 다음 모듈을 재시도합니다. |

### ACR 이름 충돌 복구

이미 앞 단계의 RG, workspace, environment를 만들었다면 전체 `SUFFIX`를 바꾸지 마세요.
ACR 이름만 새 전역 고유 값으로 변경한 뒤 `az acr create`부터 다시 실행합니다.

```bash
ACR="acracarunner$(openssl rand -hex 4)"
printf 'ACR=%s\n' "$ACR"
```

⚠️ **주의**

이 시점부터 `ACR`은 더 이상 `SUFFIX`에서 유도되지 않습니다. 방금 출력된 새 `ACR` 값을 지금 바로 저장하고, 이전에 적어 둔 `ACR` 값은 이 새 값으로 교체하세요. 모듈 03과 04는 재접속 시 `SUFFIX`와 이 실제 `ACR` 이름을 각각 따로 물어보므로, 낡은 `ACR` 값을 입력하면 충돌 복구로 새로 만든 registry를 찾지 못합니다.

리소스 이름을 모두 새 suffix로 통일하려면 기존 실습 리소스를 정리하고 모듈 02의 1단계부터 다시 시작합니다.

---

[← 이전: GitHub 사전 준비](01-prerequisites-github.md) | [다음: Runner image 빌드 →](03-runner-image.md)
