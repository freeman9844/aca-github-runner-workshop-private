# 07. 보안·제약·정리

> Azure Cloud Shell Bash 기준으로 이 워크숍의 보안 기본선, 운영 한계, GitHub App private key rotation, Azure/GitHub 정리 절차를 마무리합니다. 이 모듈은 Module 02 foundation에서 만든 ACA subnet service endpoint + resource firewall 구성을 정리하며, Module 04의 Key Vault runtime proof와 Module 06의 Blob runtime proof를 production 확장 관점에서 다시 해석합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- 워크숍 구성을 production 기준으로 어떻게 확장할지 설명할 수 있다.
- `private repository`와 `trusted workflow authors` 전제를 지키며 self-hosted runner 노출면을 줄일 수 있다.
- Storage와 Key Vault가 `publicNetworkAccess=Enabled`, `defaultAction=Deny`, `bypass=None` 상태를 유지한 채 ACA subnet firewall rule과 managed identity RBAC로 보호된다는 점을 설명할 수 있다.
- service endpoint가 `Private Link`보다 단순하지만 `private IP를 만들지 않습니다`라는 점과, private-IP-only 연결이 필요할 때만 production 확장으로 넘어간다는 점을 설명할 수 있다.
- GitHub App private key rotation을 temporary IP rule + temporary role assignment 순서로 다시 설명할 수 있다.
- Azure Container Apps Job과 GitHub runner 모델의 제약을 운영 관점에서 설명할 수 있다.
- Azure 리소스 그룹과 GitHub 측 실습 흔적을 안전하게 정리할 수 있다.

## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

👁️ **설명**

정리 단계는 비용을 멈추기 위해 **정확한 리소스 그룹 이름, Job 이름, Key Vault 이름**을 다시 잡는 것이 중요합니다. 같은 Cloud Shell 세션을 계속 사용 중이라면 기존 변수를 그대로 써도 되지만, 세션이 끊겼다면 원래 저장해 둔 suffix와 subscription ID를 다시 넣어 cleanup 대상을 복구하세요.

🟢 **실행**

```bash
# 저장한 suffix와 subscription으로 cleanup 대상 RG, Job, Key Vault를 복구합니다.
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved subscription ID: " SUBSCRIPTION_ID

LOC=koreacentral
RG="rg-acarunner-$SUFFIX"
JOB="job-ghrunner-$SUFFIX"
KEY_VAULT="kvacarunner$SUFFIX"

# Key Vault 이름 충돌 복구가 있었다면 저장해 둔 실제 이름으로 덮어씁니다.
read -rp "Saved Key Vault name if changed (press Enter to keep ${KEY_VAULT}): " SAVED_KEY_VAULT
if [[ -n "$SAVED_KEY_VAULT" ]]; then
  KEY_VAULT="$SAVED_KEY_VAULT"
fi
unset SAVED_KEY_VAULT

az account set --subscription "$SUBSCRIPTION_ID"
printf 'cleanup 대상 RG=%s JOB=%s KEY_VAULT=%s LOC=%s\n' "$RG" "$JOB" "$KEY_VAULT" "$LOC"
```

suffix를 잃어버렸다면 아래처럼 워크숍이 만든 RG 후보와 Key Vault 후보를 먼저 나열한 뒤, 본인이 처음 사용한 이름과 대조해서 다시 설정합니다.

```bash
# 저장한 suffix를 잃어버렸다면 RG와 Key Vault 후보를 먼저 나열해 대상을 복구합니다.
az group list --query "[?starts_with(name, 'rg-acarunner-')].name" --output table
az keyvault list --query "[?starts_with(name, 'kvacarunner')].name" --output table
```

⚠️ **주의**

- fallback 목록에서 비슷한 이름이 여러 개 보이면, 메모해 둔 원래 suffix와 대조한 뒤에만 삭제 명령을 실행하세요.
- 잘못된 RG를 지우면 다른 실습/리소스까지 함께 삭제될 수 있습니다.

</details>

## 태그 범례

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

## 1. 워크숍 선택과 production 확장 지점 비교

👁️ **설명**

이번 실습은 학습 속도를 위해 단순화된 구성을 사용했습니다. 운영 환경에서는 아래 표를 기준으로 보안, 네트워크, 재사용성, 용량 계획을 보강하세요.

