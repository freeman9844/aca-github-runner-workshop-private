# 05. 병렬 실행과 스케일 검증

> Azure Cloud Shell Bash와 GitHub 웹 UI를 함께 사용해 matrix 4 Job을 큐에 넣고, Azure Container Apps Event Job이 `0 → N → 0`으로 scale-out/scale-in 되는지 확인합니다. 이 모듈은 active execution과 완료 이력을 구분하고, CLI 로그와 Log Analytics KQL 모두에서 ephemeral runner lifecycle marker를 검증하는 데 초점을 둡니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- `samples/parallel-runner-workflow.yml` 전체를 확인한 뒤 GitHub 웹 UI로 workflow를 만든다.
- 브라우저 기반 workflow 작성과 GitHub App installation runner 인증 경로를 분리하는 이유를 설명할 수 있다.
- execution 이력과 현재 active execution을 구분해 `0 → N → 0` 상태를 읽는다.
- `az containerapp job logs show`와 `ContainerAppConsoleLogs` KQL로 runner lifecycle marker를 확인한다.
- GitHub Actions와 **Settings → Actions → Runners**에서 ephemeral runner가 영구 온라인 상태로 남지 않았는지 검증한다.

## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

👁️ **설명**

같은 Cloud Shell 세션을 계속 사용 중이라면 이 절은 건너뛰어도 됩니다. 세션이 끊겼거나 다른 브라우저/탭으로 다시 들어왔다면, Module 01에서 저장한 `SUFFIX`를 그대로 사용하고, Module 02에서 이름 충돌 복구로 변경한 실제 ACR 또는 Storage 이름이 있으면 해당 값을 복원합니다. 여기서는 새 suffix를 만들지 말고, 처음 실습에 사용한 값을 다시 넣어야 기존 Job/Log Analytics 조회가 정확히 이어집니다.

🟢 **실행**

```bash
# 저장한 suffix와 실제 ACR 이름으로 scale validation에 필요한 foundation 값을 복원합니다.
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved ACR name: " ACR
read -rp "Saved GITHUB_APP_ID: " GITHUB_APP_ID
read -rp "Saved GITHUB_APP_INSTALLATION_ID: " GITHUB_APP_INSTALLATION_ID

LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
LOG="log-acarunner-$SUFFIX"
ENV="env-acarunner-$SUFFIX"
VNET="vnet-acarunner-$SUFFIX"
INFRA_SUBNET="snet-aca-infra"
PE_SUBNET="snet-private-endpoints"
JOB="job-ghrunner-$SUFFIX"
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

# Log Analytics, PE subnet, Storage, Key Vault를 다시 조회하고 복구한 값을 출력합니다.
LOG_ID=$(az monitor log-analytics workspace show   --resource-group "$RG"   --workspace-name "$LOG"   --query customerId   --output tsv)
PE_SUBNET_ID=$(az network vnet subnet show   --resource-group "$RG"   --vnet-name "$VNET"   --name "$PE_SUBNET"   --query id   --output tsv)
STORAGE_ID=$(az storage account show   --resource-group "$RG"   --name "$STORAGE"   --query id   --output tsv)
KEY_VAULT_ID=$(az keyvault show \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --query id \
  --output tsv)
KEY_VAULT_SECRET_URI="https://$KEY_VAULT.vault.azure.net/secrets/$GITHUB_APP_KEY_SECRET"

printf 'RG=%s\nLOG=%s\nJOB=%s\nSTORAGE=%s\nKEY_VAULT=%s\nLOG_ID=%s\n' \
  "$RG" "$LOG" "$JOB" "$STORAGE" "$KEY_VAULT" "$LOG_ID"
printf 'GITHUB_APP_ID=%s\nGITHUB_APP_INSTALLATION_ID=%s\n' \
  "$GITHUB_APP_ID" "$GITHUB_APP_INSTALLATION_ID"
```

📋 **예상 출력**

- `RG`, `LOG`, `JOB`는 원래 만든 리소스 이름으로 다시 채워집니다.
- `LOG_ID`에는 Log Analytics workspace customer ID가 들어갑니다.
- 값이 비어 있거나 조회가 실패하면 SUFFIX 오타 여부와 원래 실습에서 사용한 suffix 기록을 다시 확인합니다.

</details>

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## 1. 샘플 workflow를 Cloud Shell에서 열고 GitHub 웹 UI로 생성

👁️ **설명**

