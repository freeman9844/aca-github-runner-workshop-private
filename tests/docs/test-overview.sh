#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="$ROOT/README.md"
[[ -f "$README" ]] || { echo "FAIL: README.md missing" >&2; exit 1; }

for heading in \
  '# Azure Container Apps GitHub Actions Runner 워크숍' \
  '## 아키텍처' \
  '## 학습 목표' \
  '## 사전 요구사항' \
  '## 모듈 목차' \
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

grep -F '약 105분' "$README" >/dev/null
grep -F 'Private repository' "$README" >/dev/null
grep -F 'Docker-in-Docker' "$README" >/dev/null
grep -F '0 → N → 0' "$README" >/dev/null
grep -F '| Azure Contributor | 실습용 Azure 리소스를 만들고 관리할 수 있어야 합니다. |' "$README" >/dev/null
grep -F '| Azure RBAC 역할 할당 권한 | ACR 범위에 `AcrPull`을 할당할 수 있도록 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. `Role Based Access Control Administrator`, `User Access Administrator`, `Owner` 등이 해당합니다. |' "$README" >/dev/null
grep -F '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | Cloud Shell 변수, `Private repository`, GitHub App 준비 | 25분 |' "$README" >/dev/null
grep -F '|  | **합계** |  | **105분** |' "$README" >/dev/null
grep -F '| 1부 | GitHub 준비 + Azure 기반 리소스 준비 | 40분 |' "$README" >/dev/null
grep -F '| 합계 | 코어 워크숍 | 105분 |' "$README" >/dev/null
grep -F '자동 검증' "$README" >/dev/null
grep -F '라이브 Azure/GitHub App 리허설' "$README" >/dev/null
grep -F '아직 별도로 수행하지 않았습니다.' "$README" >/dev/null
grep -F '`koreacentral`' "$README" >/dev/null
grep -F '`2.336.0`' "$README" >/dev/null
grep -F 'matrix 4개 Job' "$README" >/dev/null
grep -F '이미지 pull' "$README" >/dev/null
grep -F 'KEDA 확장' "$README" >/dev/null
grep -F 'ephemeral runner 종료' "$README" >/dev/null
grep -F '로그 확인' "$README" >/dev/null
grep -F '리소스 그룹 삭제' "$README" >/dev/null
grep -F 'GitHub 저장소 삭제' "$README" >/dev/null
grep -F '🟢 **실행**' "$README" >/dev/null
grep -F '📋 **예상 출력**' "$README" >/dev/null

if grep -F '약 90분' "$README" >/dev/null; then
  echo 'FAIL: README still advertises the old 90-minute timing' >&2
  exit 1
fi

if grep -F '리허설 검증' "$README" >/dev/null; then
  echo 'FAIL: README still claims a dated rehearsal validation' >&2
  exit 1
fi

printf 'PASS: README contract\n'