| Workshop choice | Production extension | Reason |
|---|---|---|
| External ACA Environment + custom VNet | dedicated egress design, UDR, Azure Firewall, NAT Gateway | runner/KEDA는 여전히 outbound Internet 경로가 필요하므로 destination 제어를 별도 설계해야 합니다. |
| ACA subnet service endpoints + resource firewall | Private Link, private endpoint, private DNS, centralized egress | service endpoint는 단순하지만 private IP를 만들지 않고 public service endpoint를 유지합니다. |
| Storage/Key Vault `defaultAction=Deny`, `bypass=None` | Azure Policy, access review, diagnostic automation | workshop은 ACA subnet rule 하나만 허용합니다. |
| Storage Blob Data Contributor at Storage scope | 더 세분화된 data-action role, JIT elevation, access review | foundation 단계에서는 Resource Group broad 권한 대신 artifact 저장소 범위만 열어 두는 것이 더 안전합니다. |
| one repository-scoped GitHub App + Key Vault reference | separate KEDA/runner Apps or external token broker | scaler polling과 runner bootstrap이 같은 App에 의존하므로 production에서는 credential 분리와 blast-radius 축소를 검토합니다. |
| Repository runner | organization runner group | controlled reuse across repositories |

📋 **예상 출력**

- `Workshop: one repository-scoped GitHub App + Key Vault reference`
- `Production extension: separate KEDA/runner Apps or external token broker`
- 참가자는 워크숍이 교육용 최소 구성이고, production에서는 egress control, policy, access review, separate GitHub Apps 또는 token broker 같은 확장이 필요하다는 점을 설명할 수 있어야 합니다.

## 2. 반드시 지킬 보안 규칙

👁️ **설명**

self-hosted runner는 GitHub Actions workflow 코드를 실제로 실행하므로, 저장소 신뢰 경계와 credential 관리 원칙이 가장 중요합니다. 이 워크숍의 영구 네트워크 상태는 service endpoint + resource firewall 조합입니다.

⚠️ **주의**

- 이 워크숍은 **private repository and trusted workflow authors only**를 전제로 합니다.
- untrusted `fork pull request`는 이 self-hosted runner로 절대 라우팅하지 마세요.
- Key Vault reference protects storage/configuration but does not make hostile workflow code safe.
- runner에 연결된 managed identity는 workflow code가 그대로 사용할 수 있습니다. 따라서 self-hosted runner는 **private repository**와 **trusted workflow authors**만 사용하는 경계 안에 두세요.
- runtime UAMI에는 vault scope의 `Key Vault Secrets User`만 유지하고 broad `Contributor`나 불필요한 data-plane 권한으로 넓히지 마세요.
- artifact 업로드용 RBAC는 `Storage Blob Data Contributor`를 Storage scope에만 두고, broad `Contributor`나 불필요한 RG-scope data access로 넓히지 마세요.
- App private key, App JWT, installation token, and runner tokens must never be logged.

이 워크숍에서 계속 유지해야 하는 permanent rule은 다음과 같습니다.

- Storage와 Key Vault는 `publicNetworkAccess=Enabled`를 유지합니다.
- `defaultAction=Deny`와 `bypass=None`을 유지합니다.
- 허용된 virtual network rule은 `snet-aca-infra` 하나여야 합니다.
- ACA delegated subnet에는 `Microsoft.Storage`, `Microsoft.KeyVault` service endpoint만 둡니다.
- `standard public DNS`는 public service IP를 반환하며, service endpoint는 `private IP를 만들지 않습니다`.
- data-plane 접근에는 subnet firewall rule과 managed identity RBAC가 모두 필요합니다.

service endpoint는 트래픽을 Azure backbone에 유지하고 source subnet을 식별하지만, 전용 private NIC/IP를 제공하지는 않습니다. 따라서 격리 수준은 `Private Link`보다 낮습니다. private-IP-only 연결이 필요한 환경에서는 `Private Link`가 production 확장 지점입니다.

Cloud Shell은 workshop ACA subnet 밖에 있으므로 data-plane `403`이 정상입니다. Module 04는 Key Vault runtime proof, Module 06은 Blob runtime proof이며, 두 모듈이 실제 runner 경로의 성공 증거입니다.

## 3. 현재 워크숍 구성의 제약 사항

👁️ **설명**

이 모듈은 “무엇이 안 되는지”를 분명히 기억하는 것이 중요합니다. 아래 제한을 알고 있어야 실습 결과를 과대해석하지 않습니다.

