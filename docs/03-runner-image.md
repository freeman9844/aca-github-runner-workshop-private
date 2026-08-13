# 03. Runner image 빌드

> Azure Cloud Shell Bash에서 `runner/Dockerfile`과 `runner/entrypoint.sh`를 점검하고, ACR Tasks로 `github-actions-runner:2.336.0` 이미지를 빌드해 다음 모듈의 ACA Job이 pull할 준비를 마칩니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- 저장해 둔 `SUFFIX`로 모듈 02의 Azure 변수들을 복구한다.
- `runner/Dockerfile`과 `runner/entrypoint.sh`의 핵심 동작을 이해한다.
- 로컬 정적 검사를 먼저 실행해 runner 스크립트 품질을 확인한다.
- ACR Tasks의 `az acr build`로 cloud build를 수행한다.
- ACR 태그와 보안 설정을 확인해 다음 모듈 입력값을 검증한다.

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## 1. 저장해 둔 `SUFFIX`로 Azure 변수 복구

👁️ **설명**

Cloud Shell 세션이 끊기면 셸 변수는 사라집니다. 모듈 02에서 기록해 둔 `SUFFIX`만 있으면 동일한 리소스 이름과 조회형 변수들을 다시 복구할 수 있습니다.

🟢 **실행**

세션이 그대로라면 건너뛰어도 되지만, 재접속했다면 아래 블록을 그대로 다시 실행합니다.

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
printf 'SUFFIX=%s ACR=%s IMAGE=%s\n' "$SUFFIX" "$ACR" "$IMAGE"
```

📋 **예상 출력**

```text
SUFFIX=01234 ACR=acracarunner01234 IMAGE=github-actions-runner:2.336.0
```

## 2. runner 이미지 파일 읽기

👁️ **설명**

이 모듈의 빌드 입력은 `runner/Dockerfile`과 `runner/entrypoint.sh` 두 파일입니다.

- `runner/Dockerfile`은 `ghcr.io/actions/actions-runner:2.336.0`를 기반으로 시작합니다.
- 필수 유틸리티 `ca-certificates`, `curl`, `jq`, `openssl`만 추가 설치하고 마지막에 `USER runner`로 내려가 non-root로 실행합니다.
- `runner/entrypoint.sh`는 OpenSSL로 짧게 유효한 GitHub App JWT를 서명하고, installation token과 registration token을 차례로 받아 ephemeral runner를 등록합니다.
- App credentials are removed from the environment before the workflow runner starts.
- `./config.sh --ephemeral --disableupdate`를 사용하므로 Job 1회당 1회성 runner가 뜨고, 컨테이너 안에서 자체 업데이트를 시도하지 않습니다.
- Docker daemon은 넣지 않습니다. Azure Container Apps Jobs는 Docker-in-Docker를 지원하지 않으므로 이 워크숍의 workflow도 Docker 명령을 전제로 하지 않습니다.

⚠️ **주의**

base image tag와 문서의 `IMAGE="github-actions-runner:2.336.0"`는 같이 움직여야 합니다. 둘 중 하나만 바꾸면 태그 확인이나 다음 모듈 배포 단계가 어긋납니다.

## 3. 로컬 정적 검사 먼저 실행

👁️ **설명**

TDD 흐름상 배포 문서를 쓰기 전에 현재 runner artifact가 기대한 상태인지 확인합니다. `entrypoint.sh` 문법, entrypoint 테스트, 문서/샘플 artifact 검사를 순서대로 돌리면 build 원인과 문서 원인을 분리하기 쉽습니다.

🟢 **실행**

```bash
cd ~/aca-github-runner-workshop
bash -n runner/entrypoint.sh
bash tests/runner/test-entrypoint.sh
bash tests/test-artifacts.sh
```

📋 **예상 출력**

- `bash -n runner/entrypoint.sh`는 출력 없이 종료됩니다.
- `bash tests/runner/test-entrypoint.sh`는 `PASS: entrypoint behavior`를 출력합니다.
- `bash tests/test-artifacts.sh`는 `PASS: runner image and workflow artifacts`를 출력합니다.

## 4. ACR Tasks로 runner image 빌드

👁️ **설명**

Cloud Shell에는 Docker daemon이 없어도 됩니다. `az acr build`는 소스 컨텍스트를 ACR Tasks로 보내 Azure 쪽에서 빌드하므로 로컬 Docker 설치나 privileged 권한이 필요 없습니다.

🟢 **실행**

```bash
az acr build \
  --resource-group "$RG" \
  --registry "$ACR" \
  --image "$IMAGE" \
  ./runner