이 워크숍은 로컬 편집기나 `git push` 대신 GitHub 웹 UI로 workflow 파일을 만듭니다. 이렇게 하면 browser-based workflow creation이 repository-write activity를 처리하고, 모듈 04에서 준비한 GitHub App installation과 Key Vault-backed private key는 queue monitoring과 runner bootstrap 용도로만 남겨 둘 수 있습니다. 즉 Cloud Shell에 별도의 repository write credential을 둘 필요가 없습니다.

모듈 04의 Event Job은 `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `applicationID`, `installationID`, `appKey`를 KEDA queue monitoring과 runner bootstrap에 연결합니다. 이 모듈은 그 foundation 위에서 queue-driven scale만 검증합니다.

Module 04의 Event Job에는 이미 `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_CONTAINER`, `AZURE_PRIVATE_ENDPOINT_CIDR=10.20.1.0/24`가 설정되어 있습니다. 이 모듈은 그 foundation 위에서 queue-driven scale만 검증합니다. Jobs do not support ingress 이므로 이번 검증 대상은 public inbound endpoint가 아니라 queued workflow를 처리하는 ephemeral runner lifecycle입니다.

🟢 **실행**

```bash
# reviewed scale-test workflow를 Cloud Shell에서 확인한 뒤 GitHub 웹 UI에 복사합니다.
cd ~/aca-github-runner-workshop
sed -n '1,200p' samples/parallel-runner-workflow.yml
```

이제 private lab repository의 GitHub 웹 UI에서 다음 순서로 진행합니다.

1. `.github/workflows/aca-runner-scale-test.yml`이 없으면 **Add file → Create new file**을 선택하고 해당 파일 이름을 입력합니다.
2. 기존 workflow가 이미 있으면 파일을 연 뒤 **Edit this file**을 선택합니다.
3. 두 경우 모두 기존 내용을 일부만 수정하지 말고, 방금 Cloud Shell에 출력한 `samples/parallel-runner-workflow.yml` 전체 내용으로 교체합니다.
4. `runs-on: [aca-runner]`인지 다시 확인하고 기본 브랜치에 commit합니다.

⚠️ **주의**

CLI에서 workflow를 commit/push하려고 Cloud Shell에 별도의 repository write credential을 추가하지 마세요. 이 모듈은 **웹 UI로만 workflow를 생성**해 browser session의 repository-write 활동과 GitHub App installation 기반 queue monitoring/runner bootstrap 경로를 분리합니다.

이전 실습처럼 `self-hosted`, `linux`, `x64` default label을 `aca-runner`와
함께 요구하는 `runs-on` 배열을 그대로 두면 `noDefaultLabels=true`인 현재
KEDA scaler가 해당 queued Job을 세지 않습니다. 이 경우 workflow는 queued
상태로 남고 ACA execution도 생성되지 않으므로 반드시 최신 sample 전체로
교체하세요.

📋 **예상 출력**

- Cloud Shell에는 workflow YAML 전체가 출력됩니다.
- GitHub에는 `.github/workflows/aca-runner-scale-test.yml`가 새로 생기고 workflow 이름이 **ACA Runner Scale Test**로 보입니다.

## 2. matrix 4 Job 전체 YAML 확인

👁️ **설명**

아래는 GitHub에 저장한 workflow 전체입니다. 주석을 따라 수동 실행 방식, matrix 4개, runner label, 실행 시간 확보 단계가 어떻게 연결되는지 확인합니다.

🟢 **실행**

GitHub에 저장한 workflow 또는 Cloud Shell 출력과 아래 YAML을 비교합니다.

```yaml
# GitHub Actions 화면에 표시할 workflow 이름입니다.
name: ACA Runner Scale Test

# 수동 실행으로만 scale test를 시작합니다.
on:
  workflow_dispatch:

jobs:
  # 이 job 하나가 matrix 값에 따라 네 개의 GitHub job으로 확장됩니다.
  parallel-runner:
    # Actions 화면에는 Worker 1부터 Worker 4까지 표시됩니다.
    name: Worker ${{ matrix.worker }}

    # 모듈 04에서 등록한 aca-runner custom label만 요구합니다.
    runs-on: [aca-runner]

    # runner 기동이나 workflow가 비정상적으로 지연될 때 무한 대기하지 않습니다.
    timeout-minutes: 10

    strategy:
      # 한 Worker가 실패해도 나머지 Worker를 취소하지 않아 전체 scale 결과를 확인할 수 있습니다.
      fail-fast: false
      matrix:
        # queued job 네 개를 만들어 KEDA의 0 → N scale-out을 관찰합니다.
        worker: [1, 2, 3, 4]

    steps:
      # 각 Worker가 실행된 runner hostname과 시작 시간을 기록합니다.
      - name: Show runner identity
        shell: bash
        run: |
          set -euo pipefail
          echo "worker=${{ matrix.worker }}"
          echo "hostname=$(hostname)"
          echo "started_at=$(date --utc --iso-8601=seconds)"

      # 여러 execution이 동시에 Running 상태가 되는 구간을 관찰할 시간을 확보합니다.
      - name: Hold the runner for scale observation
        shell: bash
        run: |
          set -euo pipefail
          sleep 45
          echo "completed_at=$(date --utc --iso-8601=seconds)"
