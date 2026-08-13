# 04. Event Job + KEDA 구성

> Azure Cloud Shell Bash에서 ACR image, GitHub App credential, User-Assigned Managed Identity, KEDA `github-runner` scaler를 연결해 repository-scoped Azure Container Apps Event Job을 배포합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- 저장해 둔 `SUFFIX`로 Azure 변수들을 복구한다.
- 세션이 재시작되었더라도 GitHub owner/repo/App ID/installation ID/private key를 안전하게 다시 입력한다.
- `github-actions-runner`라는 container name으로 ACA Event Job을 만든다.
- `github-runner` scaler의 execution/scale/auth/metadata 값을 이해한다.
- secret 값을 노출하지 않고 Job 설정과 초기 상태를 검증한다.

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## 1. 저장해 둔 `SUFFIX`로 Azure 변수 복구

👁️ **설명**

이 모듈은 모듈 02와 03의 출력값을 모두 사용합니다. Cloud Shell을 다시 열었다면 `SUFFIX`를 기준으로 Azure 리소스 이름과 조회형 변수들을 다시 채웁니다.

🟢 **실행**

```bash
read -rp "Saved SUFFIX: " SUFFIX
LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
LOG="log-acarunner-$SUFFIX"
ENV="env-acarunner-$SUFFIX"
ACR="acracarunner$SUFFIX"
UAMI="id-acarunner-$SUFFIX"
JOB="job-ghrunner-$SUFFIX"
IMAGE="github-actions-runner:2.336.0"

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
ENV_ID=$(az containerapp env show \
  --resource-group "$RG" \
  --name "$ENV" \
  --query id \
  --output tsv)
ACR_SERVER=$(az acr show --name "$ACR" --query loginServer --output tsv)
ACR_ID=$(az acr show --name "$ACR" --query id --output tsv)
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

export SUFFIX LOC RG LOG ENV ACR UAMI JOB IMAGE LOG_ID LOG_RID ENV_ID ACR_SERVER ACR_ID UAMI_RID UAMI_PID
printf 'JOB=%s ENV=%s ACR_SERVER=%s\n' "$JOB" "$ENV" "$ACR_SERVER"
```

📋 **예상 출력**

```text
JOB=job-ghrunner-01234 ENV=env-acarunner-01234 ACR_SERVER=acracarunner01234.azurecr.io
```

## 2. GitHub App 입력값 다시 로드

👁️ **설명**

Cloud Shell 세션이 재시작되면 GitHub 변수도 사라집니다. 모듈 01과 동일한 계약으로 owner, repo, App ID, installation ID, private key PEM 경로를 다시 읽고 private key 본문만 메모리 변수로 올립니다.

🟢 **실행**

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rp "GitHub App ID: " GITHUB_APP_ID
read -rp "GitHub App installation ID: " GITHUB_APP_INSTALLATION_ID
read -rp "GitHub App private key PEM path: " GITHUB_APP_PRIVATE_KEY_PATH

[[ -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]] || {
  printf 'Private key file not found: %s\n' "$GITHUB_APP_PRIVATE_KEY_PATH" >&2
  return 1 2>/dev/null || exit 1
}

GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"
export GITHUB_OWNER GITHUB_REPO GITHUB_APP_ID
export GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY
```

📋 **예상 출력**

- 프롬프트는 owner, repository, App ID, installation ID, PEM 경로를 순서대로 요청합니다.
- PEM 본문은 파일에서 읽어 메모리 변수로만 저장하고, 화면에 그대로 출력하지 않습니다.

## 3. ACA Event Job 생성

👁️ **설명**

이 워크숍은 queued workflow가 생겼을 때만 runner를 띄우는 Event Job을 사용합니다. runner container 이름은 문서, 검증, 로그 해석을 통일하기 위해 반드시 `github-actions-runner`로 고정합니다.

🟢 **실행**

```bash
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

  # GitHub.com API에서 지정한 private repository와 aca-runner label만 감시합니다.
  --scale-rule-metadata \
  "githubApiURL=https://api.github.com"
  "owner=$GITHUB_OWNER"
  "runnerScope=repo"
  "repos=$GITHUB_REPO"
  "labels=aca-runner"

  # queued workflow job 1개당 execution 1개가 필요하다고 계산합니다.
  "targetWorkflowQueueLength=1"
  "applicationID=$GITHUB_APP_ID"
  "installationID=$GITHUB_APP_INSTALLATION_ID"

  # scaler는 Job secret에 저장된 GitHub App private key로 GitHub API를 호출합니다.
  --scale-rule-auth "appKey=github-app-private-key"
  --secrets "github-app-private-key=$GITHUB_APP_PRIVATE_KEY"

  # entrypoint에 GitHub App secret, repository URL, token API URL, runner label과 이름 prefix를 전달합니다.
  --env-vars
  "GITHUB_APP_ID=$GITHUB_APP_ID"
  "GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID"
  "GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key"
  "GH_URL=https://github.com/$GITHUB_OWNER/$GITHUB_REPO"
  "REGISTRATION_TOKEN_API_URL=https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token"
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

