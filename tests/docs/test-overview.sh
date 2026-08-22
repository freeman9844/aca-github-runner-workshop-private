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
  'Microsoft.Storage service endpoint' \
  'Storage firewall: default deny' \
  'standard public DNS' \
  'Storage Blob Data Contributor' \
  'GitHub, ARM, Entra ID, Azure Monitor와 Basic ACR은 public outbound를 사용합니다.'; do
  require "$text" "missing README architecture marker"
done

for text in \
  'organization-owned GitHub App' \
  'GitHub App installation' \
  'Azure Key Vault' \
  'Microsoft.KeyVault service endpoint' \
  'Key Vault firewall: default deny' \
  'Key Vault Secrets User' \
  'Azure Portal Cloud Shell Bash' \
  'trusted workflow'; do
  require "$text" "missing README GitHub App architecture marker"
done

require '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | GitHub App 설치, Azure Portal Cloud Shell file upload와 installation 범위 검증 | 30분 |' 'README Module 01 row mismatch'
require '| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | Custom VNet ACA Environment, Storage·Key Vault service endpoint와 runtime RBAC | 30분 |' 'README Module 02 row mismatch'
require '| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4개 Job의 `0 → N → 0`과 `JobName` 기반 Log Analytics 검증 | 20분 |' 'README Module 05 row mismatch'
require '| 06 | [VNet 제한 Blob 배포와 결과 확인](docs/06-azure-sample-deployment.md) | control-plane 사전 확인과 Managed Identity 기반 Blob checksum 검증 | 20분 |' 'README Module 06 row mismatch'
require '**약 150분**' 'README top-level duration mismatch'
require '|  | **워크숍 합계** |  | **150분** |' 'README module table total mismatch'
require '| 합계 | 전체 워크숍 | 150분 |' 'README schedule total mismatch'
require '> 리소스 그룹 삭제 요청은 150분 일정에 포함되지만' 'README cleanup note total mismatch'
require '이 워크숍은 Fine-grained PAT를 사용하지 않습니다.' 'README must explicitly state Fine-grained PAT is not used'
require '- [ ] GitHub App이 `aca-runner-lab` repository에만 설치되어 있습니다.' 'README completion checklist typo or contract mismatch'
require 'Module 06의 1단계에서 control-plane을 확인하고, 3단계에서 runner의 Blob data-plane 성공과 checksum 결과를 함께 해석합니다.' 'README Module 06 flow summary mismatch'
require 'GitHub App installation 또는 권한 변경은 organization 보안 정책에 따라 owner 승인 또는 재승인이 필요할 수 있습니다.' 'README missing GitHub App approval caveat'
for obsolete in \
  '- [ ] GitHub에 permanent online ephemeral runner가 남지 않습니다.' \
  'Cloud Shell에서 Step 6/7 data-plane `403`'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    fail "README still references removed module content: $obsolete"
  fi
done
for text in \
  'Module 04의 Key Vault reference synchronization/execution을 workshop delivery 전 live rehearsal로 직접 성공시켜야 합니다.' \
  '저장소 테스트만으로 증명할 수 없습니다.' \
  '모든 identity/service endpoint/subnet rule/firewall 점검이 통과했는데도 reference synchronization이 실패하면 워크숍 delivery를 중단하고 환경별 platform path를 조사하세요.' \
  '`defaultAction=Deny`를 완화하거나 성공처럼 보이는 fallback을 추가하지 마세요.'; do
  require "$text" 'README missing Key Vault service-endpoint caveat'
done

module_total_check="$(
  awk -F'|' '
    function minutes(value,    cleaned) {
      cleaned = value
      gsub(/\*\*/, "", cleaned)
      gsub(/[[:space:]]/, "", cleaned)
      sub(/분$/, "", cleaned)
      return cleaned + 0
    }
    /^## 모듈 목차$/ { in_section=1; next }
    /^## / && in_section { exit }
    !in_section || $0 !~ /^\|/ { next }
    $2 ~ /^[[:space:]]*$/ && $3 ~ /워크숍 합계/ {
      stated_total = minutes($5)
      next
    }
    $2 ~ /^[[:space:]]*#?[[:space:]]*$/ { next }
    $2 ~ /^[[:space:]]*-+[[:space:]]*$/ { next }
    $5 ~ /분/ { sum += minutes($5) }
    END {
      if (stated_total == "") {
        print "missing:module-total"
        exit 1
      }
      print sum ":" stated_total
      if (sum != stated_total) {
        exit 2
      }
    }
  ' "$README"
)" || {
  case "$module_total_check" in
    missing:module-total) fail 'README module table total row missing' ;;
    *) fail "README module table arithmetic mismatch: ${module_total_check:-unknown}" ;;
  esac
}

schedule_total_check="$(
  awk -F'|' '
    function minutes(value,    cleaned) {
      cleaned = value
      gsub(/\*\*/, "", cleaned)
      gsub(/[[:space:]]/, "", cleaned)
      sub(/분$/, "", cleaned)
      return cleaned + 0
    }
    /^## 시간표$/ { in_section=1; next }
    /^## / && in_section { exit }
    !in_section || $0 !~ /^\|/ { next }
    $2 ~ /^[[:space:]]*구간[[:space:]]*$/ { next }
    $2 ~ /^[[:space:]]*-+[[:space:]]*$/ { next }
    $2 ~ /^[[:space:]]*합계[[:space:]]*$/ {
      stated_total = minutes($4)
      next
    }
    $4 ~ /분/ { sum += minutes($4) }
    END {
      if (stated_total == "") {
        print "missing:schedule-total"
        exit 1
      }
      print sum ":" stated_total
      if (sum != stated_total) {
        exit 2
      }
    }
  ' "$README"
)" || {
  case "$schedule_total_check" in
    missing:schedule-total) fail 'README schedule total row missing' ;;
    *) fail "README schedule arithmetic mismatch: ${schedule_total_check:-unknown}" ;;
  esac
}

require '| Azure Key Vault |' 'README cost table missing Key Vault row'
require '| Virtual network service endpoint | 추가 요금 없음 |' \
  'README cost table missing service endpoint row'

for obsolete in \
  'GitHub App が' \
  'Fine-grained PAT의 organization 승인과 최소 권한 동작은 참가자의 GitHub enterprise/organization 정책에 따라 달라집니다.' \
  'Fine-grained PAT를 사용하지만' \
  'Fine-grained PAT 생성'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    fail "README contains stale approval, PAT, or timing guidance: $obsolete"
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