```

📋 **예상 출력**

- `workflow_dispatch`가 있으면 GitHub Actions 화면에서 **Run workflow** 버튼으로 수동 실행할 수 있습니다.
- `worker: [1, 2, 3, 4]`가 보이면 matrix가 네 개의 GitHub job을 생성합니다.
- `runs-on: [aca-runner]`가 보이면 default self-hosted label이 아니라 모듈 04의 custom label만 요구합니다.
- `sleep 45`는 네 execution이 겹치는 구간을 관찰할 시간을 확보합니다.

## 3. 실행 전 baseline 이력과 active execution 0 상태 확인

👁️ **설명**

`az containerapp job execution list`는 **완료 이력**도 함께 보여 줍니다. 따라서 표에 완료된 record가 남아 있어도 이상이 아닙니다. 중요한 것은 지금 이 순간 `properties.status=='Running'`인 active execution 수가 0인지입니다.

🟢 **실행**

```bash
# workflow 실행 전 최근 이력과 Running execution이 0개인 baseline을 확인합니다.
az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "[].{Name:name,Status:properties.status,Start:properties.startTime,End:properties.endTime}" \
  --output table
```

📋 **예상 출력**

- 최초 실행처럼 execution 이력이 없다면 명령 출력 없이 다음 프롬프트로
  돌아올 수 있습니다.
- 이전 실행 이력이 있다면 끝난 execution이 `Succeeded`/`Failed` 상태로
  남아 있을 수 있습니다.
- 이 단계에서는 **active execution이 0인 상태가 정상**입니다.
- 즉, history는 남을 수 있지만 현재 처리 중인 execution이 없다는 점을 먼저 구분해야 합니다.

## 4. GitHub Actions에서 `ACA Runner Scale Test`를 수동 실행

👁️ **설명**

이 워크숍은 `workflow_dispatch`를 사용합니다. GitHub Actions 화면에서 직접 큐를 만들어야 KEDA scaler가 queued workflow를 감지합니다.

🟢 **실행**

GitHub repository에서 **Actions → ACA Runner Scale Test → Run workflow**를 선택하고 기본 브랜치에서 실행합니다.

📋 **예상 출력**

- GitHub Actions 실행 목록에 `ACA Runner Scale Test`가 새로 생성됩니다.
- 잠시 후 matrix로 분기된 `Worker 1`부터 `Worker 4`까지 네 개의 GitHub job이 queued/running 상태로 보이기 시작합니다.

> **참고 화면:** workflow를 수동 실행한 직후 네 개의 matrix Job이 `Queued` 상태로 생성된 모습입니다.

![GitHub Actions에서 네 개 matrix Job이 queued 상태인 화면](images/05-github-actions-queued-matrix.png)

## 5. 첫 30~90초 동안 Running execution만 반복 조회

👁️ **설명**

KEDA polling 간격은 30초이고, runner가 시작되는 데도 약간의 시간이 필요합니다. 따라서 polling 순간에 따라 1개만 보일 수도 있고, 4개까지 보일 수도 있습니다. **항상 네 개가 동시에 화면에 보여야 한다고 약속하면 안 됩니다.**

🟢 **실행**

처음 30~90초 동안 아래 명령을 몇 번 반복합니다.

```bash
# scale-out 구간의 상태 변화를 보기 위해 Running execution만 시간순으로 반복 조회합니다.
az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "[?properties.status=='Running'].{Name:name,Status:properties.status,Start:properties.startTime}" \
  --output table
