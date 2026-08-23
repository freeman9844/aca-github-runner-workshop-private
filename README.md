# Azure Container Apps GitHub Actions Runner 워크숍

> Azure Portal Cloud Shell Bash와 GitHub 웹 UI를 사용해 **약 150분** 안에 `Private repository` 전용 **repository-scoped ephemeral runner**를 만들고, Azure Container Apps Event Job과 KEDA `github-runner` scaler로 **0 → N → 0** active executions를 관찰하는 핸즈온 워크숍입니다. 참가자는 organization-owned GitHub App 설치, runner image 빌드, **External ACA + Custom VNet + Storage·Key Vault service endpoint** foundation 배포, 병렬 workflow와 Log Analytics 검증, Managed Identity 기반 Blob artifact 배포, 리소스 정리까지 한 흐름으로 완료합니다.

---

## 빠른 시작

1. Azure Portal에서 **Cloud Shell**을 엽니다. 처음 Cloud Shell을 사용하는 경우 **Mount storage account**를 선택해 영구 스토리지를 연결한 뒤 Bash를 엽니다. 임시 **No storage account required** 세션은 재연결 시 clone과 작업 파일이 유지되지 않으므로 이 워크숍의 기본 경로로 사용하지 않습니다.
2. 다음 명령으로 Public workshop source를 고정 경로에 clone합니다. Public workshop source는 GitHub CLI 로그인 없이 clone할 수 있습니다.

```bash
git clone https://github.com/freeman9844/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop
cd ~/aca-github-runner-workshop
```

3. [Module 01: GitHub 사전 준비](docs/01-prerequisites-github.md)를 엽니다. 위 Quick Start에서 clone했으므로 Module 01의 4단계는 이미 완료되었으며 반드시 건너뜁니다. 그 외 Module 01 단계와 Module 02~07은 순서대로 모두 진행합니다. Module 07은 필수 cleanup입니다.

상세 변수 설정, 예상 출력, 오류 해결 명령은 각 모듈에서 안내합니다. 필요한 단계에는 실행 블록의 한글 주석, 실제 예상 출력, Azure와 GitHub 콘솔 참고 화면을 함께 제공합니다.

---

## 두 GitHub 저장소 구분

| Repository | 역할 | 생성 주체 | 사용 위치 |
|---|---|---|---|
| `aca-github-runner-workshop-private` | 워크숍 문서, runner source, samples, tests | 워크숍 운영자 | source clone, 문서 확인, runner image 빌드 |
| `aca-runner-lab` | 참가자 소유 Private lab repository | 참가자(Module 01) | workflow queue, KEDA 감시, ephemeral runner 등록 |

이 워크숍은 Fine-grained PAT를 사용하지 않습니다. GitHub App installation token으로 runner registration 및 removal token을 발급하며, private key PEM은 Azure Key Vault secret reference를 통해 ACA Job에 전달합니다. 이 구분은 [Module 01](docs/01-prerequisites-github.md)에서 자세히 설명합니다.

---

## 아키텍처

```mermaid
flowchart LR
  github["GitHub Actions<br/>Workflow queue"]

  subgraph rg["Azure Resource Group: rg-acarunner-{suffix}"]
    subgraph vnet["Custom VNet: 10.20.0.0/16"]
      subgraph acaSubnet["Delegated ACA subnet: 10.20.0.0/27"]
        aca["Azure Container Apps<br/>Event Job + ephemeral runner<br/>workflow job 실행"]
      end
    end

    blob["Azure Blob Storage<br/>runner-artifacts container"]

    subgraph support["Supporting resources"]
      acr["Azure Container Registry<br/>runner image"]
      kv["Azure Key Vault<br/>GitHub App private key"]
      log["Log Analytics<br/>execution logs"]
    end
  end

  aca -->|"KEDA queue polling"| github
  github -->|"queued job response"| aca
  aca -->|"Blob upload / download<br/>service endpoint"| blob
  acr -.->|"runner image pull"| aca
  kv -.->|"secret reference"| aca
  aca -.->|"console / system logs"| log
```

실선은 workflow와 Blob data-plane의 주 실행 흐름이고, 점선은 runner image, secret, log를 제공하는 보조 리소스 연결입니다.

이 워크숍의 네트워크 계약은 다음과 같습니다.