```

📋 **예상 출력**

- 스트리밍 로그가 보이다가 최종적으로 build run ID와 push 완료 메시지가 출력됩니다.
- 빌드가 끝나면 `$ACR_SERVER/github-actions-runner:2.336.0` 이미지가 레지스트리에 존재해야 합니다.

## 5. 태그와 ACR 보안 설정 검증

🟢 **실행**

```bash
az acr repository show-tags \
  --name "$ACR" \
  --repository github-actions-runner \
  --output table

az acr show \
  --name "$ACR" \
  --query "{loginServer:loginServer,adminUserEnabled:adminUserEnabled}" \
  --output table
```

📋 **예상 출력**

- tag 목록에 `2.336.0`이 보여야 합니다.
- `az acr show` 표에는 `loginServer`가 `<registry>.azurecr.io` 형식으로 보이고 `adminUserEnabled`는 반드시 `False`여야 합니다.
- `adminUserEnabled`가 `False`라는 것은 다음 모듈에서 registry admin password 대신 UAMI + `AcrPull`을 사용한다는 뜻입니다.

## 6. 왜 이 구성을 유지하나요?

👁️ **설명**

| 항목 | 이유 |
|------|------|
| base image pinning | `ghcr.io/actions/actions-runner:2.336.0`처럼 고정 버전을 써야 워크숍 결과와 트러블슈팅 기준이 흔들리지 않습니다. |
| `--disableupdate` | ephemeral runner가 시작될 때마다 self-update를 시도하면 실행 시간이 늘고 재현성이 떨어집니다. 워크숍은 검증된 tag를 새로 빌드해 배포하는 방식을 사용합니다. |
| ACR cloud build | Cloud Shell 로컬 Docker에 의존하지 않고 Azure 쪽에서 build/push를 끝내므로 참가자 환경 편차가 작습니다. |
| non-root 실행 | `USER runner`로 내려가 GitHub runner 프로세스를 최소 권한으로 실행합니다. |
| Docker 미포함 | ACA Jobs는 Docker daemon과 Docker-in-Docker를 지원하지 않습니다. 따라서 이 워크숍의 runner는 Docker build용이 아니라 일반 workflow job 실행용입니다. |

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `az acr build`가 `unauthorized` 또는 upstream pull 오류로 실패함 | `ghcr.io/actions/actions-runner:2.336.0` pull 과정의 일시적 네트워크 문제 또는 upstream rate/availability 이슈 | 잠시 후 같은 명령을 다시 실행합니다. 장시간 지속되면 `runner/Dockerfile`의 `FROM ghcr.io/actions/actions-runner:2.336.0`가 오타 없는지 먼저 확인합니다. |
| build는 성공했는데 다음 모듈에서 image pull 실패 | `AcrPull` RBAC 전파가 아직 끝나지 않음 | 몇 분 기다린 뒤 `az role assignment list --assignee "$UAMI_PID" --scope "$ACR_ID" --query "[].roleDefinitionName" --output tsv`로 `AcrPull`을 확인하고 Job 생성/업데이트를 다시 시도합니다. |
| `COPY entrypoint.sh` 관련 오류가 남 | 잘못된 build context에서 `az acr build`를 실행함 | 명령 끝 인자가 반드시 `./runner`인지 확인합니다. 루트(`.`)나 다른 경로로 실행하면 Dockerfile 옆 파일 기준이 달라질 수 있습니다. |
| `runner/entrypoint.sh` 또는 테스트 파일을 못 찾음 | 워크숍 저장소 루트가 아닌 위치에서 검사 명령을 실행함 | `cd ~/aca-github-runner-workshop` 후 `ls`로 `runner`, `tests`, `docs`가 보이는지 확인한 다음 다시 실행합니다. |
| runner 버전을 올리고 싶음 | base image tag와 image tag가 서로 안 맞을 수 있음 | `runner/Dockerfile`의 `FROM ghcr.io/actions/actions-runner:<new-version>`과 셸 변수 `IMAGE="github-actions-runner:<new-version>"`를 함께 바꾸고, `bash -n runner/entrypoint.sh`, `bash tests/runner/test-entrypoint.sh`, `bash tests/test-artifacts.sh`, `az acr build ...` 순서로 다시 검증합니다. |

---

[← 이전: Azure 기반 리소스 준비](02-azure-foundation.md) | [다음: Event Job + KEDA 구성 →](04-event-job-keda.md)
