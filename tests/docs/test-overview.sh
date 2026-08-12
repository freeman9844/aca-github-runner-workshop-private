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

grep -F '약 90분' "$README" >/dev/null
grep -F 'Private repository' "$README" >/dev/null
grep -F 'Docker-in-Docker' "$README" >/dev/null
grep -F '0 → N → 0' "$README" >/dev/null
grep -F '리허설 검증' "$README" >/dev/null
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

printf 'PASS: README contract\n'
