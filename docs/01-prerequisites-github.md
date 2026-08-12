# 01. GitHub 사전 준비

> Azure Cloud Shell Bash에서 구독, GitHub `Private repository`, Fine-grained PAT를 준비하고 다음 모듈에서 재사용할 `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_PAT`를 검증합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- Cloud Shell에서 실습에 사용할 Azure 구독을 선택한다.
- Azure Container Apps 관련 CLI extension과 provider 등록 상태를 맞춘다.
- `aca-runner-lab` 이름의 `Private repository`를 준비한다.
- 30일 만료 Fine-grained PAT를 필요한 최소 권한만으로 만든다.
- `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_PAT`를 안전하게 저장하고 GitHub API로 검증한다.

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## 1. Cloud Shell에서 Azure 구독 선택

👁️ **설명**

Cloud Shell을 열면 여러 구독이 보일 수 있습니다. 실습 리소스를 만들 구독을 먼저 고정해야 이후 명령이 의도한 구독에 배포됩니다.

🟢 **실행**

```bash
az account list --query "[].{Name:name,SubscriptionId:id,State:state}" -o table
read -rp "Azure subscription ID: " SUBSCRIPTION_ID
az account set --subscription "$SUBSCRIPTION_ID"
az account show --query "{Name:name,SubscriptionId:id,State:state}" -o table
```

📋 **예상 출력**

- 첫 번째 표에는 현재 로그인한 구독 목록이 보입니다.
- 마지막 표에는 방금 선택한 구독 1개만 표시되고 `State`가 `Enabled`여야 합니다.

## 2. Azure CLI extension 및 provider 준비

👁️ **설명**

이 워크숍은 Azure Container Apps Job, Azure Monitor, Log Analytics를 사용합니다. Cloud Shell에서 필요한 extension과 resource provider를 먼저 준비합니다.

🟢 **실행**

```bash
az extension add --name containerapp --upgrade --only-show-errors
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.OperationalInsights --wait
az provider register -n Microsoft.Insights --wait
```

📋 **예상 출력**

- 네 명령 모두 오류 없이 종료됩니다.
- `--wait`를 사용했으므로 provider 상태가 `Registered`가 될 때까지 반환하지 않습니다.

## 3. GitHub에서 실습용 `Private repository` 만들기

👁️ **설명**

이 실습은 queued workflow Job을 self-hosted runner가 처리하므로 반드시 `Private repository`에서만 진행합니다. Public repository는 신뢰하지 않는 코드 실행 위험이 있으므로 사용하지 않습니다.

`aca-runner-lab`은 미리 존재하는 저장소가 아니라 이 단계에서 참가자가 새로 만드는 **실습용 repository**입니다. 워크숍 문서와 runner 소스가 들어 있는 workshop repository와는 별개의 저장소이며, 이후 workflow 실행, KEDA queue 감시, self-hosted runner 등록 대상은 모두 `aca-runner-lab`입니다.

🟢 **실행**

GitHub 웹 UI에서 새 저장소를 만들고 아래 값을 사용합니다.

| 설정 | 값 |
|------|----|
| Repository name | `aca-runner-lab` |
| Visibility | **Private** |
| Initialize this repository with | `README` 파일 생성 |

⚠️ **주의**

- 실습 저장소는 개인 계정 또는 조직 어느 쪽에 만들어도 되지만, 이후 단계에서 `GITHUB_OWNER`를 직접 입력하므로 특정 owner 이름을 문서에 하드코딩하지 않습니다.
- 실습 중 runner를 연결할 저장소는 이 `Private repository` 하나만 선택하세요.

## 4. 워크숍 소스 저장소 clone

👁️ **설명**

문서, 샘플 workflow, runner 이미지 파일은 워크숍 소스 저장소에 들어 있습니다. 실습용 GitHub owner가 누구인지 미리 가정하지 않고 URL을 직접 받습니다.

🟢 **실행**

```bash
read -rp "Workshop repository URL: " WORKSHOP_REPO_URL
git clone "$WORKSHOP_REPO_URL" ~/aca-github-runner-workshop
cd ~/aca-github-runner-workshop
ls
```

📋 **예상 출력**

`ls` 결과에 최소한 다음 항목이 보여야 합니다.

- `README.md`
- `docs`
- `runner`
- `samples`
- `tests`

## 5. Fine-grained PAT 만들기

👁️ **설명**

KEDA `github-runner` scaler와 runner 등록 API는 GitHub API 인증이 필요합니다. 코어 실습은 교육 시간을 줄이기 위해 **30일 만료 Fine-grained PAT**를 사용합니다.

PAT의 repository 범위에는 워크숍 소스 저장소가 아니라 **3단계에서 새로 만든 `aca-runner-lab`**을 선택합니다.

🟢 **실행**

GitHub에서 **Settings → Developer settings → Personal access tokens → Fine-grained tokens**로 이동한 뒤 아래 기준으로 새 토큰을 만듭니다.

| 항목 | 값 |
|------|----|
| Token name | `aca-runner-lab-pat` 등 식별 가능한 이름 |
| Expiration | **30 days** |
| Resource owner | 실습 저장소 owner |
| Repository access | **Only select repositories** |
| Selected repository | `aca-runner-lab` |