- **Custom VNet 통합 ACA Environment**는 External 타입으로 배포되지만 runner Job은 inbound endpoint를 노출하지 않습니다.
- **ACA Event Job은 ingress를 지원하지 않습니다.** 따라서 External Environment를 사용해도 Job에 public URL이나 participant-facing ingress가 생기지 않습니다.
- Storage와 Key Vault의 표준 DNS 이름은 public service IP로 해석됩니다.
- public service endpoint는 유지되지만 `defaultAction=Deny`, `bypass=None`, ACA subnet rule로 data-plane 접근을 제한합니다.
- service endpoint는 Private Link가 아니며 private IP를 만들지 않습니다.
- runner UAMI에는 Storage account scope의 **Storage Blob Data Contributor**와 Key Vault scope의 **Key Vault Secrets User** 역할만 부여합니다.
- KEDA scaler와 runner bootstrap은 organization-owned GitHub App의 App ID·Installation ID를 사용하고, private key는 Key Vault secret reference(`keyvaultref:`)로 전달합니다.
- GitHub, ARM, Entra ID, Azure Monitor와 Basic ACR은 public outbound를 사용합니다.
- 이 워크숍에는 Storage/Key Vault Private Link, Private DNS, ACR Private Endpoint, UDR, NSG, Azure Firewall, forced tunneling, NAT Gateway, VNet-isolated Cloud Shell이 포함되지 않으며 모두 production extension입니다.

이 워크숍의 코어 설정은 다음 값으로 고정합니다.

- Runner scope: `repo`
- Labels: `aca-runner`
- `min-executions=0`
- `max-executions=5`
- `polling-interval=30`
- `targetWorkflowQueueLength=1`
- `noDefaultLabels=true`

---

## 학습 목표

이 워크숍을 완료하면 다음을 할 수 있다.

1. GitHub와 Azure 실습 준비를 Cloud Shell 기준으로 점검할 수 있다.
2. organization-owned GitHub App을 설치하고, GitHub App installation token 흐름과 trusted workflow 경계를 이해할 수 있다.
3. root wrapper/non-root runner 구조와 권한 제한이 적용된 self-hosted runner image를 빌드할 수 있다.
4. Custom VNet 통합 ACA Environment, Storage·Key Vault service endpoint와 runtime RBAC 기반 Azure Container Apps Event Job foundation을 배포할 수 있다.
5. KEDA `github-runner` scaler를 GitHub App metadata와 Key Vault secret reference로 구성할 수 있다.
6. 네 개의 병렬 workflow Job으로 scale-out 동작을 검증할 수 있다.
7. Log Analytics와 CLI로 로그를 확인하고 트러블슈팅할 수 있다.
8. Custom VNet에 통합된 ACA Job에서 VNet 제한 Blob에 artifact를 배포하고, Managed Identity data-plane RBAC·upload/download checksum을 검증할 수 있다.
9. 실습 리소스를 정리하고 보안·제약 사항을 점검할 수 있다. untrusted fork PR은 이 워크숍의 trusted workflow 경계를 벗어나므로 절대 실행하지 않는다.

---

## 사전 요구사항

| 항목 | 설명 |
|------|------|
| Azure Contributor | 실습용 Azure 리소스를 만들고 관리할 수 있어야 합니다. |
| Azure RBAC 역할 할당 권한 | workshop Resource Group 또는 상위 범위에서 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. ACR 범위의 `AcrPull`, Storage account 범위의 `Storage Blob Data Contributor`, Key Vault 범위의 `Key Vault Secrets User`를 모두 할당할 수 있어야 합니다. |
| Azure Portal Cloud Shell Bash | 모든 필수 명령은 Cloud Shell에서 실행합니다. Module 01에서는 **Manage files → Upload**로 PEM을 일시적으로 올리고 Key Vault 저장 직후 자동 삭제합니다. |
| GitHub account | GitHub Actions와 self-hosted runner 등록에 사용할 계정이 필요합니다. |
| GitHub organization owner 권한 | organization-owned GitHub App을 만들고 설치하려면 organization owner 권한이 필요합니다. |
| Private repository 권한 | 새 `Private repository`를 만들거나 실습용 저장소에 접근할 수 있어야 합니다. |
| 워크숍 source 접근 | Public workshop source repository에 HTTPS로 접근할 수 있어야 합니다. |
| Lab repository | 참가자 소유 Private `aca-runner-lab` repository를 만들거나 사용할 수 있어야 합니다. |
| 기본 지식 | Azure 리소스 그룹, 컨테이너 image, GitHub Actions 기본 흐름을 알고 있으면 수월합니다. |

