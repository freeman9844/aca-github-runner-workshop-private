#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"
JOB_PORTAL_IMAGE="$ROOT/docs/images/04-azure-portal-container-app-job.png"
JOB_EMPTY_RUNNERS_IMAGE="$ROOT/docs/images/04-github-self-hosted-runners-empty.png"

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
[[ -f "$JOB_PORTAL_IMAGE" ]] || fail "module 04 Azure Portal Container App Job image missing"
[[ "$(sha256sum "$JOB_PORTAL_IMAGE" | cut -d' ' -f1)" == "4ceb72322eb345250d7433a2b58cfa80b8906e83645445af38c337331db128f0" ]] ||
  fail "module 04 Azure Portal Container App Job image is not the approved service-endpoint foundation screenshot"
[[ ! -e "$JOB_EMPTY_RUNNERS_IMAGE" ]] || fail "module 04 obsolete empty runners image must be removed"

IMAGE_TEXT="$(<"$IMAGE_DOC")"
JOB_TEXT="$(<"$JOB_DOC")"
IMAGE_OBJECTIVES="$(extract_objectives "$IMAGE_DOC")"
JOB_OBJECTIVES="$(extract_objectives "$JOB_DOC")"

[[ -n "$IMAGE_OBJECTIVES" ]] || fail "module 03 missing objective section"
[[ -n "$JOB_OBJECTIVES" ]] || fail "module 04 missing objective section"

for obsolete in \
  '## 3. GitHub 쪽에서 미리 확인할 것' \
  '04-github-self-hosted-runners-empty.png' \
  'workflow가 queue되기 전에는 self-hosted runner가 0개인 화면이 정상입니다.'; do
  if [[ "$JOB_TEXT" == *"$obsolete"* ]]; then
    fail "module 04 still contains obsolete step 3 content: $obsolete"
  fi
done

for text in \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved ACR name: " ACR' \
  'RG="rg-acarunner-$SUFFIX"' \
  'IMAGE="github-actions-runner:2.336.0"' \
  'ACR_SERVER=$(az acr show --name "$ACR" --query loginServer --output tsv)' \
  'ACR_ID=$(az acr show --name "$ACR" --query id --output tsv)'; do
  assert_contains "$IMAGE_TEXT" "$text" 'module 03 minimal recovery contract missing'
done

for removed_text in \
  'Saved Storage account name if changed' \
  'Saved Key Vault name if changed' \
  'STORAGE_ID=$(az storage account show' \
  'KEY_VAULT_ID=$(az keyvault show' \
  'UAMI_RID=$(az identity show' \
  'LOG_ID=$(az monitor log-analytics workspace show'; do
  if grep -F -- "$removed_text" "$IMAGE_DOC" >/dev/null; then
    fail "module 03 recovery still restores unused state: $removed_text"
  fi
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
  'Jobs do not support ingress' \
  'Microsoft.Storage' \
  'Microsoft.KeyVault'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 service endpoint marker missing'
done

for text in \
  'Module 04 Key Vault reference synchronization/execution 성공이 acceptance gate입니다.' \
  'live rehearsal' \
  '저장소 테스트만으로 증명할 수 없습니다.' \
  '모든 identity/service endpoint/subnet rule/firewall 점검이 통과했는데도 reference synchronization이 실패하면 워크숍 delivery를 중단하고 환경별 platform path를 조사하세요.' \
  '`defaultAction=Deny`를 완화하거나 성공처럼 보이는 fallback을 추가하지 마세요.'; do
  assert_contains "$JOB_TEXT" "$text" 'module 04 Key Vault service-endpoint caveat missing'
done

