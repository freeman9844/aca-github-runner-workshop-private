# 01. GitHub 사전 준비

> Azure Cloud Shell Bash에서 구독, GitHub `Private repository`, repository-scoped GitHub App을 준비하고 다음 모듈에서 재사용할 `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`를 검증합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- Cloud Shell에서 실습에 사용할 Azure 구독을 선택한다.
- Azure Container Apps 관련 CLI extension과 provider 등록 상태를 맞춘다.
- `aca-runner-lab` 이름의 `Private repository`를 준비한다.
- repository-scoped GitHub App을 만들고 `aca-runner-lab`에만 설치한다.
- `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`를 안전하게 로드하고 GitHub API로 검증한다.

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

## 5. Repository-scoped GitHub App 만들기

👁️ **설명**

이 워크숍의 runner 등록 토큰 발급과 installation access token 발급은 GitHub App 인증 흐름을 사용합니다. App은 참가자의 개인 계정 또는 organization이 소유해도 되지만, 설치 대상은 반드시 실습용 `aca-runner-lab` 하나로 제한합니다.

GitHub에서 **Settings → Developer settings → GitHub Apps**로 이동한 뒤 새 App을 만들고 아래 값을 사용합니다.

| 항목 | 값 |
|---|---|
| GitHub App name | `aca-runner-lab-<unique-name>` |
| Homepage URL | 실습 repository URL |
| Webhook | **Inactive** |
| Where can this GitHub App be installed? | **Only on this account** |

🟢 **실행**

1. **GitHub Apps** 화면에서 새 App을 만듭니다.
2. App 생성 직후 아래 repository permissions를 **정확히** 설정합니다.

| Permission | Access |
|------------|--------|
| Actions | Read-only |
| Administration | Read and write |
| Metadata | Read-only |

3. **Generate a private key**를 눌러 PEM 파일을 다운로드합니다.
4. 다운로드한 PEM을 Cloud Shell에 직접 저장하거나 업로드합니다.
5. **Install App**을 선택하고 대상 owner 아래에서 **Only select repositories**를 고른 뒤 `aca-runner-lab`만 선택합니다.
6. App의 **General** 설정 화면에서 **App ID**를 확인합니다.
7. 설치 상세 화면의 URL에서 installation ID를 확인합니다.

⚠️ **주의**

- PEM 파일은 App 서명에 사용하는 민감한 credential입니다. Git에 commit하거나 터미널에 원문을 출력하지 마세요.
- App이 개인 계정 소유든 organization 소유든, 설치 범위는 `aca-runner-lab` 하나만 선택해야 합니다.
- installation settings URL은 일반적으로 `/settings/installations/<installation_id>` 형태이므로 마지막 숫자를 읽어 `GITHUB_APP_INSTALLATION_ID`로 사용합니다.

## 6. Cloud Shell 변수로 GitHub App 정보 로드

👁️ **설명**

다음 모듈에서는 owner, repository, App ID, installation ID, private key 본문을 그대로 재사용합니다. PEM 경로를 먼저 읽고 파일 존재 여부를 확인한 뒤 메모리 변수로 로드합니다.

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

printf 'GITHUB_OWNER=%s\nGITHUB_REPO=%s\nGITHUB_APP_ID=%s\nINSTALLATION_ID=%s\nPRIVATE_KEY=%s\n' \
  "$GITHUB_OWNER" \
  "$GITHUB_REPO" \
  "$GITHUB_APP_ID" \
  "$GITHUB_APP_INSTALLATION_ID" \
  "${GITHUB_APP_PRIVATE_KEY:+SET}"
```

📋 **예상 출력**

```text
GITHUB_OWNER=octocat
GITHUB_REPO=aca-runner-lab
GITHUB_APP_ID=123456
INSTALLATION_ID=78901234
PRIVATE_KEY=SET
```

- PEM 본문은 출력하지 않고 `PRIVATE_KEY=SET`만 보여야 합니다.
- 이후 같은 Cloud Shell 세션에서 다섯 변수를 그대로 재사용할 수 있습니다.

## 7. GitHub App JWT와 installation token 검증

👁️ **설명**

Task 1의 `runner/entrypoint.sh`와 동일한 흐름으로 로컬에서 JWT를 만들고 installation access token으로 교환한 뒤, 선택한 저장소를 조회해 App 설치와 권한이 올바른지 확인합니다.

🟢 **실행**

```bash
base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now="$(date +%s)"
issued_at=$((now - 60))
expires_at=$((now + 540))
header="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url)"
payload="$(
  printf '{"iat":%s,"exp":%s,"iss":"%s"}' \
    "$issued_at" "$expires_at" "$GITHUB_APP_ID" |
    base64url
)"
unsigned="$header.$payload"
signature="$(
  printf '%s' "$unsigned" |
    openssl dgst -sha256 \
      -sign <(printf '%s' "$GITHUB_APP_PRIVATE_KEY") |
    base64url
)"
APP_JWT="$unsigned.$signature"

