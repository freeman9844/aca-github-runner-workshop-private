#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="$ROOT/README.md"
[[ -f "$README" ]] || { echo "FAIL: README.md missing" >&2; exit 1; }

for heading in \
  '# Azure Container Apps GitHub Actions Runner 워크숍' \
  '## 빠른 시작' \
  '## 두 GitHub 저장소 구분' \
  '## 아키텍처' \
  '## 학습 목표' \
  '## 사전 요구사항' \
  '## 모듈 목차' \
  '## 세션이 끊겼을 때' \
  '## 완료 기준' \
  '## 시간표' \
  '## 비용 개요' \
  '## 태깅 범례' \
  '## 트러블슈팅 색인' \
  '## 참고 자료'; do
  grep -F "$heading" "$README" >/dev/null || { echo "FAIL: missing $heading" >&2; exit 1; }
done

for module in \
  'docs/01-prerequisites-github.md' \
  'docs/02-azure-foundation.md' \
  'docs/03-runner-image.md' \
  'docs/04-event-job-keda.md' \
  'docs/05-parallel-scale-validation.md' \
  'docs/06-azure-sample-deployment.md' \
  'docs/07-security-limitations-cleanup.md'; do
  grep -F "$module" "$README" >/dev/null || { echo "FAIL: missing link $module" >&2; exit 1; }
done

for troubleshooting_doc in \
  "$ROOT/docs/01-prerequisites-github.md" \
  "$ROOT/docs/02-azure-foundation.md" \
  "$ROOT/docs/03-runner-image.md" \
  "$ROOT/docs/04-event-job-keda.md" \
  "$ROOT/docs/05-parallel-scale-validation.md" \
  "$ROOT/docs/06-azure-sample-deployment.md" \
  "$ROOT/docs/07-security-limitations-cleanup.md"; do
  grep -Fx '## 트러블슈팅' "$troubleshooting_doc" >/dev/null ||
    { echo "FAIL: $(basename "$troubleshooting_doc") must expose #트러블슈팅" >&2; exit 1; }
done

grep -F '약 120분' "$README" >/dev/null || { echo 'FAIL: README must advertise the 120-minute workshop duration' >&2; exit 1; }
grep -F 'Private repository' "$README" >/dev/null
grep -F 'Docker-in-Docker' "$README" >/dev/null
grep -F '0 → N → 0' "$README" >/dev/null
for text in \
  'VNet 통합 internal Environment' \
  'Private DNS' \
  'same Environment' \
  'internal ingress' \
  'public outbound' \
  'network type'; do
  grep -F -- "$text" "$README" >/dev/null ||
    { echo "FAIL: README missing internal networking narrative: $text" >&2; exit 1; }
done
grep -F '따라서 워크숍 runner와 KEDA는 public outbound로 GitHub API, ACR, Azure identity, ARM, Azure Monitor에 도달합니다.' "$README" >/dev/null ||
  { echo 'FAIL: README must list the complete public outbound dependency sentence' >&2; exit 1; }
grep -F 'sample app의 internal-ingress FQDN은 same Environment runner에서만 직접 검증합니다.' "$README" >/dev/null ||
  { echo 'FAIL: README must describe same-environment internal-ingress verification exactly' >&2; exit 1; }
grep -F 'standard Cloud Shell은 sample app의 internal-ingress FQDN에 직접 도달하지 못합니다.' "$README" >/dev/null ||
  { echo 'FAIL: README must describe Cloud Shell internal-ingress isolation exactly' >&2; exit 1; }
grep -F '이 워크숍에는 ACR Private Endpoint, UDR, NSG, Azure Firewall, forced tunneling, VNet-isolated Cloud Shell, NAT Gateway가 포함되지 않으며 모두 production extension입니다.' "$README" >/dev/null ||
  { echo 'FAIL: README must describe excluded enterprise controls exactly' >&2; exit 1; }