```

📋 **예상 출력**

실제 실행에서 네 execution이 같은 시각에 시작되면 다음과 같이 보일 수 있습니다.

```text
Name                       Status    Start
-------------------------  --------  -------------------------
job-ghrunner-145945-4vql7  Running   2026-08-19T05:10:51+00:00
job-ghrunner-145945-bbqc9  Running   2026-08-19T05:10:51+00:00
job-ghrunner-145945-tvdcr  Running   2026-08-19T05:10:51+00:00
job-ghrunner-145945-xh6w5  Running   2026-08-19T05:10:51+00:00
```

- execution 이름의 suffix와 시작 시각은 실행할 때마다 달라집니다.
- 조회 시점에 따라 `Running` execution이 **1개에서 4개 사이**로 보일 수 있습니다.
- polling 타이밍과 startup timing 때문에 네 execution이 동시에 보이지 않아도 정상입니다.
- 중요한 검증 포인트는 queued GitHub job에 맞춰 active execution이 늘어났다가 나중에 다시 0으로 돌아오는지입니다.

## 6. 가장 최근 execution을 잡아 CLI 로그 확인

👁️ **설명**

`az containerapp job logs show`는 execution 하나의 컨테이너 로그를 바로 확인할 때 가장 빠릅니다. 이 모듈에서는 컨테이너 이름을 **반드시** `github-actions-runner`로 지정합니다.

🟢 **실행**

```bash
# 가장 최근 execution 이름을 조회해 뒤의 CLI·Log Analytics 필터 기준으로 저장합니다.
EXECUTION=$(az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "sort_by([], &properties.startTime)[-1].name" \
  --output tsv)

# execution을 찾지 못하면 잘못된 이름으로 로그를 조회하지 않고 명확히 중단합니다.
if [[ -z "$EXECUTION" ]]; then
  printf 'ERROR: Container Apps Job execution이 없습니다.\n' >&2
  printf 'GitHub workflow가 queued라면 runs-on이 [aca-runner]인지 확인하고 최신 sample로 교체한 뒤 다시 실행하세요.\n' >&2
else
  # 선택한 execution의 runner container stdout·stderr를 최근 100줄까지 확인합니다.
  az containerapp job logs show \
    --name "$JOB" \
    --resource-group "$RG" \
    --execution "$EXECUTION" \
    --container github-actions-runner \
    --tail 100 \
    --format text
fi
```

📋 **예상 출력**

- 최신 execution 이름이 `job-ghrunner-<suffix>-...` 같은 형식으로 `EXECUTION` 변수에 들어갑니다.
- `ERROR: Container Apps Job execution이 없습니다.`가 보이면 7단계로 진행하지 말고 GitHub workflow가 `runs-on: [aca-runner]`인지 수정한 뒤 workflow를 다시 실행합니다.
- 조회 시점에 따라 GitHub Actions worker가 bash step을 준비하고 실행하는 내부
  로그가 다음과 같이 보일 수 있습니다.

```text
2026-08-19T05:11:29.3957554Z stdout F [WORKER 2026-08-19 05:11:29Z INFO HostContext] Well known directory 'Root': '/home/runner'
2026-08-19T05:11:29.3969009Z stdout F [WORKER 2026-08-19 05:11:29Z INFO HostContext] Well known directory 'Work': '/home/runner/_work'
2026-08-19T05:11:29.3970193Z stdout F [WORKER 2026-08-19 05:11:29Z INFO HostContext] Well known directory 'Temp': '/home/runner/_work/_temp'
2026-08-19T05:11:29.3971397Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ScriptHandler] Which2: 'bash'
2026-08-19T05:11:29.3973315Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ScriptHandler] Location: '/usr/bin/bash'
2026-08-19T05:11:29.3973409Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ProcessInvokerWrapper] Starting process:
2026-08-19T05:11:29.3973465Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ProcessInvokerWrapper]   File name: '/usr/bin/bash'
2026-08-19T05:11:29.3973489Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ProcessInvokerWrapper]   Arguments: '--noprofile --norc -e -o pipefail /home/runner/_work/_temp/7ae4b711-8656-450a-ad26-701e69261ce5.sh'
2026-08-19T05:11:29.3973511Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ProcessInvokerWrapper]   Working directory: '/home/runner/_work/aca-runner-lab/aca-runner-lab'
2026-08-19T05:11:29.4002129Z stdout F [WORKER 2026-08-19 05:11:29Z INFO ProcessInvokerWrapper] Process started with process id 108, waiting for process exit.
2026-08-19T05:11:30.6453925Z stdout F [WORKER 2026-08-19 05:11:30Z INFO JobServerQueue] Got a step log file to send to results service.
2026-08-19T05:11:30.6712836Z stdout F [WORKER 2026-08-19 05:11:30Z INFO JobServerQueue] Try to upload 2 log files or attachments, success rate: 2/2.
```

- timestamp, 임시 script UUID, PID와 repository 작업 경로는 실행마다 달라집니다.
- `--tail 100` 구간에 따라 `Runner configured`, `Runner process exited`가
  보이지 않을 수 있습니다. lifecycle marker는 7단계의
  Log Analytics 조회로 다시 확인합니다.

## 7. Log Analytics에서 resource-specific `ContainerAppConsoleLogs`를 KQL로 확인

👁️ **설명**

CLI 로그가 한 execution을 빠르게 보는 용도라면, Log Analytics는 시간순으로
누적 로그를 검토하는 데 적합합니다. 이 워크숍은 legacy 테이블이 아니라
resource-specific `ContainerAppConsoleLogs`를 사용합니다.

Log Analytics ingestion은 즉시 완료되지 않을 수 있습니다. execution 직후
상세 query가 비어 있으면 먼저 최대 10분 동안 30초 간격으로 실제 로그 유입을
확인합니다. 실제 테스트에서도 마지막 로그가 Log Analytics에 나타나기까지
약 6분이 걸릴 수 있었습니다.

🟢 **실행**

```bash
# 고정 sleep 대신 실제 로그가 들어왔는지 30초마다 확인하며 최대 10분까지 기다립니다.
LOG_WAIT_TIMEOUT_SECONDS=600
LOG_WAIT_INTERVAL_SECONDS=30
LOG_WAIT_DEADLINE=$((SECONDS + LOG_WAIT_TIMEOUT_SECONDS))
LOG_COUNT=0

