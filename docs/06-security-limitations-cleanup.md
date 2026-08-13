# 06. 보안·제약·정리

> Azure Cloud Shell Bash 기준으로 이 워크숍의 보안 기본선, 운영 한계, Azure/GitHub 정리 절차를 마무리합니다. 이 모듈은 실습 구성을 그대로 운영에 올리지 않고, 어떤 지점을 production 확장으로 보완해야 하는지까지 연결해 설명합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- 워크숍 구성을 production 기준으로 어떻게 확장할지 설명할 수 있다.
- `Private repository`와 trusted workflow author 전제를 지키며 self-hosted runner 노출면을 줄일 수 있다.
- GitHub App private key, registration token, 그리고 필요 시 사용하는 보조 토큰의 `PAT 만료`/비노출 원칙을 다시 확인할 수 있다.
- Azure Container Apps Job과 GitHub runner 모델의 제약을 운영 관점에서 설명할 수 있다.
- Azure 리소스 그룹과 GitHub 측 실습 흔적을 안전하게 정리할 수 있다.

## 0. 정리 전에 변수 복구

👁️ **설명**

정리 단계는 비용을 멈추기 위해 **정확한 리소스 그룹 이름**을 다시 잡는 것이 중요합니다. 같은 Cloud Shell 세션을 계속 사용 중이라면 기존 변수를 그대로 써도 되지만, 세션이 끊겼다면 원래 저장해 둔 suffix를 다시 넣어 cleanup 대상을 복구하세요.

🟢 **실행**

```bash
SUFFIX="<your-saved-suffix>"
RG="rg-acarunner-$SUFFIX"

printf '정리 대상 RG=%s\n' "$RG"
```

suffix를 잃어버렸다면 아래처럼 워크숍이 만든 RG 후보를 먼저 나열한 뒤, 본인이 처음 사용한 이름과 대조해서 다시 설정합니다.

```bash
az group list --query "[?starts_with(name, 'rg-acarunner-')].name" --output table
```

⚠️ **주의**

- fallback 목록에서 비슷한 이름이 여러 개 보이면, 메모해 둔 원래 suffix와 대조한 뒤에만 삭제 명령을 실행하세요.
- 잘못된 RG를 지우면 다른 실습/리소스까지 함께 삭제될 수 있습니다.

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
| ACA secret의 GitHub App private key | Azure Key Vault 또는 외부 token broker | stronger key isolation and centralized rotation |
| registration token 방식 | GitHub JIT runner | reduced registration lifecycle exposure |
| Public egress | VNet, firewall, restricted egress | control reachable destinations |
| Repository runner | organization runner group | controlled reuse across repositories |
| Consumption profile | workload profiles when required | predictable dedicated capacity |

📋 **예상 출력**

- 참가자는 워크숍이 교육용 최소 구성이고, production에서는 GitHub App, Azure Key Vault, VNet, organization runner group 같은 확장이 필요하다는 점을 설명할 수 있어야 합니다.

## 2. 반드시 지킬 보안 규칙

👁️ **설명**

self-hosted runner는 GitHub Actions workflow 코드를 실제로 실행하므로, 저장소 신뢰 경계와 credential 관리 원칙이 가장 중요합니다.

⚠️ **주의**

- 이 워크숍은 **private repository only**를 전제로 합니다. `public repository`에 self-hosted runner를 연결하지 마세요.
- workflow를 수정할 수 있는 사람은 **trusted workflow authors**로 제한하세요.
- GitHub App installation은 필요한 repository에만 연결하고 permission 변경 후 installation 동의 화면을 다시 승인하세요.
- GitHub App private key PEM, registration token, remove token은 `echo`, 로그, 스크린샷, Git 기록에 출력하지 마세요.
- 보조 용도로 사람 사용자 토큰을 따로 쓰는 경우에도 **least-privilege**와 짧은 `PAT 만료` 정책을 유지하세요.
- runner image는 `ghcr.io/actions/actions-runner:2.336.0`처럼 **pinned runner image**로 고정하고 정기적으로 rebuild/scanning 하세요.
- 오래 남은 offline runner나 stale registration record는 주기적으로 삭제하세요.
- 실습에서는 ACA secret에 PEM을 저장했지만 production에서는 Azure Key Vault 또는 외부 token broker를 우선 고려하세요.