assert_contains "$IMAGE_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing module 03 optional recovery heading'
assert_contains "$JOB_TEXT" '## 0. 세션 재연결 시 변수 복구 (선택)' 'missing module 04 optional recovery heading'
assert_contains "$IMAGE_TEXT" 'Cloud Shell 세션이 끊기면 셸 변수는 사라집니다. 이때 Module 01에서 저장한 `SUFFIX`와 Module 02에서 저장한 실제 `ACR` 이름을 다시 입력해 runner image 빌드에 필요한 최소 상태만 복구합니다.' 'module 03 minimal recovery explanation missing'
assert_contains "$IMAGE_TEXT" 'SUFFIX=a1b2c3 ACR=acracarunnera1b2c3 ACR_SERVER=acracarunnera1b2c3.azurecr.io IMAGE=github-actions-runner:2.336.0' 'module 03 minimal recovery example output missing'
assert_contains "$JOB_TEXT" 'Module 01에서 만든 Key Vault와 Module 02에서 완성한 service endpoint foundation, `GITHUB_APP_KEY_SECRET`, `KEY_VAULT_SECRET_URI`, `UAMI_RID`를 그대로 사용합니다.' 'module 04 must describe split Key Vault ownership'
assert_contains "$JOB_TEXT" 'Module 02의 `Microsoft.KeyVault` service endpoint, Key Vault ACA subnet rule, `defaultAction=Deny`, `bypass=None`, `Key Vault Secrets User`' 'module 04 troubleshooting must preserve service endpoint ownership order'

module_three_step_three="$(
  awk '
    /^## 3\. / { in_section=1 }
    /^## 4\. / { exit }
    in_section { print }
  ' "$IMAGE_DOC"
)"
assert_contains \
  "$module_three_step_three" \
  'IMAGE="github-actions-runner:2.336.0"' \
  'module 03 step 3 must initialize IMAGE on the normal first-run path'
module_three_image_line="$(printf '%s\n' "$module_three_step_three" | grep -nF 'IMAGE="github-actions-runner:2.336.0"' | head -n1 | cut -d: -f1)"
module_three_build_line="$(printf '%s\n' "$module_three_step_three" | grep -n '^az acr build \\' | head -n1 | cut -d: -f1)"
[[ -n "$module_three_image_line" && -n "$module_three_build_line" &&
   "$module_three_image_line" -lt "$module_three_build_line" ]] ||
  fail 'module 03 step 3 must initialize IMAGE before az acr build'

module_four_step_one="$(
  awk '
    /^## 1\. / { in_section=1 }
    /^## 2\. / { exit }
    in_section { print }
  ' "$JOB_DOC"
)"
for text in \
  'JOB="job-ghrunner-$SUFFIX"' \
  'IMAGE="github-actions-runner:2.336.0"'; do
  assert_contains "$module_four_step_one" "$text" \
    'module 04 step 1 must initialize normal-path Job variables'
done
module_four_job_line="$(printf '%s\n' "$module_four_step_one" | grep -nF 'JOB="job-ghrunner-$SUFFIX"' | head -n1 | cut -d: -f1)"
module_four_list_line="$(printf '%s\n' "$module_four_step_one" | grep -n '^az containerapp job list \\' | head -n1 | cut -d: -f1)"
[[ -n "$module_four_job_line" && -n "$module_four_list_line" &&
   "$module_four_job_line" -lt "$module_four_list_line" ]] ||
  fail 'module 04 step 1 must initialize JOB before querying existing jobs'

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
assert_contains \
  "$IMAGE_TEXT" \
  '| Azure CLI pinning | image 안의 Azure CLI `2.89.1`을 고정해 workflow 명령 동작이 build 시점마다 달라지지 않게 합니다. |' \
  'module 03 must describe Azure CLI pinning without the unused Container Apps extension'
if grep -F -- '0.3.55' "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
  fail 'modules 03 and 04 must not reference the obsolete Container Apps extension version'
fi

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

for forbidden in \
  'PE_SUBNET' \
  'STORAGE_PE' \
  'KEY_VAULT_PE' \
  'STORAGE_DNS_ZONE' \
  'KEY_VAULT_DNS_ZONE' \
  'PRIVATE_ENDPOINT_CIDR' \
  'AZURE_PRIVATE_ENDPOINT_CIDR' \
  'privatelink.'; do
  if grep -F -- "$forbidden" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "module 03/04 still contains obsolete Private Link state: $forbidden"
  fi
done

printf 'PASS: build and deploy docs\n'