grep -F '| Azure Contributor | 실습용 Azure 리소스를 만들고 관리할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Azure RBAC 역할 할당 권한 | workshop Resource Group 또는 상위 범위에서 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. ACR 범위의 `AcrPull`과 Resource Group 범위의 `Container Apps Contributor`를 모두 할당할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| 워크숍 source 접근 | Public workshop source repository에 HTTPS로 접근할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Lab repository | 참가자 소유 Private `aca-runner-lab` repository를 만들거나 사용할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Fine-grained PAT 생성·승인 | lab repository만 선택한 Fine-grained PAT를 만들 수 있어야 하며, organization 정책이 요구하면 승인을 받아야 합니다. |' "$README" >/dev/null
grep -F 'Enterprise Managed User 또는 organization 정책에 따라 Fine-grained PAT 승인이 필요할 수 있습니다.' "$README" >/dev/null
grep -F 'Azure Cloud Shell Bash와 GitHub 웹 UI를 사용해' "$README" >/dev/null
grep -F 'base image에는 Docker CLI와 buildx가 포함되지만 ACA Jobs에는 Docker daemon과 socket이 없습니다.' "$README" >/dev/null
grep -F 'runner는 `sudo`와 `docker` 그룹에서 제거되며 entrypoint는 root 소유의 읽기·실행 전용 파일로 보호됩니다.' "$README" >/dev/null
grep -F 'Public workshop source는 GitHub CLI 로그인 없이 clone할 수 있습니다.' "$README" >/dev/null
grep -F 'git clone https://github.com/freeman9844/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop' "$README" >/dev/null
grep -F 'cd ~/aca-github-runner-workshop' "$README" >/dev/null
grep -F 'Module 01의 4단계는 이미 완료되었으며 반드시 건너뜁니다.' "$README" >/dev/null ||
  { echo 'FAIL: README Quick Start must skip the already-completed Module 01 clone step' >&2; exit 1; }
grep -F '그 외 Module 01 단계와 Module 02~07은 순서대로 모두 진행합니다. Module 07은 필수 cleanup입니다.' "$README" >/dev/null ||
  { echo 'FAIL: README Quick Start must require Modules 01 through 07' >&2; exit 1; }
grep -F '| `aca-github-runner-workshop-private` | 워크숍 문서, runner source, samples, tests | 워크숍 운영자 | source clone, 문서 확인, runner image 빌드 |' "$README" >/dev/null
grep -F '| `aca-runner-lab` | 참가자 소유 Private lab repository | 참가자(Module 01) | workflow queue, KEDA 감시, ephemeral runner 등록 |' "$README" >/dev/null
grep -F 'Fine-grained PAT는 워크숍 소스 저장소가 아니라 `aca-runner-lab`에만 scope합니다.' "$README" >/dev/null
grep -F '워크숍은 Fine-grained PAT를 사용하지만 실제 운영 환경에서는 단기 installation token을 사용하는 GitHub App 방식을 권장합니다.' "$README" >/dev/null
grep -F '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | private lab repository, Fine-grained PAT 실습과 운영용 GitHub App 권장 사항 | 15분 |' "$README" >/dev/null
grep -F '| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | VNet 통합 internal Environment, Private DNS, 저장한 `SUFFIX`, 실제 `ACR` 이름, 원래 subscription ID |' "$README" >/dev/null ||
  { echo 'FAIL: README Module 02 row must describe the VNet/internal Environment foundation' >&2; exit 1; }
grep -F '| 03 | [Runner image 빌드](docs/03-runner-image.md) | PAT 격리와 권한 제한을 적용해 ACR에 빌드한 runner image | 15분 |' "$README" >/dev/null
grep -F '| 04 | [Event Job + KEDA 구성](docs/04-event-job-keda.md) | repository-scoped ACA Event Job과 KEDA rule | 15분 |' "$README" >/dev/null
grep -F '| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4개 Job과 `0 → N → 0` 증거 | 20분 |' "$README" >/dev/null
grep -F '| 06 | [Azure 샘플 배포와 결과 확인](docs/06-azure-sample-deployment.md) | Managed Identity 기반 internal ingress sample app과 runner-internal HTTPS verification |' "$README" >/dev/null ||
  { echo 'FAIL: README Module 06 row must describe runner-internal HTTPS verification' >&2; exit 1; }