> ⚠️ **주의**
> - 이 실습은 **Private repository에서만** 진행합니다. Public repository에 self-hosted runner를 연결하면 신뢰하지 않는 코드가 실행될 수 있습니다.
> - base image에는 Docker CLI와 buildx가 포함되지만 ACA Jobs에는 Docker daemon과 socket이 없습니다. 따라서 **Docker-in-Docker**, `docker build`, Docker service container 의존 단계는 동작하지 않습니다.
> - runner는 `sudo`와 `docker` 그룹에서 제거되며 entrypoint는 root 소유의 읽기·실행 전용 파일로 보호됩니다. GitHub App installation token은 workflow가 시작되기 전에 단기 registration/removal token으로 교환한 뒤 제거합니다.
> - untrusted fork PR은 이 워크숍의 **trusted workflow** 경계를 벗어나므로 절대 실행하지 않습니다.

---

## 모듈 목차

필수 경로는 Module 01 → 07 순서로 진행합니다. Module 06의 VNet 제한 Blob 배포와 결과 확인까지 완료한 뒤 Module 07에서 보안 검토와 cleanup을 수행합니다.

| # | 모듈 | 한 줄 설명 | 시간 |
|---|------|------------|---:|
| 00 | (현재 문서) | 전체 개요, 아키텍처, 목표, 비용, 이동 경로 | 5분 |
| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | GitHub App 설치, Azure Portal Cloud Shell file upload와 installation 범위 검증 | 30분 |
| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | Custom VNet ACA Environment, Storage·Key Vault service endpoint와 runtime RBAC | 30분 |
| 03 | [Runner image 빌드](docs/03-runner-image.md) | root wrapper·non-root runner, App key 배포·권한 제한과 ACR image 빌드 | 15분 |
| 04 | [Event Job + KEDA 구성](docs/04-event-job-keda.md) | GitHub App scaler metadata·auth, Key Vault secret reference와 Event Job 배포 | 15분 |
| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4개 Job의 `0 → N → 0`과 `JobName` 기반 Log Analytics 검증 | 20분 |
| 06 | [VNet 제한 Blob 배포와 결과 확인](docs/06-azure-sample-deployment.md) | control-plane 사전 확인과 Managed Identity 기반 Blob checksum 검증 | 20분 |
| 07 | [보안·제약·정리](docs/07-security-limitations-cleanup.md) | trusted private workflow 경계, App 제거, 보안 검토와 확인된 cleanup | 15분 |
|  | **워크숍 합계** |  | **150분** |

Module 05는 로그 수집이 늦을 때 최대 10분 동안 30초 간격으로 실제 유입을 확인합니다.

---

## 세션이 끊겼을 때

Cloud Shell의 shell 변수는 새 세션에 유지되지 않습니다. 기존 리소스로 계속 진행하려면 원래 `SUFFIX`, 실제 `ACR` 이름, 원래 subscription ID를 보관해야 합니다. Module 06을 이어가려면 저장해 둔 실제 Storage account 이름과 subscription ID도 필요할 수 있습니다.

Modules 03~07에는 `0. 세션 재연결 시 변수 복구 (선택)` 영역이 있습니다. 복구가 필요할 때만 접힌 상세 내용을 펼쳐 명령을 실행하세요. 기존 실습을 이어갈 때는 새 suffix를 만들지 마세요. 새 이름은 이미 만든 리소스와 연결되지 않습니다. Module 06 완료 후 Module 07 cleanup도 반드시 수행합니다.

---

## 시간표

| 구간 | 내용 | 예상 시간 |
|------|------|-----------|
| 시작 | 개요 및 실습 범위 확인 | 5분 |
| 1부 | GitHub App 준비 + Azure 기반 리소스 준비 | 60분 |
| 2부 | runner image 빌드 + Event Job/KEDA 구성 | 30분 |
| 3부 | 병렬 workflow 검증 + 로그 확인 | 20분 |
| 4부 | VNet 제한 Blob 배포 + checksum 검증 | 20분 |
| 마무리 | 보안·제약 정리 + 리소스 삭제 | 15분 |
| 합계 | 전체 워크숍 | 150분 |