az containerapp job create "${JOB_CREATE_ARGS[@]}"
unset JOB_CREATE_ARGS GITHUB_APP_PRIVATE_KEY
```

📋 **예상 출력**

- 명령은 `--output none` 때문에 정상 시 별도 JSON 없이 종료됩니다.
- 실패 없이 반환되면 Event Job 정의가 저장된 것입니다. 실제 execution은 workflow가 queued 되기 전까지 생성되지 않을 수 있습니다.

## 4. 기존 Job이 있으면 안전하게 복구

👁️ **설명**

`az containerapp job create`는 기존 Job을 원하는 상태로 덮어쓰는 idempotent update 명령이 아닙니다. 같은 이름의 Job이 이미 있다면 먼저 존재 여부를 확인하고, 실습 중 일부 설정을 잘못 넣어 다시 만들어야 할 때도 워크숍 Job 하나만 지운 뒤 이 모듈을 다시 실행합니다.

🟢 **실행**

```bash
az containerapp job show --name "$JOB" --resource-group "$RG" --output none
```

이미 존재하는 Job을 다시 만들어야 한다면 아래처럼 **이 워크숍 Job만** 삭제합니다.

```bash
az containerapp job delete \
  --name "$JOB" \
  --resource-group "$RG" \
  --yes
```

⚠️ **주의**

Do not instruct participants to recreate the whole resource group for a Job configuration error.

## 5. secret을 노출하지 않고 Job 상태 검증

👁️ **설명**

검증은 Job configuration과 execution 상태만 읽습니다. secret 값은 query에 포함하지 않으므로 GitHub App private key가 다시 출력되지 않습니다.

🟢 **실행**

```bash
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

az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --output table
```

📋 **예상 출력**

`az containerapp job show` 결과에는 최소한 아래 성격이 보여야 합니다.

```yaml
triggerType: Event
replicaTimeout: 900
minExecutions: 0
maxExecutions: 5
pollingInterval: 30
image: <registry>.azurecr.io/github-actions-runner:2.336.0
rules:
  - name: github-runner
    type: github-runner
```

`az containerapp job execution list`는 workflow를 아직 queue에 넣지 않았다면 표 헤더만 나오거나 행이 0개일 수 있습니다. **배포 직후 active execution이 없는 것이 정상**입니다.

## 6. GitHub 쪽에서 미리 확인할 것

👁️ **설명**

GitHub 저장소의 **Settings → Actions → Runners**를 열어보면, workflow를 아직 queue에 넣기 전에는 permanently online runner가 없어도 정상입니다. 이 워크숍의 runner는 Event Job이 queued workflow를 감지했을 때만 잠깐 생성되고, job이 끝나면 ephemeral runner도 사라집니다.

⚠️ **주의**

워크숍 시작 전에 runner를 수동으로 미리 등록해 둘 필요가 없습니다. 항상 queue를 트리거로 생성되는지 확인해야 `0 → N → 0` 검증이 가능합니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| workflow가 계속 queued이고 execution이 안 생김 | App이 대상 repository에 설치되지 않았거나 installation ID가 틀림 | 모듈 01에서 App이 `Only select repositories`로 `aca-runner-lab`에만 설치되었는지 확인하고, 설치 URL 마지막 숫자가 `GITHUB_APP_INSTALLATION_ID`와 같은지 다시 확인한 뒤 Job을 다시 만듭니다. |
| `job show`의 rule은 보이는데 scale이 안 됨 | scaler metadata 오타 또는 잘못된 키 이름 | `githubApiURL=https://api.github.com`, `owner`, `runnerScope=repo`, `repos=$GITHUB_REPO`, `labels=aca-runner`, `targetWorkflowQueueLength=1`, `applicationID`, `installationID`가 정확한지 `az containerapp job show ... --query "properties.configuration.eventTriggerConfig.scale.rules"`로 다시 확인합니다. |
| execution은 생겼는데 GitHub job이 runner를 못 잡음 | workflow label과 runner label 불일치 | workflow의 `runs-on`에 `aca-runner`가 들어 있는지, Job env가 `RUNNER_LABELS=aca-runner`인지 동시에 확인합니다. |
| execution이 바로 실패하며 image pull 오류가 남 | UAMI의 `AcrPull` 전파 지연 또는 registry identity 설정 누락 | `az role assignment list --assignee "$UAMI_PID" --scope "$ACR_ID" --query "[].roleDefinitionName" --output tsv`로 `AcrPull`을 확인하고, Job 정의에 `--mi-user-assigned "$UAMI_RID"`와 `--registry-identity "$UAMI_RID"`가 모두 들어갔는지 다시 봅니다. |
| execution이 곧바로 인증 오류로 끝남 | App ID, installation ID, private key PEM이 서로 다른 App 기준으로 섞였거나 private key 본문이 잘림 | 모듈 01 검증 단계처럼 같은 App의 `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, PEM 파일을 다시 읽고 `GITHUB_APP_PRIVATE_KEY_PATH`가 올바른 파일인지 확인한 뒤 Job을 다시 만듭니다. |
| GitHub API에서 403 또는 registration token 발급 실패 | App permission 부족 또는 permission 변경 후 재설치/승인 누락 | App의 repository permissions가 `Actions: Read-only`, `Administration: Read and write`, `Metadata: Read-only`인지 확인하고, 변경 직후라면 설치 화면에서 다시 승인합니다. |
| `unrecognized arguments` 또는 help와 문서가 다름 | Cloud Shell의 containerapp extension/CLI가 오래됨 | 모듈 01의 `az extension add --name containerapp --upgrade --only-show-errors`를 다시 실행하고 `az version`으로 갱신 여부를 확인한 뒤 명령을 재시도합니다. |
| 방금 권한이나 설치 범위를 바꿨는데도 실패가 계속됨 | GitHub App 설치/permission 반영 지연 또는 Azure RBAC propagation 지연 | 수 분 정도 기다린 뒤 다시 queue를 만들고, 그래도 안 되면 Job 하나만 삭제 후 이 모듈을 다시 실행합니다. 리소스 그룹 전체를 다시 만들 필요는 없습니다. |

---

[← 이전: Runner image 빌드](03-runner-image.md) | [다음: 병렬 실행과 스케일 검증 →](05-parallel-scale-validation.md)