grep -F '| 07 | [보안·제약·정리](docs/07-security-limitations-cleanup.md) | 보안 검토와 확인된 cleanup | 10분 |' "$README" >/dev/null
grep -F 'VNet 통합 internal Environment, Private DNS, 저장한 `SUFFIX`, 실제 `ACR` 이름, 원래 subscription ID' "$README" >/dev/null
grep -F 'PAT 격리와 권한 제한을 적용해 ACR에 빌드한 runner image' "$README" >/dev/null
grep -F 'repository-scoped ACA Event Job과 KEDA rule' "$README" >/dev/null
grep -F 'matrix 4개 Job과 `0 → N → 0` 증거' "$README" >/dev/null
grep -F 'Managed Identity 기반 internal ingress sample app과 runner-internal HTTPS verification' "$README" >/dev/null
grep -F '보안 검토와 확인된 cleanup' "$README" >/dev/null
grep -F 'Cloud Shell의 shell 변수는 새 세션에 유지되지 않습니다.' "$README" >/dev/null
grep -F '원래 `SUFFIX`, 실제 `ACR` 이름, 원래 subscription ID' "$README" >/dev/null
grep -F 'Module 06을 이어가려면 저장해 둔 원래 subscription ID가 필요합니다.' "$README" >/dev/null
grep -F 'Module 06 완료 후 Module 07 cleanup도 반드시 수행합니다.' "$README" >/dev/null
grep -F '`0. 세션 재연결 시 변수 복구 (선택)`' "$README" >/dev/null
grep -F '새 suffix를 만들지 마세요.' "$README" >/dev/null
for text in \
  'ACR에 runner image tag가 존재합니다.' \
  '예상한 image와 repository-scoped KEDA rule' \
  'matrix 4개 Job이 모두 성공합니다.' \
  'active execution이 `0 → N → 0`으로 돌아옵니다.' \
  'runner lifecycle marker가 CLI 또는 Log Analytics에 나타납니다.' \
  'permanent online ephemeral runner가 남지 않습니다.' \
  'self-hosted runner가 Managed Identity로 Azure Container App을 배포합니다.' \
  'ACA Environment가 internal 상태입니다.' \
  'sample Container App이 `externalIngress=false` 상태입니다.' \
  'same Environment runner에서 runner-internal HTTP success와 HTTPS 검증이 확인됩니다.' \
  'standard Cloud Shell은 sample app의 internal-ingress FQDN에 직접 도달하지 못합니다.' \
  '`ResourceGroupNotFound`' \
  'lab Fine-grained PAT와 GitHub lab artifact' \
  '검증된 범위와 남은 전제' \
  '체크인된 자동 검증은 README/문서 계약과 스크립트 인터페이스를 확인합니다.' \
  'Fine-grained PAT의 organization 승인과 최소 권한 동작은 참가자의 GitHub enterprise/organization 정책에 따라 달라집니다.'; do
  grep -F -- "$text" "$README" >/dev/null ||
    { echo "FAIL: README missing completion or validation guidance: $text" >&2; exit 1; }
done
grep -F '|  | **워크숍 합계** |  | **120분** |' "$README" >/dev/null
grep -F '| 1부 | GitHub 준비 + Azure 기반 리소스 준비 | 35분 |' "$README" >/dev/null
grep -F '| 2부 | runner image 빌드 + Event Job/KEDA 구성 | 30분 |' "$README" >/dev/null
grep -F '| 4부 | Azure 샘플 배포 + same Environment HTTPS 확인 | 20분 |' "$README" >/dev/null
grep -F '| 합계 | 전체 워크숍 | 120분 |' "$README" >/dev/null
grep -F '자동 검증' "$README" >/dev/null
grep -F '`koreacentral`' "$README" >/dev/null
grep -F '`2.336.0`' "$README" >/dev/null
grep -F 'matrix 4개 Job' "$README" >/dev/null
grep -F '이미지 pull' "$README" >/dev/null
grep -F 'KEDA `0 → 4 → 0` 확장' "$README" >/dev/null
grep -F 'ephemeral runner 종료' "$README" >/dev/null
grep -F 'Log Analytics 수집' "$README" >/dev/null
grep -F '리소스 그룹 삭제' "$README" >/dev/null
grep -F '🟢 **실행**' "$README" >/dev/null
grep -F '📋 **예상 출력**' "$README" >/dev/null
for text in \
  '| workshop source clone 네트워크·URL 오류 또는 잘못된 clone 경로 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |' \
  '| Fine-grained PAT가 비어 있거나 만료·미승인 상태이거나 GitHub API가 401/403을 반환함 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |' \
  '| ACR 이름이 이미 사용 중임 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |' \
  '| 동일 repository와 label을 감시하는 Event Job이 이미 있음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |' \
  '| Event Job secret 또는 PAT 오류 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |' \
  '| `AuthorizationFailed` 또는 `HTTP verification failed after`가 배포 workflow에서 발생함 | [docs/06-azure-sample-deployment.md#트러블슈팅](docs/06-azure-sample-deployment.md#트러블슈팅) |' \
  '| standard Cloud Shell에서 sample app의 internal-ingress FQDN에 접근할 수 없음 | [docs/06-azure-sample-deployment.md#트러블슈팅](docs/06-azure-sample-deployment.md#트러블슈팅) |' \
  '| CLI 또는 Log Analytics에서 runner 로그를 찾을 수 없음 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |'; do
  grep -F -- "$text" "$README" >/dev/null ||
    { echo "FAIL: README missing troubleshooting route: $text" >&2; exit 1; }