필수 repository permissions는 아래 **정확한 세 가지**만 사용합니다.

| Permission | Access |
|------------|--------|
| Actions | Read-only |
| Administration | Read and write |
| Metadata | Read-only |

⚠️ **주의**

- 토큰 값은 다시 전체 표시되지 않을 수 있으므로 생성 직후 바로 Cloud Shell에 입력합니다.
- 토큰을 메모, 문서, 스크린샷, Git 기록에 남기지 마세요.

## 6. Cloud Shell 변수로 저장소 정보와 PAT 저장

👁️ **설명**

다음 단계에서 GitHub API URL과 Azure Container Apps secret을 만들 때 이 변수들을 재사용합니다. `read -rsp`를 사용하면 PAT 입력이 화면에 표시되지 않습니다.

🟢 **실행**

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rsp "GitHub PAT: " GITHUB_PAT
echo
export GITHUB_OWNER GITHUB_REPO GITHUB_PAT
printf 'GITHUB_OWNER=%s\nGITHUB_REPO=%s\nGITHUB_PAT=%s\n' \
  "$GITHUB_OWNER" \
  "$GITHUB_REPO" \
  "${GITHUB_PAT:+SET}"
```

📋 **예상 출력**

- `GitHub PAT:` 입력 중에는 커서만 움직이고 토큰 값이 화면에 표시되지 않습니다.
- `echo` 때문에 입력 뒤 줄바꿈이 한 번 추가됩니다.
- `export` 명령은 성공해도 별도 출력을 만들지 않습니다.
- 마지막 `printf`에서 owner와 repository 이름이 표시되고 `GITHUB_PAT=SET`이 출력되어야 합니다. PAT 원문은 출력하지 않습니다.

```text
GITHUB_OWNER=octocat
GITHUB_REPO=aca-runner-lab
GITHUB_PAT=SET
```

`GITHUB_OWNER` 값은 본인이 선택한 개인 계정 또는 organization 이름에 따라 달라집니다. 이후 같은 Cloud Shell 세션에서 세 변수를 그대로 재사용할 수 있습니다.

## 7. GitHub API로 저장소 접근 검증

👁️ **설명**

검증 목표는 두 가지입니다.

1. PAT가 선택한 저장소에 실제로 접근 가능한지 확인한다.
2. 저장소가 `Private repository`인지 다시 확인한다.

문서 예시도 실제 검증에 바로 사용할 수 있어야 하므로, PAT를 화면에 출력하지 않으면서 인증 헤더를 별도 변수에 안전하게 구성합니다.

🟢 **실행**

아래 예시는 토큰이나 완성된 인증 헤더를 echo하지 않고 그대로 API 호출에만 사용합니다.

```bash
printf -v AUTH_HEADER '%s: %s %s' 'Authorization' 'Bearer' "$GITHUB_PAT"
curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2022-11-28' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO" \
  | jq '{full_name, private, visibility}'
unset AUTH_HEADER
```

📋 **예상 출력**

```json
{
  "full_name": "<owner>/<repo>",
  "private": true,
  "visibility": "private"
}
```

## 8. 검증

🟢 **실행**

```bash
printf 'OWNER=%s REPO=%s\n' "$GITHUB_OWNER" "$GITHUB_REPO"
```

📋 **예상 출력**

- owner와 repository 이름만 출력되고 PAT는 출력되지 않아야 합니다.
- 바로 앞 단계의 `jq` 출력에서 `"private": true`가 보여야 합니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| 저장소 JSON에서 `"private": false`가 보임 | 저장소를 Public으로 만들었거나 잘못된 저장소를 조회함 | GitHub 저장소 설정에서 visibility를 다시 확인하고, 필요하면 새 `Private repository`를 다시 만듭니다. |
| `401 Unauthorized` | PAT 오입력, 만료, 복사 중 공백 포함 | PAT를 다시 발급하고 `read -rsp "GitHub PAT: " GITHUB_PAT`로 재입력한 뒤 다시 검증합니다. |
| `403 Forbidden` | 권한 부족 또는 선택한 저장소가 토큰 범위에 없음 | Fine-grained PAT의 repository access가 `Only select repositories`이고 `aca-runner-lab`가 선택되었는지, 권한이 `Actions | Read-only`, `Administration | Read and write`, `Metadata | Read-only`인지 확인합니다. |
| 조직 저장소인데 계속 실패 | organization token policy가 Fine-grained PAT 사용을 제한함 | 조직 owner라면 조직 정책에서 Fine-grained PAT 허용 여부를 확인하고, 허용되지 않으면 개인 owner 저장소로 실습하거나 조직 관리자와 정책을 조정합니다. |
| `jq: command not found` | Cloud Shell 세션 문제 또는 로컬 셸 사용 | Azure Cloud Shell Bash에서 다시 실행하거나 `sudo apt-get update && sudo apt-get install -y jq`를 실행한 뒤 재시도합니다. |
| 어제는 되던 PAT가 오늘 실패 | PAT 만료 | 30일 만료 정책에 맞춰 새 Fine-grained PAT를 발급하고 `GITHUB_PAT`를 다시 export합니다. |

---

[← 이전: 워크숍 개요](../README.md) | [다음: Azure 기반 리소스 준비 →](02-azure-foundation.md)
