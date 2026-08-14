# 06. 보안·제약·정리

> Azure Cloud Shell Bash 기준으로 이 워크숍의 보안 기본선, 운영 한계, Azure/GitHub 정리 절차를 마무리합니다. 이 모듈은 실습 구성을 그대로 운영에 올리지 않고, 어떤 지점을 production 확장으로 보완해야 하는지까지 연결해 설명합니다.

## 목표

이 모듈을 완료하면 다음을 할 수 있습니다.

- 워크숍 구성을 production 기준으로 어떻게 확장할지 설명할 수 있다.
- `Private repository`와 trusted workflow author 전제를 지키며 self-hosted runner 노출면을 줄일 수 있다.
- Fine-grained PAT permission, rotation, revoke 순서를 다시 확인할 수 있다.
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
| ACA secret의 단일 Fine-grained PAT | separate credentials, Azure Key Vault 또는 external token broker | stronger credential isolation and centralized rotation |
| registration token 방식 | GitHub JIT runner | reduced registration lifecycle exposure |
| Public egress | VNet, firewall, restricted egress | control reachable destinations |
| Repository runner | organization runner group | controlled reuse across repositories |
| Consumption profile | workload profiles when required | predictable dedicated capacity |

📋 **예상 출력**

- 참가자는 워크숍이 교육용 최소 구성이고, production에서는 separate credentials, Azure Key Vault, external token broker, VNet, organization runner group 같은 확장이 필요하다는 점을 설명할 수 있어야 합니다.

## 2. 반드시 지킬 보안 규칙

👁️ **설명**

self-hosted runner는 GitHub Actions workflow 코드를 실제로 실행하므로, 저장소 신뢰 경계와 credential 관리 원칙이 가장 중요합니다.

⚠️ **주의**

- 이 워크숍은 **private repository only**를 전제로 합니다. `public repository`에 self-hosted runner를 연결하지 마세요.
- Fine-grained PAT의 repository access는 반드시 **Only select repositories**로 제한하고 `aca-runner-lab` 같은 실습 대상 repository만 선택하세요.
- repository permission은 `Actions: Read-only`, `Administration: Read and write`, `Metadata: Read-only`만 유지하세요.
- 워크숍용 PAT는 **30 days** 만료를 선호하고, 만료 전에 rotation을 끝내세요.
- workflow를 수정할 수 있는 사람은 **trusted workflow authors**로 제한하세요.
- Fine-grained PAT, registration token, remove token은 `echo`, 로그, 스크린샷, Git 기록에 출력하지 마세요.
- runner image는 `ghcr.io/actions/actions-runner:2.336.0`처럼 **pinned runner image**로 고정하고 정기적으로 rebuild/scanning 하세요.
- 오래 남은 offline runner나 stale registration record는 주기적으로 삭제하세요.
- 실습에서는 ACA secret에 PAT를 저장했지만 production에서는 separate credentials, Azure Key Vault 또는 external token broker를 우선 고려하세요.

### PAT rotation

1. 새 Fine-grained PAT를 같은 repository와 permission으로 생성하고 필요한
   organization approval을 완료합니다.
2. ACA secret을 새 PAT로 먼저 갱신하고 Job이 queue 감시와 runner 등록을
   정상 수행하는지 확인합니다.
3. 정상 동작 확인 후 기존 PAT를 revoke합니다.

## 3. 현재 워크숍 구성의 제약 사항

👁️ **설명**

이 모듈은 “무엇이 안 되는지”를 분명히 기억하는 것이 중요합니다. 아래 제한을 알고 있어야 실습 결과를 과대해석하지 않습니다.

| 항목 | 현재 한계 | 운영 해석 |
|------|-----------|-----------|
| Docker-in-Docker | 지원하지 않음 | workflow에서 `docker build` 또는 Docker daemon 의존 단계를 넣지 않습니다. |
| service containers | Docker daemon이 필요한 service container 미지원 | DB/service container가 필요한 테스트는 다른 실행 환경을 고려합니다. |
| workspace 지속성 | execution 간 persistent workspace 없음 | 캐시나 산출물 재사용을 기본 가정으로 두지 않습니다. |
| cold start / polling | 기동 시간 + 30초 polling 지연 가능 | queued 후 즉시 execution이 보이지 않아도 정상일 수 있습니다. |
| GitHub API limits | rate limit 또는 approval policy 영향 가능 | 대규모 동시성은 separate credentials 또는 external token broker 같은 고도화 구성을 검토합니다. |
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
리소스 그룹 삭제 요청됨: rg-acarunner-a1b2c3
```

- `--yes --no-wait`를 사용하므로 삭제는 비동기로 진행됩니다.
- 명령이 곧바로 반환되어도 실제 리소스 제거에는 시간이 더 걸릴 수 있습니다.

## 5. 리소스 그룹 삭제 완료 여부 확인

👁️ **설명**

비동기 삭제 요청 이후에는 조회가 실패하는 시점을 끝으로 판단합니다. `az group show`가 아직 성공하면 삭제가 진행 중이거나 lock이 남아 있을 수 있습니다.

🟢 **실행**

```bash
az group show \
  --name "$RG" \
  --query "{name:name,state:properties.provisioningState}" \
  --output table