| 항목 | 현재 한계 | 운영 해석 |
|------|-----------|-----------|
| network type | ACA Environment의 `network type`은 생성 후 immutable | basic/external 기반 환경을 다른 network type으로 뒤집지 말고 새 Environment를 만듭니다. |
| Jobs do not support ingress | Event Job은 public endpoint를 만들지 않음 | External ACA Environment여도 runner Job 자체에 inbound URL이 생기지 않습니다. |
| Cloud Shell data-plane check | `Cloud Shell`은 workshop ACA subnet에 붙어 있지 않음 | Storage/Key Vault data-plane `403`은 예상된 결과이며, Module 04와 Module 06이 runtime proof입니다. |
| service endpoint isolation level | service endpoint는 dedicated private NIC/IP를 만들지 않음 | private-IP-only connectivity가 필요하면 `Private Link`를 production 확장으로 검토합니다. |
| Docker-in-Docker | 지원하지 않음 | workflow에서 `docker build` 또는 Docker daemon 의존 단계를 넣지 않습니다. |
| service containers | Docker daemon이 필요한 service container 미지원 | DB/service container가 필요한 테스트는 다른 실행 환경을 고려합니다. |
| workspace 지속성 | execution 간 persistent workspace 없음 | 캐시나 산출물 재사용을 기본 가정으로 두지 않습니다. |
| cold start / polling | 기동 시간 + 30초 polling 지연 가능 | queued 후 즉시 execution이 보이지 않아도 정상일 수 있습니다. |
| GitHub API limits | rate limit 또는 approval policy 영향 가능 | 대규모 동시성은 separate KEDA/runner Apps 또는 external token broker 같은 고도화 구성을 검토합니다. |
| KEDA version | managed KEDA version을 사용 | scaler 세부 동작을 임의 버전으로 고정하지 않습니다. |
| lab scale ceiling | maximum five lab executions | 이 워크숍은 `--max-executions 5`를 넘는 확장을 다루지 않습니다. |
| history visibility | execution history limited to recent records | 오래된 이력을 영구 기록처럼 기대하지 말고 별도 관측 체계를 둡니다. |

⚠️ **주의**

- `Jobs do not support ingress`는 실습 편의가 아니라 플랫폼 모델입니다.
- active execution이 0이어도 과거 execution history는 일부 recent records로 남을 수 있습니다.
- Cloud Shell에서 Storage/Key Vault data plane이 `403`으로 보이는 것은 workshop 경계가 정상적으로 유지된다는 뜻입니다.
- workshop foundation은 runner/KEDA의 public outbound를 그대로 사용합니다. GitHub API, ACR, Azure identity, ARM, Azure Monitor 경로를 차단하지 마세요.
- 이 워크숍에는 UDR, NSG, Azure Firewall, forced tunneling, VNet-isolated Cloud Shell이 포함되지 않으며 모두 production extension입니다.

## 4. GitHub App private key rotation을 안전한 순서로 수행하기

👁️ **설명**

이 워크숍은 `GitHub App`과 `Key Vault` reference를 함께 사용하므로 rotation 순서를 바꾸면 queue polling과 runner registration이 동시에 깨질 수 있습니다. Key Vault의 permanent 상태는 항상 `publicNetworkAccess=Enabled`, `defaultAction=Deny`, `bypass=None`이며 ACA subnet rule은 유지한 채로 temporary operator access만 추가합니다.

1. GitHub App 설정에서 **새 GitHub App private key**를 생성합니다.
2. 참가자 계정에 대해 direct `Key Vault Secrets Officer` role assignment를 만들고 assignment ID를 따로 저장합니다.
3. 아래처럼 **현재 참가자 IP**를 `/32` CIDR로 입력하고 temporary firewall rule만 추가합니다.

```bash
read -rp "Current public IPv4 CIDR for rotation (for example 203.0.113.10/32): " \
  ROTATION_CIDR
if [[ "$ROTATION_CIDR" != */32 ]]; then
  printf 'ERROR: Rotation CIDR must end with /32. Received: %s\n' \
    "$ROTATION_CIDR" >&2
  exit 1
fi

az keyvault network-rule add \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --ip-address "$ROTATION_CIDR" \
  --output none
```

4. 로컬 Azure CLI에서 `az keyvault secret set --file`로 PEM을 업로드해 **새 Key Vault secret version** URI를 저장합니다.
5. 새 PEM으로 직접 `App JWT`를 mint하고 `installation token` 요청이 실제로 성공하는지 검증합니다.
6. ACA Job secret reference를 **exact new version URI**로 바꾸고, `az containerapp job show`에서 versioned reference가 보이는지 확인한 뒤 one **successful KEDA/runner execution** canary를 실행합니다.
7. 성공이 확인되면 아래 순서로 **remove the IP rule**을 수행합니다.

```bash
az keyvault network-rule remove \
  --resource-group "$RG" \
  --name "$KEY_VAULT" \
  --ip-address "$ROTATION_CIDR"
unset ROTATION_CIDR
```

