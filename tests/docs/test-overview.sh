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
  'docs/06-security-limitations-cleanup.md'; do
  grep -F "$module" "$README" >/dev/null || { echo "FAIL: missing link $module" >&2; exit 1; }
done

for troubleshooting_doc in \
  "$ROOT/docs/05-parallel-scale-validation.md" \
  "$ROOT/docs/06-security-limitations-cleanup.md"; do
  grep -Fx '## 트러블슈팅' "$troubleshooting_doc" >/dev/null ||
    { echo "FAIL: $(basename "$troubleshooting_doc") must expose #트러블슈팅" >&2; exit 1; }
done

grep -F '약 90분' "$README" >/dev/null
grep -F 'Private repository' "$README" >/dev/null
grep -F 'Docker-in-Docker' "$README" >/dev/null
grep -F '0 → N → 0' "$README" >/dev/null
grep -F '| Azure Contributor | 실습용 Azure 리소스를 만들고 관리할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Azure RBAC 역할 할당 권한 | ACR 범위에 `AcrPull`을 할당할 수 있도록 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. `Role Based Access Control Administrator`, `User Access Administrator`, `Owner` 등이 해당합니다. |' "$README" >/dev/null
grep -F '| 워크숍 source HTTPS 인증 | Private workshop source repository를 HTTPS로 clone할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Lab repository | 참가자 소유 Private `aca-runner-lab` repository를 만들거나 사용할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Fine-grained PAT 생성·승인 | lab repository만 선택한 Fine-grained PAT를 만들 수 있어야 하며, organization 정책이 요구하면 승인을 받아야 합니다. |' "$README" >/dev/null
grep -F 'Enterprise Managed User 또는 organization 정책에 따라 Fine-grained PAT 승인이 필요할 수 있습니다.' "$README" >/dev/null
grep -F 'git clone https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop' "$README" >/dev/null
grep -F 'cd ~/aca-github-runner-workshop' "$README" >/dev/null
grep -F '| `aca-github-runner-workshop-private` | 워크숍 문서, runner source, samples, tests | 워크숍 운영자 | source clone, 문서 확인, runner image 빌드 |' "$README" >/dev/null
grep -F '| `aca-runner-lab` | 참가자 소유 Private lab repository | 참가자(Module 01) | workflow queue, KEDA 감시, ephemeral runner 등록 |' "$README" >/dev/null
grep -F 'Fine-grained PAT는 워크숍 소스 저장소가 아니라 `aca-runner-lab`에만 scope합니다.' "$README" >/dev/null
grep -F '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | private lab repository, 검증된 GitHub 변수와 Fine-grained PAT | 15분 |' "$README" >/dev/null
grep -F '| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | 저장한 `SUFFIX`, 실제 `ACR` 이름, Azure resource ID | 15분 |' "$README" >/dev/null
grep -F '| 03 | [Runner image 빌드](docs/03-runner-image.md) | ACR에 빌드된 runner image | 10분 |' "$README" >/dev/null
grep -F '| 04 | [Event Job + KEDA 구성](docs/04-event-job-keda.md) | repository-scoped ACA Event Job과 KEDA rule | 15분 |' "$README" >/dev/null
grep -F '| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4개 Job과 `0 → N → 0` 증거 | 20분 |' "$README" >/dev/null
grep -F '| 06 | [보안·제약·정리](docs/06-security-limitations-cleanup.md) | 보안 검토와 확인된 cleanup | 10분 |' "$README" >/dev/null
grep -F '저장한 `SUFFIX`, 실제 `ACR` 이름, Azure resource ID' "$README" >/dev/null
grep -F 'ACR에 빌드된 runner image' "$README" >/dev/null
grep -F 'repository-scoped ACA Event Job과 KEDA rule' "$README" >/dev/null
grep -F 'matrix 4개 Job과 `0 → N → 0` 증거' "$README" >/dev/null
grep -F '보안 검토와 확인된 cleanup' "$README" >/dev/null
grep -F 'Cloud Shell의 shell 변수는 새 세션에 유지되지 않습니다.' "$README" >/dev/null
grep -F '원래 `SUFFIX`와 실제 `ACR` 이름' "$README" >/dev/null
grep -F '`0. 세션 재연결 시 변수 복구 (선택)`' "$README" >/dev/null
grep -F '새 suffix를 만들지 마세요.' "$README" >/dev/null
grep -F '|  | **합계** |  | **90분** |' "$README" >/dev/null
grep -F '| 1부 | GitHub 준비 + Azure 기반 리소스 준비 | 30분 |' "$README" >/dev/null
grep -F '| 합계 | 코어 워크숍 | 90분 |' "$README" >/dev/null
grep -F '자동 검증' "$README" >/dev/null
grep -F '라이브 Azure/GitHub 실행' "$README" >/dev/null
grep -F '기존 GitHub OAuth credential' "$README" >/dev/null
grep -F 'Fine-grained PAT의 최소권한·승인 경로는 아직 별도로 검증하지 않았습니다.' "$README" >/dev/null
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

if grep -E '약 105분|GitHub App 생성 권한|라이브 Azure/GitHub App 리허설' \
  "$README" >/dev/null; then
  echo 'FAIL: README still advertises the GitHub App workshop' >&2
  exit 1
fi

if grep -F '리허설 검증' "$README" >/dev/null; then
  echo 'FAIL: README still claims a dated rehearsal validation' >&2
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

printf 'PASS: README contract\n'