az resource list \
  --resource-group "$RG" \
  --query "[].{name:name,type:type}" \
  --output table
```

📋 **예상 출력**

- 삭제 진행 중에는 `properties.provisioningState`가 `Deleting`으로 보일 수
  있습니다.
- ACR, Job, identity, workspace가 먼저 사라지고 ACA managed environment가
  마지막까지 남을 수 있습니다. **ACA managed environment 삭제는 오래 걸릴 수 있습니다.**
  이 상태만으로 삭제 실패로 판단하거나 같은 이름의 리소스를 다시 만들지 마세요.
- 삭제가 완료되면 최종적으로 아래와 비슷한 결과를 기대합니다.

```text
(ResourceGroupNotFound) Resource group 'rg-acarunner-a1b2c3' could not be found.
```

- 즉, asynchronous deletion이 끝난 뒤 `(ResourceGroupNotFound)`가 보이면 정리가 완료된 것입니다.

## 6. GitHub 측 정리 체크리스트

👁️ **설명**

Azure만 지우고 GitHub 실습 흔적을 남겨 두면 stale runner 기록이나 불필요한 PAT가 계속 남을 수 있습니다.

🟢 **실행**

아래 체크리스트를 순서대로 확인합니다.

1. 실습용 Fine-grained PAT를 revoke하여 PAT 삭제를 완료합니다.
2. Cloud Shell에서 `unset GITHUB_PAT`를 실행합니다.
3. `aca-runner-lab`의 `.github/workflows/aca-runner-scale-test.yml`, stale runner record, lab repository 보존 여부를 정리합니다.

⚠️ **주의**

- PAT를 revoke한 뒤에는 같은 Job secret으로 더 이상 새 registration token을 발급할 수 없습니다.
- runner가 offline으로 잠깐 보이는 것은 반영 지연일 수 있지만, 오래 남는 stale runner는 직접 정리 대상입니다.

## 트러블슈팅

| 증상 | 주요 원인 | 해결 방법 |
|------|-----------|-----------|
| `AuthorizationFailed` | 현재 Azure 계정에 RG 삭제 권한이 없음 | `az account show`로 구독을 다시 확인하고, 해당 RG에 Contributor 이상 권한이 있는 계정으로 다시 로그인합니다. |
| `az group delete` 후에도 RG가 오래 보임 | ACA managed environment를 포함한 asynchronous deletion 진행 중 | `az group show`의 `Deleting` 상태와 `az resource list`의 잔여 리소스를 확인합니다. 오류나 lock이 없다면 기다리고, 최종 기준은 `(ResourceGroupNotFound)`입니다. |
| 삭제가 계속 실패하거나 멈춤 | resource lock 존재 | 포털 또는 CLI로 delete lock/read-only lock을 확인한 뒤 해제하고 다시 시도합니다. |
| GitHub에 stale offline runner가 남음 | UI 반영 지연 또는 이전 execution metadata 잔존 | 몇 분 후 새로고침하고, 계속 남으면 runner 목록에서 stale runner를 수동 제거합니다. |
| 새 workflow가 갑자기 401/403을 반환 | PAT가 revoked/expired 되었거나 organization approval 미완료, 또는 permission 불일치 | Fine-grained PAT가 아직 유효한지 확인하고, approval 상태와 함께 `Actions: Read-only`, `Administration: Read and write`, `Metadata: Read-only`가 유지되는지 확인합니다. |
| 예상보다 비용이 계속 발생함 | RG 삭제 미완료, Log Analytics/ACR 등 잔존 리소스 존재 | `az group show` 결과와 Azure Portal 비용 분석을 함께 확인하고, RG가 남아 있으면 삭제 완료까지 추적합니다. |
| workflow의 Docker 단계가 실패함 | Docker-in-Docker 또는 Docker daemon/service container 의존 | 이 플랫폼 제약은 우회하지 말고, Docker daemon이 필요한 작업은 다른 runner 환경으로 분리합니다. |

---

[← 이전: 병렬 실행과 스케일 검증](05-parallel-scale-validation.md)
