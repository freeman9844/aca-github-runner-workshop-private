# Azure Container Apps GitHub Actions Runner 워크숍

> Azure Cloud Shell Bash와 GitHub 웹 UI를 사용해 **약 105분** 안에 `Private repository` 전용 **repository-scoped ephemeral runner**를 만들고, Azure Container Apps Event Job과 KEDA `github-runner` scaler로 **0 → N → 0** active executions를 관찰하는 핸즈온 워크숍입니다. 참가자는 runner image 빌드, Event Job 배포, 병렬 workflow와 Log Analytics 검증, Managed Identity 기반 Azure 샘플 배포, 리소스 정리까지 한 흐름으로 완료합니다.

---

## 빠른 시작

1. Azure Portal에서 **Cloud Shell Bash**를 엽니다.
2. 브라우저 인증으로 GitHub CLI에 로그인하고 HTTPS Git credential helper를 연결합니다.

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status --hostname github.com
```

이 인증은 private workshop source를 읽기 위한 것이며, 이후 만드는
`aca-runner-lab` 전용 Fine-grained PAT와는 별개입니다.

3. 다음 명령으로 워크숍 source를 고정 경로에 clone합니다.

```bash
git clone https://github.com/freeman9844/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop
cd ~/aca-github-runner-workshop
```

4. [Module 01: GitHub 사전 준비](docs/01-prerequisites-github.md)를 엽니다. 위 Quick Start에서 clone했으므로 Module 01의 4단계는 이미 완료되었으며 반드시 건너뜁니다. 그 외 Module 01 단계와 Module 02~07은 순서대로 모두 진행합니다. Module 07은 필수 cleanup입니다.

상세 변수 설정, 예상 출력, 오류 해결 명령은 각 모듈에서 안내합니다.

---

## 두 GitHub 저장소 구분

| Repository | 역할 | 생성 주체 | 사용 위치 |
|---|---|---|---|
| `aca-github-runner-workshop-private` | 워크숍 문서, runner source, samples, tests | 워크숍 운영자 | source clone, 문서 확인, runner image 빌드 |
| `aca-runner-lab` | 참가자 소유 Private lab repository | 참가자(Module 01) | workflow queue, KEDA 감시, ephemeral runner 등록 |

Fine-grained PAT는 워크숍 소스 저장소가 아니라 `aca-runner-lab`에만 scope합니다.

---

## 아키텍처

```mermaid
flowchart LR
  user([참가자]) -->|workflow_dispatch| repo[GitHub Private Repository]
  repo -->|queued jobs| keda[KEDA github-runner scaler]
  keda -->|0..5 executions| job[ACA Event Job]
  job -->|ephemeral runner| repo
  job -->|Managed Identity login| arm[Azure Resource Manager]
  arm -->|Container Apps Contributor| sample[Sample Container App]
  sample -->|HTTPS result| user
  acr[(Azure Container Registry)] --> job
  uami[User-Assigned Managed Identity] -->|AcrPull| acr
  job -. logs .-> law[(Log Analytics)]
