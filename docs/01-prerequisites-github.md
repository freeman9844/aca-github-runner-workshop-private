# 01. GitHub 사전 준비

> Azure Cloud Shell Bash에서 구독, GitHub `Private repository`, Fine-grained personal access token을 준비하고 다음 모듈에서 재사용할 `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_PAT`를 검증합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- Cloud Shell에서 실습에 사용할 Azure 구독을 선택한다.
- Azure Container Apps 관련 CLI extension과 provider 등록 상태를 맞춘다.
- `aca-runner-lab` 이름의 `Private repository`를 준비한다.
- `aca-runner-lab`에만 접근 가능한 Fine-grained personal access token을 준비한다.
- `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_PAT`를 안전하게 로드하고 GitHub API로 검증한다.

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

문서, 샘플 workflow, runner 이미지 파일이 들어 있는 워크숍 소스
저장소를 지정된 경로에 clone합니다.
해당 private repository에 대한 HTTPS Git 인증이 이미 설정되어 있어야 합니다.

🟢 **실행**

```bash
git clone https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop
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

Fine-grained personal access token (PAT)을 사용해 GitHub App 설치 없이
repository-scoped 인증을 구성합니다.

GitHub에서 **Settings → Developer settings → Personal access tokens →
Fine-grained tokens → Generate new token**으로 이동합니다.

| 항목 | 값 |
|---|---|
| Token name | `aca-runner-lab` |
| Resource owner | `aca-runner-lab`을 소유한 user 또는 organization |
| Expiration | **30 days** |
| Repository access | **Only select repositories** |
| Selected repository | `aca-runner-lab` |

| Permission | Access |
|---|---|
| Actions | Read-only |
| Administration | Read and write |
| Metadata | Read-only |

- Enterprise Managed User는 개인 계정 GitHub App 설치가 금지될 수 있으므로
  이 워크숍은 App 설치를 요구하지 않습니다.
- organization 정책이 Fine-grained PAT 승인을 요구하면 승인 완료 후 다음
  단계로 진행합니다.
- enterprise 정책이 PAT 생성을 금지하면 관리자의 정책 변경 또는 승인 없이
  이 인증 경로를 진행할 수 없습니다.

## 6. Cloud Shell 변수로 PAT 안전하게 로드

👁️ **설명**

다음 모듈에서는 owner, repository, PAT를 그대로 재사용합니다. PAT 입력
프롬프트는 화면에 값을 에코하지 않고, 셸 히스토리에는 사용자가 실행한
명령문 자체만 남습니다. 토큰은 명령행 텍스트, 로그, 스크린샷, 파일에
붙여넣지 마세요.

🟢 **실행**

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rsp "Fine-grained PAT: " GITHUB_PAT
printf '\n'

export GITHUB_OWNER GITHUB_REPO GITHUB_PAT
printf 'GITHUB_OWNER=%s\nGITHUB_REPO=%s\nGITHUB_PAT=%s\n' \
  "$GITHUB_OWNER" \
  "$GITHUB_REPO" \
  "${GITHUB_PAT:+SET}"
```

📋 **예상 출력**

```text
GITHUB_OWNER=octocat
GITHUB_REPO=aca-runner-lab
GITHUB_PAT=SET
```

- PAT 원문은 출력하지 않고 `GITHUB_PAT=SET`만 보여야 합니다.
- 이후 같은 Cloud Shell 세션에서 세 변수를 그대로 재사용할 수 있습니다.

## 7. 저장소·Actions·runner administration 권한 검증

👁️ **설명**

저장소 메타데이터 읽기, GitHub Actions 읽기, self-hosted runner 등록 토큰
생성 권한을 순서대로 확인합니다. 검증 과정에서 발급되는 짧은 수명의 runner
registration token은 화면에 출력하지 않고 바로 폐기하며, `GITHUB_PAT`는
module 04에서 재사용할 수 있도록 현재 Cloud Shell 세션에 그대로 유지합니다.

🟢 **실행**

```bash
printf -v PAT_AUTH_HEADER '%s: %s %s' \
  'Authorization' 'Bearer' "$GITHUB_PAT"

curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$PAT_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO" |
  jq --exit-status '.private == true' >/dev/null
printf 'Repository access: OK\n'

curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$PAT_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runs?per_page=1" |
  jq --exit-status '.total_count >= 0' >/dev/null
printf 'Actions read: OK\n'

curl --fail --silent --show-error --request POST \
  --header 'Accept: application/vnd.github+json' \
  --header "$PAT_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token" |
  jq --exit-status '.token | type == "string" and length > 0' >/dev/null
printf 'Runner administration: OK\n'

unset PAT_AUTH_HEADER
```

📋 **예상 출력**

```text
Repository access: OK
Actions read: OK
Runner administration: OK
```

- 첫 번째 GET은 private repository 메타데이터 접근을 검증합니다.
- 두 번째 GET은 GitHub Actions 읽기 권한을 검증합니다.
- 마지막 POST는 runner registration token 생성 권한만 확인하고, 반환된 token은
  표시하지 않은 채 버립니다.
- 검증 뒤 `PAT_AUTH_HEADER`는 `unset`하고 `GITHUB_PAT`만 현재 세션에 남깁니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `401 Unauthorized` | copied token is wrong, expired, or revoked. | GitHub에서 토큰 값을 다시 복사하거나 새 Fine-grained PAT를 발급한 뒤 6단계 입력 블록을 다시 실행합니다. |
| `403 Forbidden` | organization approval is pending or enterprise policy blocks Fine-grained PAT use. | organization approval 상태를 확인하고, enterprise 정책 제한이 있으면 관리자 승인 또는 정책 변경 후 다시 시도합니다. |
| Repository check failure | wrong resource owner or selected repository. | Token의 Resource owner와 Selected repository가 `aca-runner-lab`인지 다시 확인하고, `GITHUB_OWNER`와 `GITHUB_REPO` 입력값도 함께 점검합니다. |
| Actions check failure | Actions permission is not read-only or higher. | Fine-grained PAT permission에서 Actions를 `Read-only` 이상으로 수정한 뒤 다시 검증합니다. |
| Runner administration failure | Administration is not read and write. | Fine-grained PAT permission에서 Administration을 `Read and write`로 수정한 뒤 다시 검증합니다. |
| Empty variable after reconnect | rerun the non-echoing input block. | Cloud Shell 세션이 바뀌면 export가 유지되지 않으므로 6단계의 non-echoing 입력 블록을 다시 실행합니다. |

---

[← 이전: 워크숍 개요](../README.md) | [다음: Azure 기반 리소스 준비 →](02-azure-foundation.md)