> 리소스 그룹 삭제 요청은 150분 일정에 포함되지만, ACA managed environment의 비동기 삭제 완료는 워크숍 종료 후까지 이어질 수 있습니다.

> ✅ **검증된 범위와 남은 전제** — 체크인된 자동 검증은 README/문서 계약과 스크립트 인터페이스를 확인합니다.
> 이 저장소는 `koreacentral`, runner `2.336.0`, matrix 4개 Job, 이미지 pull,
> KEDA `0 → 4 → 0` 확장, VNet 제한 Blob upload/download, service endpoint firewall 계약,
> ephemeral runner 종료, Log Analytics 수집, 리소스 그룹 삭제 계약을 기준으로 문서와 스크립트를 유지합니다.
> live validation은 참가자 구독의 ACA subnet service endpoint, Storage/Key Vault firewall rule, Storage data-plane RBAC 상태에 따라 Module 06 절차를 직접 재실행해야 하며,
> Module 06의 1단계에서 control-plane을 확인하고, 3단계에서 runner의 Blob data-plane 성공과 checksum 결과를 함께 해석합니다. Cloud Shell에서 같은 Blob data-plane 명령을 실행할 때 `403`이 보이는 것은 예상된 결과입니다.
> Module 04의 Key Vault reference synchronization/execution을 workshop delivery 전 live rehearsal로 직접 성공시켜야 합니다.
> 이 경로는 Microsoft 문서화가 제한적이어서 저장소 테스트만으로 증명할 수 없습니다.
> 모든 identity/service endpoint/subnet rule/firewall 점검이 통과했는데도 reference synchronization이 실패하면 워크숍 delivery를 중단하고 환경별 platform path를 조사하세요.
> `defaultAction=Deny`를 완화하거나 성공처럼 보이는 fallback을 추가하지 마세요.
> GitHub App installation 또는 권한 변경은 organization 보안 정책에 따라 owner 승인 또는 재승인이 필요할 수 있습니다.

---

## 비용 개요

> 실습이 끝나면 반드시 [docs/07-security-limitations-cleanup.md](docs/07-security-limitations-cleanup.md) 모듈의 정리 절차를 수행하세요. 정확한 통화 금액은 구독, 리전, 실행 시간, 로그 수집량에 따라 달라지므로 이 문서에서는 고정 비용을 약속하지 않습니다.

| 리소스 | 과금 기준 | 실습 관점 메모 |
|--------|-----------|----------------|
| ACA Consumption Event Job | Job execution 동안의 vCPU/메모리 사용 시간 | queued Job이 없을 때는 `min-executions=0`으로 active execution이 없습니다. |
| Azure Container Registry Basic | 저장 용량 + build 실행 시간 | runner image 보관과 `az acr build` 사용량이 포함됩니다. |
| Custom VNet | VNet과 delegated subnet 리소스 사용량 | ACA Environment와 service endpoint가 붙는 subnet 하나를 사용합니다. |
| Virtual network service endpoint | 추가 요금 없음 | Storage와 Key Vault는 ACA subnet의 service endpoint와 firewall rule로 제한합니다. |
| Azure Storage Standard LRS | 저장 용량 + 트랜잭션 | artifact container와 checksum 검증에 사용됩니다. |
| Azure Key Vault | Key Vault 리소스 사용량 + secret 버전 저장 | GitHub App private key PEM을 secret으로 보관합니다. |
| Log Analytics | 로그 수집량(ingestion) | 실습 로그 확인에 필요하며, 오래 보관할수록 추가 비용이 늘 수 있습니다. |

> 이 워크숍 비용 표에는 **Storage/Key Vault Private Link**, **Private DNS**, **ACR Private Endpoint**, **Azure Firewall**, NAT Gateway, 사용자 지정 UDR/NSG 같은 production 확장 리소스가 포함되지 않습니다. 워크숍은 service endpoint + firewall rule을 사용하고, 그 외 runner 운영 경로는 public outbound를 유지합니다.

---

## 태깅 범례

이 워크숍의 모든 문서는 아래 태그를 공통으로 사용합니다.