```

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

이 워크숍을 완료하면 다음을 할 수 있습니다.

1. GitHub와 Azure 실습 준비를 Cloud Shell 기준으로 점검할 수 있다.
2. self-hosted runner image를 이해하고 빌드할 수 있다.
3. Azure Container Apps Event Job을 배포할 수 있다.
4. KEDA `github-runner` scaler를 repository 범위로 구성할 수 있다.
5. 네 개의 병렬 workflow Job으로 scale-out 동작을 검증할 수 있다.
6. Log Analytics와 CLI로 로그를 확인하고 트러블슈팅할 수 있다.
7. Module 06에서 Managed Identity 로그인으로 샘플 Container App을 배포하고 HTTPS 결과를 검증할 수 있다.
8. 실습 리소스를 정리하고 보안·제약 사항을 점검할 수 있다.

---

## 사전 요구사항

| 항목 | 설명 |
|------|------|
| Azure Contributor | 실습용 Azure 리소스를 만들고 관리할 수 있어야 합니다. |
| Azure RBAC 역할 할당 권한 | ACR 범위에 `AcrPull`을 할당할 수 있도록 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. `Role Based Access Control Administrator`, `User Access Administrator`, `Owner` 등이 해당합니다. |
| Cloud Shell Bash | 모든 필수 단계는 Azure Cloud Shell Bash 기준으로 진행합니다. |
| GitHub account | GitHub Actions와 self-hosted runner 등록에 사용할 계정이 필요합니다. |
| Private repository 권한 | 새 `Private repository`를 만들거나 실습용 저장소에 접근할 수 있어야 합니다. |
| Fine-grained PAT 생성·승인 | lab repository만 선택한 Fine-grained PAT를 만들 수 있어야 하며, organization 정책이 요구하면 승인을 받아야 합니다. |
| 워크숍 source HTTPS 인증 | Private workshop source repository를 HTTPS로 clone할 수 있어야 합니다. |
| Lab repository | 참가자 소유 Private `aca-runner-lab` repository를 만들거나 사용할 수 있어야 합니다. |
| 기본 지식 | Azure 리소스 그룹, 컨테이너 image, GitHub Actions 기본 흐름을 알고 있으면 수월합니다. |

> Enterprise Managed User 또는 organization 정책에 따라 Fine-grained PAT 승인이 필요할 수 있습니다. Azure 리소스 생성 권한과 `Microsoft.Authorization/roleAssignments/write` 권한은 별도 요구사항입니다.

> ⚠️ **주의**
> - 이 실습은 **Private repository에서만** 진행합니다. Public repository에 self-hosted runner를 연결하면 신뢰하지 않는 코드가 실행될 수 있습니다.
> - Azure Container Apps Jobs는 **Docker-in-Docker**를 지원하지 않습니다. 따라서 workflow에서 `docker build`, Docker daemon, Docker service container 의존 단계를 사용하지 않습니다.

---

## 모듈 목차

필수 경로는 Module 01 → 07 순서로 진행합니다. Module 06의 Azure 샘플 배포와 결과 확인까지 완료한 뒤 Module 07에서 보안 검토와 cleanup을 수행합니다.

| # | 모듈 | 한 줄 설명 | 시간 |
|---|------|------------|---:|
| 00 | (현재 문서) | 전체 개요, 아키텍처, 목표, 비용, 이동 경로 | 5분 |
| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | private lab repository, 검증된 GitHub 변수와 Fine-grained PAT | 15분 |
| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | 저장한 `SUFFIX`, 실제 `ACR` 이름, 원래 subscription ID, Azure resource ID | 15분 |
| 03 | [Runner image 빌드](docs/03-runner-image.md) | ACR에 빌드된 runner image | 10분 |
| 04 | [Event Job + KEDA 구성](docs/04-event-job-keda.md) | repository-scoped ACA Event Job과 KEDA rule | 15분 |
| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4개 Job과 `0 → N → 0` 증거 | 20분 |
| 06 | [Azure 샘플 배포와 결과 확인](docs/06-azure-sample-deployment.md) | Managed Identity 기반 샘플 Container App과 HTTPS 검증 | 15분 |
| 07 | [보안·제약·정리](docs/07-security-limitations-cleanup.md) | 보안 검토와 확인된 cleanup | 10분 |
|  | **워크숍 합계** |  | **105분** |

---

## 세션이 끊겼을 때

Cloud Shell의 shell 변수는 새 세션에 유지되지 않습니다. 기존 리소스로 계속 진행하려면 원래 `SUFFIX`, 실제 `ACR` 이름, 원래 subscription ID를 보관해야 합니다. Module 06을 이어가려면 저장해 둔 원래 subscription ID가 필요합니다.

Modules 03~07에는 `0. 세션 재연결 시 변수 복구 (선택)` 영역이 있습니다. 복구가 필요할 때만 접힌 상세 내용을 펼쳐 명령을 실행하세요. 기존 실습을 이어갈 때는 새 suffix를 만들지 마세요. 새 이름은 이미 만든 리소스와 연결되지 않습니다. Module 06 완료 후 Module 07 cleanup도 반드시 수행합니다.

---

## 완료 기준

- [ ] ACR에 runner image tag가 존재합니다.
- [ ] ACA Event Job이 예상한 image와 repository-scoped KEDA rule을 사용합니다.
- [ ] matrix 4개 Job이 모두 성공합니다.
- [ ] active execution이 `0 → N → 0`으로 돌아옵니다.
- [ ] runner lifecycle marker가 CLI 또는 Log Analytics에 나타납니다.
- [ ] self-hosted runner가 Managed Identity로 Azure Container App을 배포합니다.
- [ ] sample Container App의 HTTPS endpoint를 GitHub Actions, Cloud Shell, 브라우저, Azure Portal에서 교차 확인합니다.
- [ ] GitHub에 permanent online ephemeral runner가 남지 않습니다.
- [ ] Azure cleanup 후 조회 결과가 `ResourceGroupNotFound`에 도달합니다.
- [ ] 안내에 따라 lab Fine-grained PAT와 GitHub lab artifact를 정리합니다.

---

## 시간표

| 구간 | 내용 | 예상 시간 |
|------|------|-----------|
| 시작 | 개요 및 실습 범위 확인 | 5분 |
| 1부 | GitHub 준비 + Azure 기반 리소스 준비 | 30분 |
| 2부 | runner image 빌드 + Event Job/KEDA 구성 | 25분 |
| 3부 | 병렬 workflow 검증 + 로그 확인 | 20분 |
| 4부 | Azure 샘플 배포 + HTTPS 확인 | 15분 |
| 마무리 | 보안·제약 정리 + 리소스 삭제 | 10분 |
| 합계 | 전체 워크숍 | 105분 |

> 리소스 그룹 삭제 요청은 105분 일정에 포함되지만, ACA managed environment의
> 비동기 삭제 완료는 워크숍 종료 후까지 이어질 수 있습니다.

> ✅ **검증된 범위와 남은 전제** — 체크인된 자동 검증은 README/문서 계약과 스크립트 인터페이스를 확인합니다.
> 라이브 Azure/GitHub 실행에서 `koreacentral`, runner `2.336.0`, matrix 4개 Job,
> 이미지 pull, KEDA `0 → 4 → 0` 확장, ephemeral runner 종료, Log Analytics 수집,
> 리소스 그룹 삭제를 확인했고, Module 06에서는 managed identity 로그인, 샘플
> Container App 배포, HTTPS 결과 확인을 검증했습니다. Fine-grained PAT의 organization 승인과 최소 권한 동작은 참가자의 GitHub enterprise/organization 정책에 따라 달라집니다.

---

## 비용 개요

> 실습이 끝나면 반드시 [docs/07-security-limitations-cleanup.md](docs/07-security-limitations-cleanup.md) 모듈의 정리 절차를 수행하세요. 정확한 통화 금액은 구독, 리전, 실행 시간, 로그 수집량에 따라 달라지므로 이 문서에서는 고정 비용을 약속하지 않습니다.

| 리소스 | 과금 기준 | 실습 관점 메모 |
|--------|-----------|----------------|
| ACA Consumption Event Job | Job execution 동안의 vCPU/메모리 사용 시간 | queued Job이 없을 때는 `min-executions=0`으로 active execution이 없습니다. |
| Azure Container Registry Basic | 저장 용량 + build 실행 시간 | runner image 보관과 `az acr build` 사용량이 포함됩니다. |
| Log Analytics | 로그 수집량(ingestion) | 실습 로그 확인에 필요하며, 오래 보관할수록 추가 비용이 늘 수 있습니다. |

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
| workshop source clone 인증 실패 또는 잘못된 clone 경로 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| Fine-grained PAT가 비어 있거나 만료·미승인 상태이거나 GitHub API가 401/403을 반환함 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| ACR 이름이 이미 사용 중임 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |
| workflow가 계속 queued 상태로 남음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| image pull 실패 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |
| 동일 repository와 label을 감시하는 Event Job이 이미 있음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| Event Job secret 또는 PAT 오류 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| Job execution이 생성되지 않음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| execution timeout 발생 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |
| `AuthorizationFailed` 또는 `HTTP verification failed after`가 배포 workflow에서 발생함 | [docs/06-azure-sample-deployment.md#트러블슈팅](docs/06-azure-sample-deployment.md#트러블슈팅) |
| CLI 또는 Log Analytics에서 runner 로그를 찾을 수 없음 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |
| workflow의 Docker 단계가 실패함 | [docs/07-security-limitations-cleanup.md#트러블슈팅](docs/07-security-limitations-cleanup.md#트러블슈팅) |
| runner가 GitHub에 남아 있음 | [docs/07-security-limitations-cleanup.md#트러블슈팅](docs/07-security-limitations-cleanup.md#트러블슈팅) |
| 리소스 삭제가 끝나지 않거나 실패함 | [docs/07-security-limitations-cleanup.md#트러블슈팅](docs/07-security-limitations-cleanup.md#트러블슈팅) |

---

## 참고 자료

- [Running GitHub Actions Runners on Azure Container Apps with KEDA Autoscaling](https://techcommunity.microsoft.com/blog/azureinfrastructureblog/running-github-actions-runners-on-azure-container-apps-with-keda-autoscaling/4512980)
- [Tutorial: Run GitHub Actions runners with Azure Container Apps jobs](https://learn.microsoft.com/azure/container-apps/tutorial-ci-cd-runners-jobs?pivots=container-apps-jobs-self-hosted-ci-cd-github-actions)
- [Jobs in Azure Container Apps](https://learn.microsoft.com/azure/container-apps/jobs)
- [KEDA GitHub Runner scaler](https://keda.sh/docs/latest/scalers/github-runner/)
- [Security hardening for GitHub Actions — hardening for self-hosted runners](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners)
- [참고 문서 스타일: ms-aca-basic-workshop01](https://github.com/freeman9844/ms-aca-basic-workshop01)