## 3. 현재 워크숍 구성의 제약 사항

👁️ **설명**

이 모듈은 “무엇이 안 되는지”를 분명히 기억하는 것이 중요합니다. 아래 제한을 알고 있어야 실습 결과를 과대해석하지 않습니다.

| 항목 | 현재 한계 | 운영 해석 |
|------|-----------|-----------|
| Docker-in-Docker | 지원하지 않음 | workflow에서 `docker build` 또는 Docker daemon 의존 단계를 넣지 않습니다. |
| service containers | Docker daemon이 필요한 service container 미지원 | DB/service container가 필요한 테스트는 다른 실행 환경을 고려합니다. |
| workspace 지속성 | execution 간 persistent workspace 없음 | 캐시나 산출물 재사용을 기본 가정으로 두지 않습니다. |
| cold start / polling | 기동 시간 + 30초 polling 지연 가능 | queued 후 즉시 execution이 보이지 않아도 정상일 수 있습니다. |
| GitHub API limits | rate limit 영향 가능 | 대규모 동시성이나 잦은 polling은 GitHub App 전환을 검토합니다. |
| KEDA version | managed KEDA version을 사용 | scaler 세부 동작을 임의 버전으로 고정하지 않습니다. |
| lab scale ceiling | maximum five lab executions | 이 워크숍은 `--max-executions 5`를 넘는 확장을 다루지 않습니다. |
| history visibility | execution history limited to recent records | 오래된 이력을 영구 기록처럼 기대하지 말고 별도 관측 체계를 둡니다. |

⚠️ **주의**

- `Docker-in-Docker` 미지원은 실습 편의 문제가 아니라 플랫폼 제약입니다.
- active execution이 0이어도 과거 execution history는 일부 recent records로 남을 수 있습니다.

## 4. Azure 리소스 정리 요청

👁️ **설명**

실습 비용을 멈추는 가장 확실한 방법은 리소스 그룹 전체를 삭제하는 것입니다. 이 워크숍의 모든 Azure 리소스는 `$RG` 아래에 있으므로 개별 삭제보다 RG 삭제를 우선합니다.

🟢 **실행**

```bash
az group delete \
  --name "$RG" \
  --yes \
  --no-wait
printf '리소스 그룹 삭제 요청됨: %s\n' "$RG"
```

📋 **예상 출력**

```text
리소스 그룹 삭제 요청됨: rg-acarunner-01234
```

- `--yes --no-wait`를 사용하므로 삭제는 비동기로 진행됩니다.
- 명령이 곧바로 반환되어도 실제 리소스 제거에는 시간이 더 걸릴 수 있습니다.

## 5. 리소스 그룹 삭제 완료 여부 확인

👁️ **설명**

비동기 삭제 요청 이후에는 조회가 실패하는 시점을 끝으로 판단합니다. `az group show`가 아직 성공하면 삭제가 진행 중이거나 lock이 남아 있을 수 있습니다.

🟢 **실행**

```bash
az group show --name "$RG" --output table
```

📋 **예상 출력**

- 삭제 진행 중에는 리소스 그룹 정보가 잠시 보일 수 있습니다.
- 삭제가 완료되면 최종적으로 아래와 비슷한 결과를 기대합니다.

```text
(ResourceGroupNotFound) Resource group 'rg-acarunner-01234' could not be found.
```

- 즉, asynchronous deletion이 끝난 뒤 `(ResourceGroupNotFound)`가 보이면 정리가 완료된 것입니다.

## 6. GitHub 측 정리 체크리스트

👁️ **설명**

Azure만 지우고 GitHub 실습 흔적을 남겨 두면 stale runner 기록이나 불필요한 token이 계속 남을 수 있습니다.

🟢 **실행**

아래 체크리스트를 순서대로 확인합니다.