done

DOC04="$ROOT/docs/04-event-job-keda.md"
grep -F 'internal Environment controls inbound access' "$DOC04" >/dev/null ||
  { echo 'FAIL: module 04 missing inbound-access clarification' >&2; exit 1; }
grep -F '따라서 워크숍 runner와 KEDA는 public outbound로 GitHub API, ACR, Azure identity, ARM, Azure Monitor에 도달해야 합니다.' "$DOC04" >/dev/null ||
  { echo 'FAIL: module 04 must list the complete public outbound dependency sentence' >&2; exit 1; }
grep -F '이 워크숍에는 ACR Private Endpoint, UDR, NSG, Azure Firewall, forced tunneling, NAT Gateway가 포함되지 않으며 모두 production extension입니다.' "$DOC04" >/dev/null ||
  { echo 'FAIL: module 04 must describe excluded outbound controls exactly' >&2; exit 1; }

for obsolete in \
  '기존 GitHub OAuth credential' \
  'GitHub App 생성 권한' \
  'GitHub App 설치' \
  'GitHub App private key'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    echo "FAIL: README contains obsolete authentication guidance: $obsolete" >&2
    exit 1
  fi
done

if grep -E 'GitHub App 생성 권한|라이브 Azure/GitHub App 리허설' \
  "$README" >/dev/null; then
  echo 'FAIL: README still advertises the GitHub App workshop' >&2
  exit 1
fi

if grep -F '리허설 검증' "$README" >/dev/null; then
  echo 'FAIL: README still claims a dated rehearsal validation' >&2
  exit 1
fi

if grep -F '약 105분' "$README" >/dev/null; then
  echo 'FAIL: README still advertises the old 105-minute duration' >&2
  exit 1
fi

if grep -F 'sample Container App의 HTTPS endpoint를 GitHub Actions, Cloud Shell, 브라우저, Azure Portal에서 교차 확인합니다.' \
  "$README" >/dev/null; then
  echo 'FAIL: README still claims the old four-way public HTTPS verification path' >&2
  exit 1
fi

if grep -F '라이브 Azure/GitHub 실행' "$README" >/dev/null; then
  echo 'FAIL: README still claims a live private-network rehearsal' >&2
  exit 1
fi

if grep -E '선택 Module 06|Module 06은 선택|Module 06을 건너뛰|선택적으로 추가|선택 15분|선택 Module 06 포함' \
  "$README" >/dev/null; then
  echo 'FAIL: README still describes Module 06 as optional' >&2
  exit 1
fi

if grep -E 'git clone .* ~/aca-github-runner-workshop-private([[:space:]]|$)' \
  "$README" >/dev/null; then
  echo 'FAIL: README clones into the repository-name directory instead of the workshop path' >&2
  exit 1
fi

if grep -F 'Fine-grained PAT는 `aca-github-runner-workshop-private`' \
  "$README" >/dev/null; then
  echo 'FAIL: README scopes the lab PAT to the workshop source repository' >&2
  exit 1
fi

if grep -F 'Azure Cloud Shell만 사용해' "$README" >/dev/null; then
  echo 'FAIL: README incorrectly claims the workshop uses only Cloud Shell' >&2
  exit 1
fi

if grep -E 'private workshop source|Private workshop source|gh auth login|gh auth setup-git|gh auth status' \
  "$README" >/dev/null; then
  echo 'FAIL: README still requires authentication for the public workshop source' >&2
  exit 1
fi

printf 'PASS: README contract\n'