8. 2단계에서 저장한 exact temporary `Key Vault Secrets Officer` assignment ID를 삭제합니다.
9. 5~8단계가 모두 성공한 뒤에만 **기존 GitHub App private key**를 삭제합니다.
10. ACA Job secret reference를 다시 **unversioned URI**로 돌려 다음 rotation에서도 같은 절차를 반복할 수 있게 합니다.
11. 새 **local PEM file**을 삭제하고 local path variable도 unset합니다.

⚠️ **주의**

- ACA subnet virtual network rule은 지우지 마세요.
- 절대 `defaultAction=Allow`로 바꾸지 마세요.
- temporary operator access는 현재 참가자 IP rule과 temporary `Key Vault Secrets Officer` assignment 두 개뿐이어야 합니다.
- `App JWT` 성공, versioned reference 확인, canary 성공 전에 **기존 GitHub App private key**를 삭제하면 scaling과 runner registration이 동시에 깨질 수 있습니다.

## 5. cleanup 시작: GitHub App을 제거하기 전에 Job부터 삭제

👁️ **설명**

cleanup에서는 새 execution 생성부터 막아야 합니다. 따라서 `GitHub App installation`이나 `workshop 전용 GitHub App`을 먼저 지우지 말고, 먼저 ACA Job을 제거해 scaler가 더 이상 queue를 보지 못하게 하세요.

🟢 **실행**

```bash
# 새 execution 생성을 막기 위해 GitHub App을 제거하기 전에 ACA Job부터 삭제합니다.
if az containerapp job show \
  --name "$JOB" \
  --resource-group "$RG" \
  --output none 2>/dev/null; then
  az containerapp job delete \
    --name "$JOB" \
    --resource-group "$RG" \
    --yes
fi
```

📋 **예상 출력**

- Job이 존재하면 삭제 confirmation 없이 제거됩니다.
- 이미 삭제된 상태라면 아무 일도 일어나지 않고 다음 단계로 넘어가면 됩니다.

## 6. runner와 GitHub 측 실습 흔적 정리

👁️ **설명**

Job이 사라진 뒤에는 GitHub 쪽에 active runner나 설치 흔적이 남지 않았는지 순서대로 정리합니다. 여기서는 Azure 리소스를 지우기 전에 GitHub 인증 경로부터 닫습니다.

🟢 **실행**

아래 체크리스트를 순서대로 확인합니다.

1. **Settings → Actions → Runners**에서 `online/busy/stale runner`가 남지 않았는지 확인합니다.
2. `aca-runner-lab` repository에서 `GitHub App installation`을 uninstall합니다.
3. GitHub App settings에서 `workshop 전용 GitHub App` 자체를 삭제합니다.
4. Module 05/06 실습을 위해 만든 추가 workflow나 lab artifact가 더 이상 필요 없으면 함께 정리합니다.

⚠️ **주의**

- runner가 offline으로 잠깐 보이는 것은 UI 반영 지연일 수 있지만, 오래 남는 stale runner는 직접 정리 대상입니다.
- Job 삭제 전에 App installation을 먼저 제거하면 KEDA/runner 실패 로그만 늘고 cleanup 경계가 흐려질 수 있습니다.

## 7. Azure resource group 삭제 요청

👁️ **설명**

GitHub 정리가 끝나면 **Azure resource group** 삭제로 넘어갑니다. 실습 비용을 멈추는 가장 확실한 방법은 리소스 그룹 전체를 삭제하는 것입니다. 이 워크숍의 모든 Azure 리소스는 `$RG` 아래에 있으므로 개별 삭제보다 RG 삭제를 우선합니다.

Resource Group cleanup inventory는 아래 항목만 보면 됩니다.

- ACR
- ACA Job and Environment
- managed identity
- Log Analytics workspace
- VNet and delegated ACA subnet
- Storage account
- Key Vault
- provider-managed ACA infrastructure

🟢 **실행**

```bash
# workshop Resource Group의 비동기 삭제를 요청하고 요청이 접수된 이름을 기록합니다.
az group delete \
  --name "$RG" \
  --yes \
  --no-wait
printf '리소스 그룹 삭제 요청됨: %s\n' "$RG"
```

📋 **예상 출력**

```text
리소스 그룹 삭제 요청됨: rg-acarunner-a1b2c3
```

- `--yes --no-wait`를 사용하므로 삭제는 비동기로 진행됩니다.
- 명령이 곧바로 반환되어도 실제 리소스 제거에는 시간이 더 걸릴 수 있습니다.

## 8. ResourceGroupNotFound 확인, Key Vault purge, local PEM 확인

