# 01. GitHub 사전 준비

> Azure Cloud Shell Bash에서 구독, 조직이 소유한 GitHub `Private repository`, organization GitHub App 식별자를 준비하고 다음 모듈에서 재사용할 `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`를 검증합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- Cloud Shell을 Bash와 영구 스토리지로 처음 설정한다.
- Cloud Shell에서 실습에 사용할 Azure 구독을 선택한다.
- Azure Container Apps 관련 CLI extension과 provider 등록 상태를 맞춘다.
- 조직이 소유한 `aca-runner-lab` 이름의 `Private repository`를 준비한다.
- `aca-runner-lab` 하나에만 설치된 organization GitHub App을 준비한다.
- `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`를 Cloud Shell에 안전하게 로드하고, private key PEM 파일은 로컬 워크스테이션에만 보관한다.

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## Cloud Shell 최초 준비

Azure Portal에서 Cloud Shell을 처음 실행한다면 **Bash**와 영구 스토리지를
먼저 준비합니다. 스토리지를 연결하면 Cloud Shell 세션이 다시 만들어져도
홈 디렉터리에 clone한 워크숍 파일을 유지할 수 있습니다.

⚠️ **주의**

이 워크숍에서는 **Mount storage account**를 권장합니다.
**No storage account required**는 ephemeral session을 사용하므로 Cloud Shell
세션이 종료되면 clone한 파일이 유지되지 않을 수 있습니다.

