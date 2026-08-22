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

require '처음 Cloud Shell을 사용하는 경우 **Mount storage account**를 선택해 영구 스토리지를 연결한 뒤 Bash를 엽니다.' 'missing README first-run storage guidance'

storage_line=$(grep -nF '처음 Cloud Shell을 사용하는 경우 **Mount storage account**를 선택해 영구 스토리지를 연결한 뒤 Bash를 엽니다.' "$README" | cut -d: -f1)
clone_line=$(grep -nF 'git clone https://github.com/freeman9844/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop' "$README" | cut -d: -f1)
[[ -n "$storage_line" && -n "$clone_line" && "$storage_line" -lt "$clone_line" ]] ||
  fail 'README must establish persistent Cloud Shell storage before cloning'

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

for text in \
  'organization-owned GitHub App' \
  'GitHub App installation' \
  'Azure Key Vault' \
  'Key Vault Private Endpoint' \
  'privatelink.vaultcore.azure.net' \
  'Key Vault Secrets User' \
  '로컬 Azure CLI' \
  'trusted workflow'; do
  require "$text" "missing README GitHub App architecture marker"
done

require '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | lab repository, organization-owned GitHub App 설치와 App installation token 흐름 이해 | 20분 |' 'README Module 01 row mismatch'
require '| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | Custom VNet ACA Environment, Blob·Key Vault Private Endpoint·Private DNS와 Storage·Key Vault RBAC | 40분 |' 'README Module 02 row mismatch'
require '| 06 | [Private Blob 배포와 결과 확인](docs/06-azure-sample-deployment.md) | Managed Identity 기반 private Blob 업로드·다운로드와 checksum 검증 | 20분 |' 'README Module 06 row mismatch'

require '| Azure Key Vault |' 'README cost table missing Key Vault row'
require '| Key Vault Private Endpoint |' 'README cost table missing Key Vault Private Endpoint row'

for obsolete in \
  'Fine-grained PAT를 사용하지만' \
  'Fine-grained PAT 생성'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    fail "README contains PAT operational guidance: $obsolete"
  fi
done

for obsolete in \
  '--internal-only ''true' \
  'ENV_DEFAULT_''DOMAIN' \
  'ENV_STATIC_''IP' \
  'same ''Environment HTTPS' \
  'internal-ingress FQDN' \
  'AZURE_SAMPLE_''APP'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    fail "README contains obsolete internal ""ACA content: $obsolete"
  fi
done

printf 'PASS: README contract\n'