printf -v APP_AUTH_HEADER '%s: %s %s' 'Authorization' 'Bearer' "$APP_JWT"
GITHUB_APP_INSTALLATION_TOKEN="$(
  curl --fail --silent --show-error --request POST \
    --header 'Accept: application/vnd.github+json' \
    --header "$APP_AUTH_HEADER" \
    --header 'X-GitHub-Api-Version: 2026-03-10' \
    "https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens" |
    jq --exit-status --raw-output '.token'
)"

printf -v INSTALLATION_AUTH_HEADER '%s: %s %s' \
  'Authorization' 'Bearer' "$GITHUB_APP_INSTALLATION_TOKEN"
curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$INSTALLATION_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO" |
  jq '{full_name, private, visibility}'
unset APP_AUTH_HEADER INSTALLATION_AUTH_HEADER APP_JWT
unset GITHUB_APP_INSTALLATION_TOKEN
```

📋 **예상 출력**

```json
{
  "full_name": "<owner>/<repo>",
  "private": true,
  "visibility": "private"
}
```

- 첫 번째 POST는 App JWT를 installation token으로 교환합니다.
- 두 번째 GET은 installation token으로 `aca-runner-lab` 접근 여부를 검증합니다.
- 검증 뒤 `APP_JWT`, installation token, 임시 Authorization 헤더는 모두 `unset`합니다.

## 8. 검증

🟢 **실행**

```bash
printf 'OWNER=%s REPO=%s APP_ID=%s INSTALLATION_ID=%s PRIVATE_KEY=%s\n' \
  "$GITHUB_OWNER" \
  "$GITHUB_REPO" \
  "$GITHUB_APP_ID" \
  "$GITHUB_APP_INSTALLATION_ID" \
  "${GITHUB_APP_PRIVATE_KEY:+SET}"
```

📋 **예상 출력**

- owner, repository, App ID, installation ID만 표시되고 PEM 본문은 출력되지 않아야 합니다.
- 바로 앞 단계의 `jq` 출력에서 `"private": true`가 보여야 합니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| 저장소 JSON에서 `"private": false`가 보임 | 저장소를 Public으로 만들었거나 잘못된 저장소를 조회함 | GitHub 저장소 설정에서 visibility를 다시 확인하고, 필요하면 새 `Private repository`를 다시 만듭니다. |
| `401 Unauthorized` | 잘못된 App ID, installation ID, 또는 PEM 불일치 | App 설정 화면의 App ID, 설치 URL의 installation ID, PEM을 다시 확인하고 같은 App에서 다시 발급한 키로 재시도합니다. |
| `403 Forbidden` | App이 `aca-runner-lab`에 설치되지 않았거나 필요한 권한이 승인되지 않음 | App 설치 범위가 `Only select repositories`인지, `aca-runner-lab`만 선택했는지, `Actions | Read-only`, `Administration | Read and write`, `Metadata | Read-only`가 모두 반영되었는지 확인합니다. |
| installation token 발급은 되지만 저장소 조회 실패 | App이 다른 owner에 설치되었거나 설치 권한 변경을 아직 수락하지 않음 | 해당 owner 아래 설치 대상을 다시 열어 `aca-runner-lab`가 선택되어 있는지 확인하고, permission 변경 후 필요한 승인 절차를 완료합니다. |
| PEM 파일 로드 단계에서 실패 | Cloud Shell 경로 오입력 또는 파일 업로드 누락 | `ls`와 `pwd`로 PEM 위치를 확인하고 `GITHUB_APP_PRIVATE_KEY_PATH`를 정확한 경로로 다시 입력합니다. |
| `jq: command not found` | Cloud Shell 세션 문제 또는 로컬 셸 사용 | Azure Cloud Shell Bash에서 다시 실행하거나 `sudo apt-get update && sudo apt-get install -y jq`를 실행한 뒤 재시도합니다. |

---

[← 이전: 워크숍 개요](../README.md) | [다음: Azure 기반 리소스 준비 →](02-azure-foundation.md)