1. [Azure Portal](https://portal.azure.com) 상단의 Cloud Shell(`>_`) 아이콘을
   선택하고 **Bash**를 선택합니다.

   ![Cloud Shell Welcome 화면에서 Bash 선택](images/01-cloudshell-step1-welcome.png)

2. **Getting started** 화면에서 **Mount storage account**를 선택합니다.
   **Storage account subscription**에서 실습에 사용할 구독을 선택한 뒤
   **Apply**를 선택합니다.

   ![Getting started 화면에서 영구 스토리지와 구독 선택](images/01-cloudshell-step2-getting-started.png)

3. **Mount storage account** 화면에서
   **We will create a storage account for you**를 선택하고 **Next**를
   선택합니다. 대상 구독에 리소스를 만들 수 있는 권한이 필요합니다.

   ![Cloud Shell 스토리지 계정 자동 생성 선택](images/01-cloudshell-step3-mount-storage.png)

4. `Requesting a Cloud Shell.Succeeded.` 메시지 뒤에 Bash 프롬프트가
   나타나면 준비가 완료된 것입니다.

   ![Cloud Shell Bash 프롬프트 준비 완료](images/01-cloudshell-step4-ready.png)

이미 ephemeral session을 선택했다면 Cloud Shell의
**Settings(⚙️) → Reset User Settings**를 선택한 후 Cloud Shell을 다시 열어
위 절차를 진행합니다.

## 1. Cloud Shell에서 Azure 구독 선택

👁️ **설명**

Cloud Shell을 열면 여러 구독이 보일 수 있습니다. 실습 리소스를 만들 구독을 먼저 고정해야 이후 명령이 의도한 구독에 배포됩니다.

🟢 **실행**

```bash
# 사용 가능한 Azure subscription을 확인하고 workshop 리소스를 만들 대상을 선택합니다.
az account list --query "[].{Name:name,SubscriptionId:id,State:state}" -o table
# 이후 모든 Azure CLI 명령이 선택한 subscription을 사용하도록 active context를 바꿉니다.
read -rp "Azure subscription ID: " SUBSCRIPTION_ID
az account set --subscription "$SUBSCRIPTION_ID"
# 잘못된 subscription에 배포하지 않도록 최종 active context를 확인합니다.
az account show --query "{Name:name,SubscriptionId:id,State:state}" -o table
```

📋 **예상 출력**

- 첫 번째 표에는 현재 로그인한 구독 목록이 보입니다.
- 마지막 표에는 방금 선택한 구독 1개만 표시되고 `State`가 `Enabled`여야 합니다.

## 2. Azure CLI extension 및 provider 준비

👁️ **설명**

이 워크숍은 Azure Container Apps Job, Azure Container Registry, Azure Monitor,
Log Analytics뿐 아니라 External ACA Environment용 Virtual Network,
delegated subnet, Blob Private Endpoint, Private DNS, Storage Account, Key Vault를 함께
사용합니다. 따라서 Cloud Shell에서 필요한 extension과 resource provider를
먼저 준비합니다. `Microsoft.Network`는 VNet, subnet, Private Endpoint,
Private DNS를 위해 필요하고, `Microsoft.ContainerService`는 ACA custom VNet
infrastructure provisioning에, `Microsoft.Storage`는 Storage Account와 Blob
Private Endpoint 생성에, `Microsoft.KeyVault`는 GitHub App private key를 보관할 Key Vault 생성에 필요합니다. `--upgrade`를 함께 지정해야 이전 버전의
`containerapp` extension이 이미 설치된 Cloud Shell에서도 워크숍 기준 버전
`0.3.55`로 실제 교체됩니다.

🟢 **실행**

```bash
# ACA 명령 형식을 workshop 기준에 맞추기 위해 containerapp extension 버전을 고정합니다.
az extension add --name containerapp --upgrade --version 0.3.55 --only-show-errors
# VNet, ACA, ACR, Storage, Key Vault, Log Analytics와 diagnostic setting 생성에 필요한 provider를 등록합니다.
az provider register -n Microsoft.Network --wait
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerService --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.KeyVault --wait
az provider register -n Microsoft.OperationalInsights --wait
az provider register -n Microsoft.Insights --wait
```

📋 **예상 출력**

- 여덟 provider 등록 명령과 extension 갱신이 오류 없이 종료됩니다.
- `--wait`를 사용했으므로 provider 상태가 `Registered`가 될 때까지 반환하지 않습니다.
- Storage Account, Private Endpoint 또는 Key Vault 생성에서 `MissingSubscriptionRegistration`이 발생하면 `Microsoft.Storage`와 `Microsoft.KeyVault` 등록 상태를 확인합니다.

## 3. GitHub에서 조직 소유 실습용 `Private repository` 만들기

👁️ **설명**

이 실습은 queued workflow Job을 self-hosted runner가 처리하므로 반드시 `Private repository`에서만 진행합니다. Public repository는 신뢰하지 않는 코드 실행 위험이 있으므로 사용하지 않습니다.

이 모듈의 전제는 **조직이 소유한 `aca-runner-lab` private repository와 해당 조직이 소유한 GitHub App**입니다. 개인 계정 저장소가 아니라 GitHub organization 아래에 lab 저장소를 만들고, 같은 organization에서 App을 생성·설치·삭제할 수 있는 계정을 사용해야 합니다.

`aca-runner-lab`은 미리 존재하는 저장소가 아니라 이 단계에서 참가자가 새로 만드는 **실습용 repository**입니다. 워크숍 문서와 runner 소스가 들어 있는 workshop repository와는 별개의 저장소이며, 이후 workflow 실행, KEDA queue 감시, self-hosted runner 등록 대상은 모두 `aca-runner-lab`입니다.

🟢 **실행**

GitHub 웹 UI에서 organization 아래에 새 저장소를 만들고 아래 값을 사용합니다.

| 설정 | 값 |
|------|----|
| Owner | GitHub organization (`Organization owner` 권한 필요) |
| Repository name | `aca-runner-lab` |
| Visibility | **Private** |
| Initialize this repository with | `README` 파일 생성 |

⚠️ **주의**

- 이 단계는 organization에 App을 설치할 수 있는 계정이 필요합니다. 저장소 생성자에게 최소한 `Organization owner` 또는 동등한 App 관리 권한이 있어야 합니다.
- 실습 중 runner를 연결할 저장소는 이 `Private repository` 하나만 선택하세요.
- 이후 단계에서 `GITHUB_OWNER`에는 organization 이름을 입력합니다.

## 4. 워크숍 소스 저장소 clone

👁️ **설명**

문서, 샘플 workflow, runner 이미지 파일이 들어 있는 워크숍 소스
저장소를 지정된 경로에 clone합니다.

이름에 `private`가 포함되어 있지만 저장소 visibility는 **Public**입니다.
따라서 Public workshop source는 GitHub CLI login 없이 clone할 수 있습니다.

🟢 **실행**

```bash
# public workshop source를 이후 모듈이 기대하는 Cloud Shell 고정 경로에 clone합니다.
git clone https://github.com/freeman9844/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop
# 상대 경로 기반 문서·runner·sample 명령이 동작하도록 clone directory로 이동합니다.
cd ~/aca-github-runner-workshop
ls
```

Public workshop source clone과 organization GitHub App 준비는 서로 다른 흐름입니다.
5단계에서 생성하는 App은 Public source clone에 사용하지 않고, `aca-runner-lab` queue
감시와 runner 등록에만 사용합니다.

📋 **예상 출력**

`ls` 결과에 최소한 다음 항목이 보여야 합니다.

- `README.md`
- `docs`
- `runner`
- `samples`
- `tests`

## 5. 조직 GitHub App 만들기

👁️ **설명**

이 워크숍은 개인 사용자 토큰 대신 organization GitHub App 설치를 사용합니다.
다음 모듈에서는 Cloud Shell의 비밀이 아닌 식별자와 로컬 워크스테이션에만 남겨 둔
private key PEM 파일을 조합해 installation access token을 발급합니다.

🟢 **실행**

개인 계정 Settings가 아니라 `aca-runner-lab` 저장소를 소유한 organization의
Settings로 이동해야 합니다.

1. GitHub 우측 상단의 프로필 사진을 선택합니다.
2. 프로필 사진 → **Your organizations** → 대상 organization의 **Settings** → **Developer settings** → **GitHub Apps** → **New GitHub App** 순서로 이동합니다.
3. 아래 값을 사용해 organization-owned App을 만듭니다.

개인 계정의 **Settings → Applications → Authorized GitHub Apps** 화면에서는 organization-owned App을 만들 수 없습니다. 이 화면이 보이면 **Your organizations**로 돌아가 대상 organization의 Settings에서 다시 시작하세요.

| 설정 | 값 |
|------|----|
| App owner | `aca-runner-lab` 저장소를 소유한 동일한 organization |
| GitHub App name | `aca-runner-lab-<unique-suffix>` |
| Homepage URL | `https://github.com/<organization>/aca-runner-lab` |
| Callback URL | 비워 둠 |
| Webhook | 비활성화 |
| User authorization callback URL | 비워 둠 |
| Request user authorization (OAuth) | 비활성화 |

다음으로 **Repository permissions**를 정확히 아래 표와 같이 설정합니다.

| Permission | Access |
|---|---|
| Metadata | Read-only |
| Actions | Read-only |
| Administration | Read and write |

그다음 App을 설치할 때 아래 값을 사용합니다.

| 설정 | 값 |
|---|---|
| Install target | `aca-runner-lab` 저장소를 소유한 organization |
| Repository access | **Only select repositories** |
| Selected repository | `aca-runner-lab` |

설치가 끝나면 아래 값을 기록합니다.

1. **App settings** 페이지에서 `App ID`를 기록합니다.
2. 설치 상세 페이지 URL의 `/settings/installations/<installation-id>` 숫자 구간에서 `Installation ID`를 기록합니다.
3. **Generate a private key**를 한 번만 실행해 PEM 파일을 다운로드합니다.
4. 다운로드된 PEM 파일의 로컬 경로를 기록하되, 다음 모듈 전까지 Cloud Shell로 복사하지 않습니다.

⚠️ **주의**

- Homepage URL은 반드시 private lab repository URL인 `https://github.com/<organization>/aca-runner-lab`이어야 합니다.
- `Only select repositories`를 유지하고 반드시 `aca-runner-lab` 하나만 선택합니다.
- private key PEM 파일은 로컬 워크스테이션에만 보관하고 Cloud Shell에 업로드하거나 Git에 commit하지 않습니다.
- PEM 파일은 다음 모듈에서 `로컬 Azure CLI` 세션이 JWT 서명에 사용할 비밀입니다.
- PEM 파일의 로컬 경로는 참가자 메모로만 유지하고 Cloud Shell 환경 변수로 추가하지 않습니다.

## 6. Cloud Shell 변수로 GitHub App 식별자만 로드

👁️ **설명**

다음 모듈에서는 owner, repository, App ID, Installation ID를 Cloud Shell에서 그대로 재사용합니다.
이 단계에서는 비밀이 아닌 식별자만 입력합니다. PEM 파일 경로와 파일 내용은 Cloud Shell에 복사하지 않습니다.

🟢 **실행**

```bash
# 다음 모듈에서 사용할 GitHub App의 비밀이 아닌 식별자를 입력합니다.
read -rp "GitHub organization: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rp "GitHub App ID: " GITHUB_APP_ID
read -rp "GitHub App Installation ID: " GITHUB_APP_INSTALLATION_ID
printf 'GITHUB_OWNER=%s\nGITHUB_REPO=%s\nGITHUB_APP_ID=%s\nGITHUB_APP_INSTALLATION_ID=%s\n' \
  "$GITHUB_OWNER" "$GITHUB_REPO" "$GITHUB_APP_ID" "$GITHUB_APP_INSTALLATION_ID"
```

📋 **예상 출력**

```text
GitHub organization: contoso
Private repository name: aca-runner-lab
GitHub App ID: 1234567
GitHub App Installation ID: 98765432
GITHUB_OWNER=contoso
GITHUB_REPO=aca-runner-lab
GITHUB_APP_ID=1234567
GITHUB_APP_INSTALLATION_ID=98765432
```

- `GITHUB_OWNER`는 개인 계정이 아니라 organization 이름이어야 합니다.
- 이 단계에서는 PEM 원문이나 경로를 출력하지 않습니다.
- 이후 같은 Cloud Shell 세션에서 네 변수를 그대로 재사용할 수 있습니다.

## 7. 다음 모듈 입력값 점검

👁️ **설명**

다음 모듈은 Cloud Shell에 저장한 네 개의 식별자와 로컬 워크스테이션에만 남겨 둔 PEM 파일을 함께 사용합니다.
Cloud Shell에서는 식별자만 유지하고, PEM 파일 검증과 JWT 서명은 로컬 Azure CLI 또는 로컬 워크스테이션 셸에서 수행합니다.

🟢 **실행**

아래 항목을 모두 확인합니다.

- `GITHUB_OWNER`가 organization 이름인지 확인합니다.
- `GITHUB_REPO`가 `aca-runner-lab`인지 확인합니다.
- `GITHUB_APP_ID`가 App settings 페이지의 값과 일치하는지 확인합니다.
- `GITHUB_APP_INSTALLATION_ID`가 `/settings/installations/` URL의 숫자와 일치하는지 확인합니다.
- PEM 파일이 로컬 워크스테이션의 안전한 경로에만 존재하는지 확인합니다.
- PEM 파일 경로 메모가 로컬 워크스테이션 또는 `로컬 Azure CLI` 세션에서만 접근 가능한지 확인합니다.
- Cloud Shell 업로드, 메신저 전송, Git commit, 저장소 체크인을 하지 않았는지 확인합니다.

📋 **예상 출력**

이 단계는 체크리스트 확인 단계입니다. 별도 명령 출력 대신 다음 상태를 만족하면 됩니다.

- Cloud Shell에는 `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`만 남아 있습니다.
- PEM 파일은 로컬 워크스테이션 또는 `로컬 Azure CLI` 세션에서만 접근할 수 있습니다.
- GitHub App 설치 범위는 `aca-runner-lab` 한 개 저장소로 제한되어 있습니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| Public workshop source clone 네트워크 또는 URL 오류 | Cloud Shell의 GitHub 연결이 차단되었거나 clone URL 대신 브라우저 URL을 사용함. | 브라우저에서 `https://github.com/freeman9844/aca-github-runner-workshop-private/tree/master` 접근 여부를 확인합니다. 브라우저의 `/tree/master` URL은 접근 확인용이며 clone URL이 아닙니다. clone에는 `https://github.com/freeman9844/aca-github-runner-workshop-private.git`을 사용합니다. organization 방화벽이나 proxy가 `github.com` HTTPS 연결을 차단한다면 네트워크 정책을 먼저 확인합니다. |
| App 생성 또는 설치 메뉴가 보이지 않음 | 현재 계정에 organization App 생성 권한이 없음 | organization의 `Organization owner` 또는 GitHub App 관리 권한이 있는 계정으로 다시 로그인하거나, 권한을 위임받은 뒤 5단계를 다시 진행합니다. |
| Installation approval pending | organization 정책상 새 App 설치에 승인이 필요함 | organization 관리자가 App 설치를 승인할 때까지 기다린 뒤 설치 상태를 다시 확인합니다. |
| 잘못된 저장소 범위에 App을 설치함 | `Only select repositories` 대신 전체 organization 또는 다른 저장소를 선택함 | App 설치 페이지로 돌아가 `Only select repositories`를 다시 선택하고 `aca-runner-lab` 하나만 남기도록 재설치하거나 설치 범위를 수정합니다. |
| runner registration 단계에서 권한 부족 오류가 발생함 | App에 `Administration` 권한이 `Read and write`로 설정되지 않음 | App의 **Repository permissions**에서 `Administration`을 `Read and write`로 수정한 뒤 설치를 새로 고치고 다음 모듈을 다시 진행합니다. |
| Enterprise Managed User 계정에서 App 설치가 차단됨 | organization 또는 enterprise 정책이 사용자 주도 App 설치를 막음 | 설치 화면에 `Install is prohibited`가 표시되면 organization 관리자에게 App 설치 또는 승인 절차를 요청합니다. |
| App ID 또는 Installation ID가 일치하지 않음 | 다른 organization, 다른 App, 다른 설치 URL을 참고함 | App settings 페이지의 `App ID`와 설치 상세 URL의 `/settings/installations/<installation-id>` 숫자를 다시 확인하고 6단계 입력 블록을 다시 실행합니다. |
| PEM 파일을 Cloud Shell에 올렸거나 저장소에 추가하려고 함 | 비밀 저장 위치를 잘못 선택함 | Cloud Shell 업로드와 commit을 즉시 중단하고, 로컬 워크스테이션에만 새 private key를 다시 생성합니다. 이전 파일은 안전하게 폐기하고 Git staging area와 히스토리에 남지 않았는지 확인합니다. |
| Storage Account, Private Endpoint 또는 Key Vault 생성에서 `MissingSubscriptionRegistration`이 발생함 | `Microsoft.Storage` 또는 `Microsoft.KeyVault` provider가 아직 등록되지 않음 | 2단계의 `az provider register -n Microsoft.Storage --wait`와 `az provider register -n Microsoft.KeyVault --wait`를 다시 실행하고 등록 완료 후 다시 시도합니다. |

---

[← 이전: 워크숍 개요](../README.md) | [다음: Azure 기반 리소스 준비 →](02-azure-foundation.md)