while (( SECONDS <= LOG_WAIT_DEADLINE )); do
  LOG_COUNT=$(az monitor log-analytics query \
    --workspace "$LOG_ID" \
    --analytics-query "
      ContainerAppConsoleLogs
      | where TimeGenerated > ago(2h)
      | summarize Count=count()
    " \
    --query "[0].Count" \
    --output tsv)

  if [[ "$LOG_COUNT" =~ ^[0-9]+$ ]] && (( LOG_COUNT > 0 )); then
    printf 'Log Analytics ingestion ready: %s rows\n' "$LOG_COUNT"
    break
  fi

  if (( SECONDS >= LOG_WAIT_DEADLINE )); then
    break
  fi

  printf 'Log Analytics ingestion pending; %s초 후 다시 확인합니다.\n' \
    "$LOG_WAIT_INTERVAL_SECONDS"
  sleep "$LOG_WAIT_INTERVAL_SECONDS"
done

if [[ ! "$LOG_COUNT" =~ ^[0-9]+$ ]] || (( LOG_COUNT == 0 )); then
  printf '%s\n' \
    'ERROR: ContainerAppConsoleLogs가 10분 안에 수집되지 않았습니다.' \
    'LOG_ID와 Module 02의 aca-runner-logs diagnostic setting을 확인하세요.' >&2
  exit 1
fi

# 로그 유입이 확인되면 replica별 건수와 마지막 수집 시각을 출력합니다.
az monitor log-analytics query \
  --workspace "$LOG_ID" \
  --analytics-query "
    ContainerAppConsoleLogs
    | where TimeGenerated > ago(2h)
    | summarize Count=count(), LastSeen=max(TimeGenerated)
        by ContainerGroupName
    | order by LastSeen desc
  " \
  --output table

unset LOG_WAIT_TIMEOUT_SECONDS LOG_WAIT_INTERVAL_SECONDS LOG_WAIT_DEADLINE LOG_COUNT
```

📋 **예상 출력**

```text
Log Analytics ingestion pending; 30초 후 다시 확인합니다.
Log Analytics ingestion ready: 8212 rows

ContainerGroupName               Count    LastSeen                      TableName
-------------------------------  -------  ----------------------------  -------------
job-ghrunner-145945-xh6w5-phfkj  2058     2026-08-19T05:12:18.2470166Z  PrimaryResult
job-ghrunner-145945-bbqc9-m97mq  1867     2026-08-19T05:12:17.8271544Z  PrimaryResult
```

- replica suffix, `Count`, `LastSeen`은 실행과 수집 시점마다 달라집니다.
- 로그가 이미 수집되었다면 `pending` 줄 없이 바로 `ready`와 집계 표가 출력됩니다.
- `$EXECUTION` 뒤에 replica suffix가 추가된 실제 `ContainerGroupName`을 확인한
  다음 상세 로그를 조회합니다.

🟢 **실행**

```bash
# 최신 execution prefix로 같은 replica들의 상세 console log를 시간순으로 조회합니다.
az monitor log-analytics query \
  --workspace "$LOG_ID" \
  --analytics-query "
    ContainerAppConsoleLogs
    | where TimeGenerated > ago(30m)
    | where ContainerGroupName startswith '$EXECUTION'
    | project TimeGenerated, ContainerGroupName, Log
    | order by TimeGenerated asc
  " \
  --output table
```

📋 **예상 출력**

- `ContainerAppConsoleLogs` 표에서 `ContainerGroupName`이 `$EXECUTION`으로 시작하는 행들이 시간순으로 출력됩니다.
- CLI 로그와 같은 execution의 메시지를 Azure Monitor 쪽에서도 재확인할 수 있습니다.
- 집계 query에는 결과가 있지만 상세 query가 비어 있으면 `$EXECUTION`이 가장
  최근 execution인지 다시 확인합니다.

## 8. GitHub에서 네 개 Job 성공과 runner hostname 차이 확인

👁️ **설명**

workflow 샘플의 `Show runner identity` 단계는 각 job이 어떤 hostname에서 실행되었는지 남깁니다. concurrency가 허용된 구간에서는 서로 다른 runner hostname이 보여야 scale-out evidence로 쓰기 좋습니다.

🟢 **실행**

GitHub Actions 실행 화면에서 `Worker 1` ~ `Worker 4` 로그를 열고 `Show runner identity` 단계의 출력값을 확인합니다.

📋 **예상 출력**

- 네 개 GitHub job이 모두 `Success`여야 합니다.
- 각 job 로그에는 `worker=...`, `hostname=...`, `started_at=...`, `completed_at=...`가 출력됩니다.
- 각 `hostname`은 현재 Job에서 유도된 `job-ghrunner-$SUFFIX-...` 형식이어야
  합니다. 다른 suffix가 보이면 다른 Event Job이 같은 repository와
  `aca-runner` label을 감시하며 queue를 가져간 것입니다.
- 실행 타이밍이 겹친 구간에서는 서로 다른 hostname이 관찰됩니다. 다만 조회 타이밍 때문에 네 개가 항상 동시에 보일 것이라고 기대하지는 마세요.

> **참고 화면:** 체크인된 이미지는 **Worker 1은 성공했고 Worker 4는 아직 진행 중인 중간 상태**를 보여 줍니다. 이 화면은 scale-out 진행 상황 예시일 뿐이며, 실제 검증은 `Worker 1`~`Worker 4`가 최종적으로 모두 `Success`인지까지 확인해야 완료입니다.

![GitHub Actions에서 Worker 1은 성공했고 Worker 4는 아직 진행 중인 중간 상태 화면](images/05-github-actions-successful-matrix.png)

## 9. Running execution이 다시 0으로 돌아오는지 확인

👁️ **설명**

scale-out 검증의 마지막은 scale-in입니다. queued job 처리가 끝난 뒤에는 `Running` filter가 더 이상 행을 반환하지 않아야 합니다.

🟢 **실행**

아래 명령을 다시 반복해 `Running` 행이 사라질 때까지 확인합니다.

```bash
# workflow 종료 후 Running execution이 다시 0개로 scale-in 되었는지 확인합니다.
az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "[?properties.status=='Running'].{Name:name,Status:properties.status,Start:properties.startTime}" \
  --output table
```

📋 **예상 출력**

- 어느 시점에는 표 헤더만 남거나 행이 0개가 됩니다.
- 이때 아래 문장을 **그대로** 기억해 두세요.

```text
대기 Job 처리가 끝나면 active execution 수는 0이 됩니다. 완료 execution 이력은 남을 수 있습니다.
```

## GitHub App 실패 검증 메모

👁️ **설명**

### KEDA authentication failure memo

queued workflow가 생겼는데 runner가 뜨지 않으면 `applicationID`, `installationID`, `appKey`, `github-app-private-key` secretRef를 먼저 확인합니다. private key PEM은 읽지 말고 `az containerapp job show --query "properties.configuration.eventTriggerConfig.scale.rules"` 출력만 검증합니다. `GitHub App installation`이 `aca-runner-lab` repository에 유지되어 있는지도 함께 확인하고, `401`은 JWT clock skew 또는 installation token 문제로, `403`은 App 권한 또는 installation approval 문제로 분리해서 봅니다.

### Key Vault resolution failure memo

`github-app-private-key`가 resolve되지 않으면 KEDA auth와 분리해서 Key Vault 경로부터 확인합니다. `identityref`가 현재 Job의 UAMI를 가리키는지, 그 UAMI에 `Key Vault Secrets User`가 vault scope로 부여되어 있는지, vault의 Private DNS와 private endpoint가 `privatelink.vaultcore.azure.net`을 실제 private IP로 해석하는지, `publicNetworkAccess`가 `Disabled`라 private path만 허용되는지 순서대로 봅니다. secret 값 자체는 읽지 말고 Key Vault reference와 network path만 검증합니다.

### Runner registration failure memo

KEDA auth와 Key Vault resolution이 맞는데도 runner가 등록되지 않으면 registration token 단계로 좁혀 봅니다. 이 경우 `github-app-private-key` secret이 현재 GitHub App의 활성 private key와 일치하는지 확인하고, execution log에 GitHub API 오류가 나온 뒤 `Runner configured`가 누락되었는지 확인합니다.

👁️ **설명**

```bash
# GitHub App scaler rule과 secretRef 매핑만 읽기 전용으로 점검합니다.
az containerapp job show \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "properties.configuration.eventTriggerConfig.scale.rules" \
  --output yaml
```

📋 **예상 출력**

- `applicationID`, `installationID`, `appKey`가 보입니다.
- `github-app-private-key` secretRef가 유지되어야 하고, `identityref`도 현재 UAMI를 가리켜야 합니다.
- `GitHub App installation`이 `aca-runner-lab` repository에 설치된 상태여야 합니다.
- `Key Vault Secrets User`, Private DNS/private endpoint, `publicNetworkAccess` 상태는 KEDA auth와 별개로 확인합니다.
- `401`과 `403`은 서로 다른 복구 경로를 뜻합니다.

## 10. GitHub Settings에서 permanent online runner가 남지 않았는지 확인

👁️ **설명**

ephemeral runner 워크숍의 핵심은 job이 끝난 뒤 runner가 계속 온라인 상태로 남지 않는 것입니다. Actions 실행 화면과 별개로 repository runner 목록도 반드시 확인합니다.

🟢 **실행**

GitHub repository에서 **Settings → Actions → Runners**로 이동합니다.

📋 **예상 출력**

- workflow가 모두 끝난 뒤에는 runner가 permanently online 상태로 남아 있지 않아야 합니다.
- 일시적으로 offline record가 보일 수는 있지만, 장시간 고정된 online runner가 보이면 ephemeral 정리 흐름을 다시 확인해야 합니다.

> **참고 화면:** 아래 화면처럼 **Self-hosted runners** 목록에 runner가 없으면 ephemeral runner가 workflow 종료 후 정상적으로 정리된 상태입니다.

![GitHub Actions Self-hosted runners 목록이 비어 있는 정상 화면](images/05-github-actions-no-self-hosted-runners.png)

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| GitHub job이 계속 queued 상태로 남음 | GitHub App이 `aca-runner-lab` repository에 설치되지 않았거나, `applicationID`/`installationID`가 틀렸거나, workflow label이 다름 | GitHub App installation이 선택한 `aca-runner-lab` repository에 남아 있는지 확인하고, `az containerapp job show --name "$JOB" --resource-group "$RG" --query "properties.configuration.eventTriggerConfig.scale.rules"`에서 `githubApiURL=https://api.github.com`, `owner`, `runnerScope=repo`, `repos=$GITHUB_REPO`, `labels=aca-runner`, `noDefaultLabels=true`, `targetWorkflowQueueLength=1`, `applicationID`, `installationID`, `appKey -> github-app-private-key`가 모두 정확한지 다시 확인합니다. |
| `github-app-private-key`가 resolve되지 않음 | `identityref`가 잘못되었거나 UAMI의 Key Vault 권한 또는 private DNS/private endpoint 경로가 깨짐 | `az containerapp job show --name "$JOB" --resource-group "$RG" --query "properties.configuration.secrets"`와 Key Vault 설정을 함께 확인해 `github-app-private-key=keyvaultref:...,identityref:$UAMI_RID`가 유지되는지, UAMI에 `Key Vault Secrets User`가 있는지, vault `publicNetworkAccess=Disabled`와 `privatelink.vaultcore.azure.net` DNS가 같은 private endpoint를 가리키는지 다시 검증합니다. |
| `ContainerAppJobsExecutionNotFound`와 `execution - replicas`가 표시됨 | `EXECUTION`이 비어 있으며, 흔히 기존 workflow가 default label을 계속 요구해 KEDA가 queued Job을 세지 못한 상태 | GitHub workflow를 최신 sample 전체로 교체해 `runs-on: [aca-runner]`로 만들고, 기존 queued run을 취소한 뒤 다시 실행합니다. ACA execution이 생성된 후 6단계의 `EXECUTION=$(...)` 블록부터 다시 실행합니다. |
| workflow hostname의 suffix가 현재 `$SUFFIX`와 다르거나 현재 execution이 timeout됨 | 다른 Event Job이 같은 repository와 `aca-runner` label을 감시함 | 모듈 04의 중복 watcher query로 이전 Job을 찾습니다. 이전 실습 Job을 정리하거나 새 lab repository를 사용한 뒤 다시 실행합니다. |
| Running execution이 항상 1개만 보임 | polling 타이밍상 동시에 관찰하지 못했거나 Azure quota/시작 지연이 있음 | 먼저 GitHub에서 네 job이 모두 생성되었는지 확인하고, 30~90초 동안 같은 `Running` query를 반복합니다. 네 개가 항상 한 번에 보여야 한다고 가정하지 마세요. |
| `az containerapp job logs show`에 아직 로그가 거의 없음 | execution 시작 직후라 runner bootstrap 로그가 아직 수집되지 않음 | 10~20초 정도 기다렸다가 같은 `EXECUTION`으로 다시 조회하고, 필요하면 가장 최근 execution 이름을 다시 잡아 확인합니다. |
| ACA 쪽 execution은 끝났는데 과거 replica 로그가 안 보이거나 일부만 남음 | 로그 보존/수집 지연 또는 조회 대상을 잘못 잡음 | `EXECUTION=$(...)`로 최신 execution 이름을 다시 구한 뒤 `ContainerAppConsoleLogs | where ContainerGroupName startswith '$EXECUTION'` KQL로 조회 범위를 좁힙니다. |
| GitHub API 또는 scaler 동작이 401/403을 반환함 | JWT clock skew, installation token 실패, 또는 App permission/approval 누락 | `401`이면 private key로 만든 JWT의 시스템 시간이 맞는지 먼저 확인하고, `403`이면 App 권한 변경 후 installation approval이 갱신됐는지 확인합니다. 둘 다 `applicationID`, `installationID`, `GitHub App installation`, `appKey`를 다시 점검해야 합니다. |
| KEDA scaler가 queue를 감시하지 못함 | ACA secret 또는 auth mapping 이름이 맞지 않음 | ACA secret `github-app-private-key`와 scale-rule auth `appKey` 매핑이 그대로 유지됐는지 `az containerapp job show ... --query "properties.configuration.eventTriggerConfig.scale.rules"`로 다시 확인합니다. |
| runner registration이 실패함 | private key가 손상되었거나 disabled/deleted key를 참조하거나 registration token 발급이 실패함 | `github-app-private-key` secret이 현재 GitHub App의 활성 private key와 일치하는지 확인하고, execution log의 GitHub API 오류와 `Runner configured` 출력 여부를 함께 확인합니다. |
| secret rotation 뒤에도 이전 인증처럼 동작함 | 교체 후 기존 Job 정의가 그대로 남아 있거나 옛 Key Vault secretRef를 계속 참조함 | 새 `github-app-private-key` secret으로 바꾼 뒤 이 워크숍 Job만 다시 생성해 `appKey`가 새 Key Vault secret을 resolve하도록 합니다. |
| workflow가 오래 걸리다가 timeout으로 실패함 | execution 기동 지연, GitHub queue 적체, 또는 외부 서비스 일시 지연 | GitHub Actions와 ACA execution 시작 시간을 함께 비교합니다. 필요하면 잠시 후 같은 workflow를 다시 실행해 재현성을 확인합니다. |
| **Settings → Actions → Runners**에 stale offline runner가 남아 보임 | GitHub UI의 기록 반영 지연 또는 cleanup metadata 잔존 | 몇 분 후 새로고침해 사라지는지 확인하고, 계속 남으면 최신 execution 로그에서 `Runner process exited`가 있었는지 먼저 검토합니다. persistent online runner가 남는 경우만 문제로 취급합니다. |

---

[← 이전: Event Job + KEDA 구성](04-event-job-keda.md)
[다음: Private Blob 배포와 결과 확인 →](06-azure-sample-deployment.md)

Module 06은 필수 단계입니다. 위 링크로 이동해 Private Blob 배포와 결과 확인을 계속합니다.