1. `aca-runner-lab`에서 **GitHub App installation 삭제** 여부를 확인합니다.
2. 재사용하지 않을 계획이라면 실습용 GitHub App 자체를 삭제합니다.
3. 다운로드한 **GitHub App private key PEM 삭제**와 Cloud Shell 복사본 삭제를 완료합니다.
4. `.github/workflows/aca-runner-scale-test.yml`, stale runner record, lab repository 보존 여부를 함께 정리합니다.

⚠️ **주의**

- GitHub App installation 삭제 후에는 같은 Job secret으로 더 이상 새 registration token을 발급할 수 없습니다.
- runner가 offline으로 잠깐 보이는 것은 반영 지연일 수 있지만, 오래 남는 stale runner는 직접 정리 대상입니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `AuthorizationFailed` | 현재 Azure 계정에 RG 삭제 권한이 없음 | `az account show`로 구독을 다시 확인하고, 해당 RG에 Contributor 이상 권한이 있는 계정으로 다시 로그인합니다. |
| `az group delete` 후에도 RG가 한동안 보임 | asynchronous deletion 진행 중 | 몇 분 기다린 뒤 같은 `az group show --name "$RG" --output table`를 다시 실행합니다. 최종 기준은 `(ResourceGroupNotFound)`입니다. |
| 삭제가 계속 실패하거나 멈춤 | resource lock 존재 | 포털 또는 CLI로 delete lock/read-only lock을 확인한 뒤 해제하고 다시 시도합니다. |
| GitHub에 stale offline runner가 남음 | UI 반영 지연 또는 이전 execution metadata 잔존 | 몇 분 후 새로고침하고, 계속 남으면 runner 목록에서 stale runner를 수동 제거합니다. |
| 새 workflow가 갑자기 401/403을 반환 | GitHub App installation 삭제, PEM 교체 누락, 또는 보조 토큰의 PAT 만료 | 실습을 계속해야 한다면 GitHub App installation과 PEM/secret 동기화 상태를 먼저 확인하고, 별도로 사용하는 사람 사용자 토큰이 있다면 만료 여부도 함께 점검합니다. 이미 종료 단계라면 installation 삭제 상태를 정상으로 간주합니다. |
| 예상보다 비용이 계속 발생함 | RG 삭제 미완료, Log Analytics/ACR 등 잔존 리소스 존재 | `az group show` 결과와 Azure Portal 비용 분석을 함께 확인하고, RG가 남아 있으면 삭제 완료까지 추적합니다. |
| workflow의 Docker 단계가 실패함 | Docker-in-Docker 또는 Docker daemon/service container 의존 | 이 플랫폼 제약은 우회하지 말고, Docker daemon이 필요한 작업은 다른 runner 환경으로 분리합니다. |

## 7. 전체 워크숍 완료 확인

👁️ **설명**

아래 표로 각 모듈의 학습 산출물을 최종 점검합니다.

| 모듈 | 완료 결과 |
|------|-----------|
| 00 개요 | 아키텍처, 시간표, 비용, 학습 목표를 설명할 수 있다. |
| 01 GitHub 사전 준비 | `Private repository`, GitHub App, GitHub 변수 검증을 마쳤다. |
| 02 Azure 기반 리소스 준비 | RG, Log Analytics, ACA environment, ACR, UAMI, `AcrPull` 구성을 완료했다. |
| 03 Runner image 빌드 | runner image와 entrypoint 검증 및 ACR 빌드를 수행했다. |
| 04 Event Job + KEDA 구성 | `github-runner` scaler와 Event Job 배포를 완료했다. |
| 05 병렬 실행과 스케일 검증 | `0 → N → 0` execution 변화와 runner lifecycle marker를 확인했다. |
| 06 보안·제약·정리 | production 확장 포인트, 제한 사항, Azure/GitHub cleanup 절차를 점검했다. |

📋 **예상 출력**

- 참가자는 여섯 개 모듈을 처음부터 끝까지 연결해 설명할 수 있어야 합니다.
- Azure에서는 최종적으로 `(ResourceGroupNotFound)` 확인까지 끝내고, GitHub에서는 lab workflow/App installation/PEM/stale runner 정리 여부를 판단할 수 있어야 합니다.

---

[← 이전: 병렬 실행과 스케일 검증](05-parallel-scale-validation.md)