| 태그 | 의미 |
|------|------|
| 🟢 **실행** | 참가자가 직접 입력하거나 수행해야 하는 단계 |
| 👁️ **설명** | 개념 설명 또는 읽기 전용 안내 |
| 📋 **예상 출력** | 실행 결과와 비교할 기준 출력 |
| ⚠️ **주의** | 보안, 비용, 제약 사항 안내 |

---

## 트러블슈팅 색인

| 증상 | 바로 갈 모듈 |
|------|----------------|
| workshop source clone 네트워크·URL 오류 또는 잘못된 clone 경로 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| GitHub App이 organization에서 만들어지지 않거나 installation이 안 됨 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| GitHub App 권한 오류 또는 JWT 발급 실패 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| ACR 이름이 이미 사용 중임 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |
| Key Vault 이름 충돌 또는 soft-delete 복구 필요 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |
| workflow가 계속 queued 상태로 남음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| image pull 실패 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |
| 동일 repository와 label을 감시하는 Event Job이 이미 있음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| App installation token 발급 또는 runner registration에서 401/404가 남 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| Key Vault secret reference 오류 또는 PEM 읽기 실패 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| Job execution이 생성되지 않음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| execution timeout 발생 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |
| Blob 배포 workflow에서 네트워크 제한 또는 checksum 검증이 실패함 | [docs/06-azure-sample-deployment.md#트러블슈팅](docs/06-azure-sample-deployment.md#트러블슈팅) |
| `az storage blob upload` 또는 `az storage blob download`가 403/timeout으로 실패함 | [docs/06-azure-sample-deployment.md#트러블슈팅](docs/06-azure-sample-deployment.md#트러블슈팅) |
| `AuthorizationPermissionMismatch` 또는 `AuthorizationFailure`가 발생함 | [docs/06-azure-sample-deployment.md#트러블슈팅](docs/06-azure-sample-deployment.md#트러블슈팅) |
| 사용자 지정 NSG/UDR/Firewall 뒤에 GitHub API·ACR·Azure Monitor 접근이 막힘 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| CLI 또는 Log Analytics에서 runner 로그를 찾을 수 없음 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |
| workflow의 Docker 단계가 실패함 | [docs/07-security-limitations-cleanup.md#트러블슈팅](docs/07-security-limitations-cleanup.md#트러블슈팅) |
| runner가 GitHub에 남아 있음 | [docs/07-security-limitations-cleanup.md#트러블슈팅](docs/07-security-limitations-cleanup.md#트러블슈팅) |
| 리소스 삭제가 끝나지 않거나 실패함 | [docs/07-security-limitations-cleanup.md#트러블슈팅](docs/07-security-limitations-cleanup.md#트러블슈팅) |

---

## 참고 자료

- [Running GitHub Actions Runners on Azure Container Apps with KEDA Autoscaling](https://techcommunity.microsoft.com/blog/azureinfrastructureblog/running-github-actions-runners-on-azure-container-apps-with-keda-autoscaling/4512980)
- [Tutorial: Run GitHub Actions runners with Azure Container Apps jobs](https://learn.microsoft.com/azure/container-apps/tutorial-ci-cd-runners-jobs?pivots=container-apps-jobs-self-hosted-ci-cd-github-actions)
- [Jobs in Azure Container Apps](https://learn.microsoft.com/azure/container-apps/jobs)
- [Azure Container Apps networking](https://learn.microsoft.com/azure/container-apps/networking)
- [Virtual network configuration in Azure Container Apps environment](https://learn.microsoft.com/azure/container-apps/custom-virtual-networks)
- [Azure Storage network security](https://learn.microsoft.com/azure/storage/common/storage-network-security)
- [Virtual network service endpoints for Azure Storage](https://learn.microsoft.com/azure/storage/common/storage-network-security?tabs=azure-portal#grant-access-from-a-virtual-network)
- [Network security for Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/network-security)
- [Assign an Azure role for blob data access](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access)
- [KEDA GitHub Runner scaler](https://keda.sh/docs/latest/scalers/github-runner/)
- [Security hardening for GitHub Actions — hardening for self-hosted runners](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-self-hosted-runners)
- [참고 문서 스타일: ms-aca-basic-workshop01](https://github.com/freeman9844/ms-aca-basic-workshop01)