👁️ **설명**

비동기 삭제 요청 이후에는 조회가 실패하는 시점을 끝으로 판단합니다. `az group show`가 아직 성공하면 삭제가 진행 중이거나 lock이 남아 있을 수 있습니다. Key Vault는 Resource Group과 함께 삭제되더라도 seven-day soft delete가 남고 purge protection은 disabled였으므로, workshop vault는 `az keyvault purge --name "$KEY_VAULT" --location "$LOC"`로 별도 purge해야 이름 재사용과 흔적 제거가 완료됩니다.

🟢 **실행**

```bash
# ResourceGroupNotFound를 확인하고 soft-deleted Key Vault purge까지 마무리합니다.
az group show \
  --name "$RG" \
  --query "{name:name,state:properties.provisioningState}" \
  --output table

az resource list \
  --resource-group "$RG" \
  --query "[].{name:name,type:type}" \
  --output table

az keyvault purge --name "$KEY_VAULT" --location "$LOC"
```

📋 **예상 출력**

- 삭제 진행 중에는 `properties.provisioningState`가 `Deleting`으로 보일 수 있습니다.
- ACR, managed identity, workspace, VNet, Storage account, Key Vault, ACA Environment, provider-managed ACA infrastructure가 차례로 사라질 수 있습니다.
- 삭제가 완료되면 최종적으로 아래와 비슷한 결과를 기대합니다.

```text
(ResourceGroupNotFound) Resource group 'rg-acarunner-a1b2c3' could not be found.
```

- 즉, asynchronous deletion이 끝난 뒤 `(ResourceGroupNotFound)`가 보이면 Azure cleanup이 완료된 것입니다.
- purge가 끝난 뒤에는 local workstation에서도 `local PEM`이 남아 있지 않은지 마지막으로 확인하세요.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `AuthorizationFailed` | 현재 Azure 계정에 RG 삭제 또는 purge 권한이 없음 | `az account show`로 구독을 다시 확인하고, 해당 RG와 Key Vault purge에 필요한 권한이 있는 계정으로 다시 로그인합니다. |
| rotation 중 `401` 또는 `403`이 남 | 새 key 업로드는 됐지만 `App JWT`, `installation token`, App permission/approval, 또는 versioned secret reference 검증 순서가 깨짐 | 새 PEM으로 직접 JWT와 installation token을 먼저 검증하고, `az containerapp job show`에서 exact new version URI가 보이는지 확인한 뒤 canary execution을 다시 실행합니다. old key 삭제는 그 다음입니다. |
| `az keyvault secret set --file`이 실패함 | temporary `Key Vault Secrets Officer` assignment 전파 전이거나 현재 IP가 firewall에 없음 | RBAC 전파를 잠시 기다리고, 현재 참가자 IP rule이 추가되었는지 다시 확인합니다. 완료 후에는 temporary IP rule과 temporary role assignment를 모두 제거합니다. |
| Cloud Shell에서 data-plane `403`이 보임 | Cloud Shell이 workshop ACA subnet 밖에 있음 | 정상입니다. Module 04의 Key Vault runtime proof와 Module 06의 Blob runtime proof를 기준으로 runner 경로를 검증하세요. |
| GitHub에 stale offline runner가 남음 | UI 반영 지연 또는 이전 execution metadata 잔존 | 몇 분 후 새로고침하고, 계속 남으면 runner 목록에서 stale runner를 수동 제거합니다. persistent online runner가 남는 경우만 문제로 취급합니다. |
| `az group delete` 후에도 RG가 오래 보임 | ACA Environment 또는 provider-managed ACA infrastructure 삭제가 아직 진행 중 | `az group show`의 `Deleting` 상태와 `az resource list`의 잔여 리소스를 확인합니다. 오류나 lock이 없다면 기다리고, 최종 기준은 `(ResourceGroupNotFound)`입니다. |
| `az keyvault purge`가 실패함 | RG 삭제가 아직 끝나지 않았거나 soft-deleted vault가 아직 조회되지 않음 | 먼저 `ResourceGroupNotFound`를 확인하고 몇 분 더 기다린 뒤 purge를 다시 시도합니다. purge protection은 disabled이므로 soft-deleted vault가 보이면 purge가 가능합니다. |
| workflow의 Docker 단계가 실패함 | Docker-in-Docker 또는 Docker daemon/service container 의존 | 이 플랫폼 제약은 우회하지 말고, Docker daemon이 필요한 작업은 다른 runner 환경으로 분리합니다. |

---

[← 이전: Private Blob 배포와 결과 확인](06-azure-sample-deployment.md)
