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

[[ -f "$IMAGE_DOC" ]] || fail "module 03 missing"
[[ -f "$JOB_DOC" ]] || fail "module 04 missing"

IMAGE_TEXT="$(<"$IMAGE_DOC")"
JOB_TEXT="$(<"$JOB_DOC")"
ALL_TEXT="$IMAGE_TEXT
$JOB_TEXT"

for text in \
  'STORAGE="stacarunner$SUFFIX"' \
  'STORAGE_CONTAINER="runner-artifacts"' \
  'STORAGE_ID=$(az storage account show' \
  'PE_SUBNET_ID=$(az network vnet subnet show'; do
  assert_contains "$ALL_TEXT" "$text" 'module 03/04 must restore private-blob variables'
done

for text in \
  '`runner/Dockerfile`과 `runner/entrypoint.sh`를 검토하고 정적 검사를 실행한다.' \
  'ACR Tasks의 `az acr build`로 runner image를 빌드하고 ACR에 게시한다.' \
  '`github-actions-runner` container를 사용하는 ACA Event Job을 만든다.' \
  'GitHub repository와 Fine-grained PAT를 KEDA `github-runner` scaler에 연결한다.'; do
  assert_contains "$ALL_TEXT" "$text" 'missing first-run objective marker'
done

for text in \
  'AZURE_STORAGE_ACCOUNT' \
  'AZURE_STORAGE_CONTAINER' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'Jobs do not support ingress' \
  '10.20.1.0/24'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 private-blob marker missing'
done

assert_contains "$JOB_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing optional recovery heading'

for obsolete in \
  'AZURE_SAMPLE_''APP' \
  'internal ''Environment' \
  'same ''Environment' \
  'internal ''ingress' \
  '저장해 둔 `SUFFIX`와 실제 `ACR` 이름으로 모듈 02의 Azure 변수들을 복구한다.' \
  '저장해 둔 `SUFFIX`와 실제 `ACR` 이름으로 Azure 변수들을 복구한다.' \
  '세션이 재시작되었더라도 GitHub owner/repo/Fine-grained PAT를 안전하게 다시 입력한다.' \
  'PASS: runner image and workflow artifacts'; do
  if grep -F -- "$obsolete" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "obsolete sample-app architecture still present: $obsolete"
  fi
done

assert_contains "$IMAGE_DOC" '`bash tests/test-artifacts.sh`는 `PASS: workflow artifacts contract`를 출력합니다.' 'missing module 03 expected output'

printf 'PASS: build and deploy docs\n'
