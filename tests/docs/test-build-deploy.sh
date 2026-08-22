#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message: $needle"
}

extract_objectives() {
  local doc="$1"
  awk '
    /^## 목표$/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "$doc"
}

[[ -f "$IMAGE_DOC" ]] || fail "module 03 missing"
[[ -f "$JOB_DOC" ]] || fail "module 04 missing"

IMAGE_TEXT="$(<"$IMAGE_DOC")"
JOB_TEXT="$(<"$JOB_DOC")"
ALL_TEXT="$IMAGE_TEXT
$JOB_TEXT"
IMAGE_OBJECTIVES="$(extract_objectives "$IMAGE_DOC")"
JOB_OBJECTIVES="$(extract_objectives "$JOB_DOC")"

[[ -n "$IMAGE_OBJECTIVES" ]] || fail "module 03 missing objective section"
[[ -n "$JOB_OBJECTIVES" ]] || fail "module 04 missing objective section"

for text in \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_ID=$(az storage account show' \
  'PE_SUBNET_ID=$(az network vnet subnet show'; do
  assert_contains "$ALL_TEXT" "$text" 'module 03/04 must restore private-blob variables'
done

for text in \
  '`runner/Dockerfile`과 `runner/entrypoint.sh`를 검토하고 정적 검사를 실행한다.' \
  'ACR Tasks의 `az acr build`로 runner image를 빌드하고 ACR에 게시한다.'; do
  assert_contains "$IMAGE_OBJECTIVES" "$text" 'missing module 03 objective marker'
done

for text in \
  '`github-actions-runner` container를 사용하는 ACA Event Job을 만든다.' \
  'GitHub repository, GitHub App 식별자, Key Vault secret reference를 KEDA `github-runner` scaler와 runner env에 연결한다.'; do
  assert_contains "$JOB_OBJECTIVES" "$text" 'missing module 04 objective marker'
done

for text in \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'Jobs do not support ingress' \
  '10.20.1.0/24'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 private-blob marker missing'
done

assert_contains "$IMAGE_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing module 03 optional recovery heading'
assert_contains "$JOB_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing module 04 optional recovery heading'

for obsolete in \
  '저장해 둔 `SUFFIX`와 실제 `ACR` 이름으로 모듈 02의 Azure 변수들을 복구한다.'; do
  if grep -F -- "$obsolete" <<<"$IMAGE_OBJECTIVES" >/dev/null; then
    fail "module 03 objective section still contains obsolete wording: $obsolete"
  fi
done

for obsolete in \
  '저장해 둔 `SUFFIX`와 실제 `ACR` 이름으로 Azure 변수들을 복구한다.' \
  '세션이 재시작되었더라도 GitHub owner/repo/Fine-grained PAT를 안전하게 다시 입력한다.' \
  'GitHub repository와 Fine-grained PAT를 KEDA `github-runner` scaler에 연결한다.'; do
  if grep -F -- "$obsolete" <<<"$JOB_OBJECTIVES" >/dev/null; then
    fail "module 04 objective section still contains obsolete wording: $obsolete"
  fi
done

for obsolete in \
  'AZURE_SAMPLE_''APP' \
  'internal ''Environment' \
  'same ''Environment' \
  'internal ''ingress'; do
  if grep -F -- "$obsolete" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "obsolete sample-app architecture still present: $obsolete"
  fi
done

assert_contains "$IMAGE_TEXT" '`bash tests/test-artifacts.sh`는 `PASS: workflow artifacts contract`를 출력합니다.' 'missing module 03 expected output'

for text in \
  'KEY_VAULT_SECRET_URI="https://$KEY_VAULT.vault.azure.net/secrets/$GITHUB_APP_KEY_SECRET"' \
  'applicationID=$GITHUB_APP_ID' \
  'installationID=$GITHUB_APP_INSTALLATION_ID' \
  'appKey=github-app-private-key' \
  'github-app-private-key=keyvaultref:$KEY_VAULT_SECRET_URI,identityref:$UAMI_RID' \
  'GITHUB_APP_ID=$GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key' \
  'triggerParameter: appKey' \
  'secretRef: github-app-private-key'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 GitHub App contract missing'
done

for obsolete in \
  'personalAccessToken' \
  'personal-access-token' \
  'GITHUB_PAT'; do
  if grep -F -- "$obsolete" "$JOB_DOC" >/dev/null; then
    fail "module 04 still contains obsolete PAT contract: $obsolete"
  fi
done

printf 'PASS: build and deploy docs\n'
