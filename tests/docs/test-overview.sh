#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="$ROOT/README.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require() {
  local needle="$1"
  local context="$2"
  grep -F -- "$needle" "$README" >/dev/null || fail "$context: $needle"
}

[[ -f "$README" ]] || fail "README.md missing"

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
  require "$heading" "missing README heading"
done

for module in \
  'docs/01-prerequisites-github.md' \
  'docs/02-azure-foundation.md' \
  'docs/03-runner-image.md' \
  'docs/04-event-job-keda.md' \
  'docs/05-parallel-scale-validation.md' \
  'docs/06-azure-sample-deployment.md' \
  'docs/07-security-limitations-cleanup.md'; do
  require "$module" "missing README module link"
done

for text in \
  'Custom VNet 통합 ACA Environment' \
  'ACA Event Job은 ingress를 지원하지 않습니다.' \
  'Blob Private Endpoint' \
  'privatelink.blob.core.windows.net' \
  'Storage Blob Data Contributor' \
  'GitHub, ARM, Entra ID, Azure Monitor와 Basic ACR은 public outbound를 사용합니다.'; do
  require "$text" "missing README architecture marker"
done

require '| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | Custom VNet ACA Environment, Blob Private Endpoint·Private DNS와 Storage data-plane RBAC | 25분 |' 'README Module 02 row mismatch'
require '| 06 | [Private Blob 배포와 결과 확인](docs/06-azure-sample-deployment.md) | Managed Identity 기반 private Blob 업로드·다운로드와 checksum 검증 | 20분 |' 'README Module 06 row mismatch'

for obsolete in \
  '--internal-only true' \
  'ENV_DEFAULT_DOMAIN' \
  'ENV_STATIC_IP' \
  'same Environment HTTPS' \
  'internal-ingress FQDN' \
  'AZURE_SAMPLE_APP'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    fail "README contains obsolete internal ACA content: $obsolete"
  fi
done

printf 'PASS: README contract\n'
