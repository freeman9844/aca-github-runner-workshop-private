#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"
RUNNER_DOCKERFILE="$ROOT/runner/Dockerfile"
RUNNER_ENTRYPOINT="$ROOT/runner/entrypoint.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_documented_file_matches() {
  local marker="$1"
  local actual_file="$2"
  local documented_file

  documented_file="$(
    awk -v marker="$marker" '
      $0 == "<!-- BEGIN " marker " -->" { found = 1; next }
      found && /^```/ && !in_code { in_code = 1; next }
      found && /^```/ && in_code { exit }
      in_code { print }
    ' "$IMAGE_DOC"
  )"

  [[ -n "$documented_file" ]] ||
    fail "module 03 missing documented source block: $marker"
  diff -u "$actual_file" <(printf '%s\n' "$documented_file") >/dev/null ||
    fail "module 03 source block differs from $(basename "$actual_file")"
}

operational_github_app_pattern='GITHUB_APP_|github_app_jwt|/app/installations/|openssl dgst|BEGIN [A-Z0-9 ]*PRIVATE KEY|applicationID=|installationID=|appKey=|github-app-private-key'

[[ -f "$IMAGE_DOC" ]] || { echo "FAIL: module 03 missing" >&2; exit 1; }
[[ -f "$JOB_DOC" ]] || { echo "FAIL: module 04 missing" >&2; exit 1; }
[[ -f "$RUNNER_DOCKERFILE" ]] || fail "runner Dockerfile missing"
[[ -f "$RUNNER_ENTRYPOINT" ]] || fail "runner entrypoint missing"

assert_documented_file_matches "RUNNER_DOCKERFILE" "$RUNNER_DOCKERFILE"
assert_documented_file_matches "RUNNER_ENTRYPOINT" "$RUNNER_ENTRYPOINT"

for comment in \
  '# GitHub API 호출·JSON 처리와 Azure 배포에 필요한 도구 및 고정 버전 Azure CLI를 설치합니다.' \
  '# workflow가 등록·정리 로직을 바꾸지 못하도록 entrypoint를 root 소유의 읽기·실행 전용 파일로 배치합니다.' \
  '# sudo와 docker 그룹 권한을 제거한 non-root runner 사용자로 이후 명령과 workflow를 실행합니다.' \
  '# Container Apps extension을 고정 버전으로 설치하고 기본 명령 로딩까지 build 시점에 검증합니다.' \
  '# container 시작 시 entrypoint가 일회성 runner 등록을 마친 후 workflow 수신을 시작합니다.'; do
  grep -F -- "$comment" "$RUNNER_DOCKERFILE" >/dev/null ||
    fail "runner Dockerfile missing explanatory comment: $comment"
done

for comment in \
  '# GitHub API를 호출하기 전에 필수 입력을 검사하여 누락된 secret이나 repository URL로 요청하지 않게 합니다.' \
  '# 허용된 GitHub repository URL 형식만 받아 owner와 repository 이름을 안전하게 추출합니다.' \
  '# PAT는 단기 registration/removal token을 준비하는 동안에만 wrapper 내부에 유지합니다.' \
  '# PAT를 GitHub API에 전달해 일회성 runner 등록 또는 제거에 사용할 단기 token을 발급받습니다.' \
  '# container 종료 시 미리 발급한 removal token으로 ephemeral runner 등록 정보를 정리합니다.' \
  '# 종료 signal을 runner process에 전달하고 Container Apps에 원래 종료 상태를 보존합니다.' \
  '# 기본 label을 제외하고 custom label만 가진 고유 이름의 일회성 runner를 등록합니다.' \
  '# workflow job 하나를 실행한 뒤 runner 종료 상태를 Container Apps Job 결과로 반환합니다.'; do
  grep -F -- "$comment" "$RUNNER_ENTRYPOINT" >/dev/null ||
    fail "runner entrypoint missing explanatory comment: $comment"
done

[[ "$(grep -c '^# ' "$RUNNER_DOCKERFILE")" -eq 5 ]] ||
  fail "runner Dockerfile must contain exactly five Korean explanatory comments"
[[ "$(grep -c '^# ' "$RUNNER_ENTRYPOINT")" -eq 8 ]] ||
  fail "runner entrypoint must contain exactly eight Korean explanatory comments"

assert_collapsed_recovery() {
  local doc="$1"
  local module="$2"
  local expected_details_count
  local details_open_line summary_line close_line first_step_line
  local summary_next_line details_prev_line
  local -a actual_headings expected_headings

  if [[ "$module" == "module 03" ]]; then
    expected_details_count=3
  else
    expected_details_count=1
  fi

  grep -Fx '## 0. 세션 재연결 시 변수 복구 (선택)' "$doc" >/dev/null ||
    fail "$module missing optional Step 0 recovery heading"
  [[ "$(grep -Fc '<details>' "$doc")" -eq "$expected_details_count" ]] ||
    fail "$module must contain exactly $expected_details_count details blocks"
  [[ "$(grep -Fc '</details>' "$doc")" -eq "$expected_details_count" ]] ||
    fail "$module must close exactly $expected_details_count details blocks"
  grep -Fx '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$doc" >/dev/null ||
    fail "$module missing recovery disclosure summary"

  details_open_line="$(grep -nF -m1 '<details>' "$doc" | cut -d: -f1)"
  summary_line="$(grep -nF -m1 '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$doc" | cut -d: -f1)"
  close_line="$(grep -nF -m1 '</details>' "$doc" | cut -d: -f1)"
  first_step_line="$(grep -nE -m1 '^## 1\. ' "$doc" | cut -d: -f1)"
  [[ -n "$details_open_line" && -n "$summary_line" && -n "$close_line" && -n "$first_step_line" ]] ||
    fail "$module missing recovery disclosure structure"

  summary_next_line="$(sed -n "$((summary_line + 1))p" "$doc")"
  details_prev_line="$(sed -n "$((close_line - 1))p" "$doc")"

  [[ -z "${summary_next_line//[[:space:]]/}" ]] ||
    fail "$module summary must be followed by a blank line"
  [[ -z "${details_prev_line//[[:space:]]/}" ]] ||
    fail "$module details close must be preceded by a blank line"
  (( details_open_line < summary_line && summary_line < close_line && close_line < first_step_line )) ||
    fail "$module recovery details must close before required Step 1"

  mapfile -t actual_headings < <(grep -E '^## [0-9]+\.' "$doc")
  case "$module" in
    "module 03")
      expected_headings=(
        '## 0. 세션 재연결 시 변수 복구 (선택)'
        '## 1. runner 이미지 파일 읽기'
        '## 2. 로컬 정적 검사 먼저 실행'
        '## 3. ACR Tasks로 runner image 빌드'
        '## 4. 왜 이 구성을 유지하나요?'
      )
      ;;
    "module 04")
      expected_headings=(
        '## 0. 세션 재연결 시 변수 복구 (선택)'
        '## 1. 기존 Job과 중복 queue watcher 확인'
        '## 2. ACA Event Job 생성'
        '## 3. GitHub 쪽에서 미리 확인할 것'
      )
      ;;
    *)
      fail "unexpected module: $module"
      ;;
  esac

  [[ "${#actual_headings[@]}" -eq "${#expected_headings[@]}" ]] ||
    fail "$module numbered heading count mismatch: expected ${#expected_headings[@]}, got ${#actual_headings[@]}"
  for i in "${!expected_headings[@]}"; do
    [[ "${actual_headings[$i]}" == "${expected_headings[$i]}" ]] ||
      fail "$module numbered heading mismatch at position $((i + 1)): expected '${expected_headings[$i]}', got '${actual_headings[$i]}'"
  done
}

assert_collapsed_recovery "$IMAGE_DOC" "module 03"
assert_collapsed_recovery "$JOB_DOC" "module 04"

assert_runner_source_disclosures() {
  local docker_summary='<summary><code>runner/Dockerfile</code> 실제 파일 내용 보기</summary>'
  local entrypoint_summary='<summary><code>runner/entrypoint.sh</code> 실제 파일 내용 보기</summary>'
  local docker_summary_line docker_open_line docker_begin_line docker_end_line docker_close_line
  local entrypoint_summary_line entrypoint_open_line entrypoint_begin_line entrypoint_end_line entrypoint_close_line
  local step2_line

  grep -Fx "$docker_summary" "$IMAGE_DOC" >/dev/null ||
    fail "module 03 missing collapsed Dockerfile summary"
  grep -Fx "$entrypoint_summary" "$IMAGE_DOC" >/dev/null ||
    fail "module 03 missing collapsed entrypoint summary"

  docker_summary_line="$(grep -nF -m1 "$docker_summary" "$IMAGE_DOC" | cut -d: -f1)"
  docker_open_line="$(awk -v summary="$docker_summary_line" 'NR < summary && $0 == "<details>" { line=NR } END { print line }' "$IMAGE_DOC")"
  docker_begin_line="$(grep -nF -m1 '<!-- BEGIN RUNNER_DOCKERFILE -->' "$IMAGE_DOC" | cut -d: -f1)"
  docker_end_line="$(grep -nF -m1 '<!-- END RUNNER_DOCKERFILE -->' "$IMAGE_DOC" | cut -d: -f1)"
  docker_close_line="$(awk -v summary="$docker_summary_line" 'NR > summary && $0 == "</details>" { print NR; exit }' "$IMAGE_DOC")"

  entrypoint_summary_line="$(grep -nF -m1 "$entrypoint_summary" "$IMAGE_DOC" | cut -d: -f1)"
  entrypoint_open_line="$(awk -v summary="$entrypoint_summary_line" 'NR < summary && $0 == "<details>" { line=NR } END { print line }' "$IMAGE_DOC")"
  entrypoint_begin_line="$(grep -nF -m1 '<!-- BEGIN RUNNER_ENTRYPOINT -->' "$IMAGE_DOC" | cut -d: -f1)"
  entrypoint_end_line="$(grep -nF -m1 '<!-- END RUNNER_ENTRYPOINT -->' "$IMAGE_DOC" | cut -d: -f1)"
  entrypoint_close_line="$(awk -v summary="$entrypoint_summary_line" 'NR > summary && $0 == "</details>" { print NR; exit }' "$IMAGE_DOC")"
  step2_line="$(grep -nF -m1 '## 2. 로컬 정적 검사 먼저 실행' "$IMAGE_DOC" | cut -d: -f1)"

  (( docker_open_line < docker_summary_line &&
     docker_summary_line < docker_begin_line &&
     docker_begin_line < docker_end_line &&
     docker_end_line < docker_close_line &&
     docker_close_line < entrypoint_open_line &&
     entrypoint_open_line < entrypoint_summary_line &&
     entrypoint_summary_line < entrypoint_begin_line &&
     entrypoint_begin_line < entrypoint_end_line &&
     entrypoint_end_line < entrypoint_close_line &&
     entrypoint_close_line < step2_line )) ||
    fail "module 03 runner source blocks must be collapsed inside Step 1"
}

assert_runner_source_disclosures

for doc in "$IMAGE_DOC" "$JOB_DOC"; do
  for text in \
    'SUBSCRIPTION_ID=$(az account show' \
    'RG_ID=$(az group show' \
    'UAMI_CLIENT_ID=$(az identity show' \
    '--query clientId'; do
    grep -F -- "$text" "$doc" >/dev/null ||
      fail "$(basename "$doc") missing recovery value: $text"
  done
done

for old_heading in \
  '## 1. 저장해 둔 `SUFFIX`와 `ACR`로 Azure 변수 복구' \
  '## 2. Fine-grained PAT 입력값 다시 로드' \
  '## 2. runner 이미지 파일 읽기' \
  '## 3. 기존 Job과 중복 queue watcher 확인'; do
  if grep -Fx "$old_heading" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "old recovery or step heading remains: $old_heading"
  fi
done

grep -Fx '### Azure 리소스 변수' "$JOB_DOC" >/dev/null ||
  fail "module 04 missing Azure recovery subsection"
grep -Fx '### GitHub 인증 변수' "$JOB_DOC" >/dev/null ||
  fail "module 04 missing GitHub recovery subsection"

for heading in \
  '## 5. 태그와 ACR 보안 설정 검증' \
  '## 5. secret을 노출하지 않고 Job 상태 검증'; do
  if grep -Fx "$heading" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "standalone validation heading remains: $heading"
  fi
done

if grep -E "$operational_github_app_pattern" <(
  printf '%s\n' 'The old GitHub App installation token path is intentionally not used in this workshop.'
) >/dev/null; then
  fail "historical GitHub App prose should not trigger operational App checks"
fi

grep -E "$operational_github_app_pattern" <(
  printf '%s\n' 'openssl dgst -sha256 -sign app-private-key.pem'
) >/dev/null || fail "JWT signing markers must stay rejected"

grep -E "$operational_github_app_pattern" <(
  printf '%s\n' '--scale-rule-auth "applicationID=12345"'
) >/dev/null || fail "operational KEDA App configuration must stay rejected"

for text in \
  'bash -n runner/entrypoint.sh' \
  'bash tests/runner/test-entrypoint.sh' \
  'az acr build' \
  'az acr repository show-tags' \
  'adminUserEnabled:adminUserEnabled' \
  '--image "$IMAGE"' \
  './runner' \
  'ghcr.io/actions/actions-runner:2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda' \
  'ARG AZURE_CLI_VERSION=2.89.1-1~noble' \
  'apt-get install -y --no-install-recommends azure-cli="$AZURE_CLI_VERSION"' \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved ACR name: " ACR' \
  'SUFFIX=a1b2c3 ACR=acracarunnera1b2c3 IMAGE=github-actions-runner:2.336.0' \
  'az extension add --name containerapp --upgrade --version 0.3.55 --only-show-errors' \
  'az version' \
  'az containerapp --help' \
  'GITHUB_PAT' \
  'unset'; do
  grep -F -- "$text" "$IMAGE_DOC" >/dev/null || { echo "FAIL: module 03 missing $text" >&2; exit 1; }
done

grep -F '| Docker CLI 포함, daemon 미포함 |' "$IMAGE_DOC" >/dev/null ||
  fail "module 03 must distinguish the Docker CLI from the unavailable daemon"

if grep -E "$operational_github_app_pattern" "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 still describes GitHub App bootstrap" >&2
  exit 1
fi

if grep -F -- 'ACR="acracarunner$SUFFIX"' "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 reconstructs ACR from SUFFIX instead of reading the saved actual ACR name" >&2
  exit 1
fi

for text in \
  'JOB_CREATE_ARGS=(' \
  '# queue가 비어 있으면 execution을 0개로 유지합니다.' \
  'az containerapp job create "${JOB_CREATE_ARGS[@]}"' \
  'triggerType:properties.configuration.triggerType' \
  'properties.configuration.eventTriggerConfig.scale.rules' \
  'az containerapp job execution list' \
  '--trigger-type Event' \
  '--container-name github-actions-runner' \
  '--replica-timeout 900' \
  '--replica-retry-limit 0' \
  '--replica-completion-count 1' \
  '--parallelism 1' \
  '--min-executions 0' \
  '--max-executions 5' \
  '--polling-interval 30' \
  '--scale-rule-type github-runner' \
  'githubApiURL=https://api.github.com' \
  'runnerScope=repo' \
  'labels=aca-runner' \
  'noDefaultLabels=true' \
  'targetWorkflowQueueLength=1' \
  'JOB=job-ghrunner-a1b2c3 ENV=env-acarunner-a1b2c3 ACR_SERVER=acracarunnera1b2c3.azurecr.io' \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved ACR name: " ACR' \
  'RUNNER_LABELS=aca-runner' \
  'RUNNER_NAME_PREFIX=aca' \
  '--mi-user-assigned "$UAMI_RID"' \
  '--registry-identity "$UAMI_RID"' \
  'read -rsp "Fine-grained PAT: " GITHUB_PAT' \
  'until [[ -n "$GITHUB_PAT" ]]' \
  'ERROR: Fine-grained PAT cannot be empty. Try again.' \
  'personalAccessToken=personal-access-token' \
  'personal-access-token=$GITHUB_PAT' \
  'GITHUB_PAT=secretref:personal-access-token' \
  '"AZURE_CLIENT_ID=$UAMI_CLIENT_ID"' \
  '"AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"' \
  '"AZURE_RESOURCE_GROUP=$RG"' \
  '"AZURE_CONTAINERAPPS_ENVIRONMENT=$ENV"' \
  '"AZURE_SAMPLE_APP=hello-aca-$SUFFIX"' \
  'unset JOB_CREATE_ARGS GITHUB_PAT' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only' \
  'az containerapp job list' \
  "metadata.owner=='\$GITHUB_OWNER'" \
  "metadata.repos=='\$GITHUB_REPO'" \
  "metadata.labels=='aca-runner'" \
  '동일한 repository와 label' \
  'az containerapp job show --name "$JOB" --resource-group "$RG" --output none' \
  'az containerapp job delete \' \
  'Job 설정 오류를 복구할 때는 Resource Group 전체를 다시 만들지 말고 이 워크숍 Job만 삭제 후 재생성합니다.'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

if grep -F 'Do not instruct participants' "$JOB_DOC" >/dev/null; then
  fail "module 04 still exposes an internal authoring note"
fi

if grep -F 'REGISTRATION_TOKEN_API_URL=' "$JOB_DOC" >/dev/null; then
  fail "module 04 must derive the registration-token endpoint from GH_URL"
fi

if grep -E '^[[:space:]]*export[[:space:]].*GITHUB_PAT' "$JOB_DOC" >/dev/null; then
  fail "module 04 must keep GITHUB_PAT shell-local"
fi

preflight_line="$(grep -nF -m1 'az containerapp job list' "$JOB_DOC" | cut -d: -f1)"
create_line="$(grep -nF -m1 'az containerapp job create "${JOB_CREATE_ARGS[@]}"' "$JOB_DOC" | cut -d: -f1)"
(( preflight_line < create_line )) ||
  fail "duplicate watcher and existing Job checks must run before job create"

if grep -E "$operational_github_app_pattern|PEM" \
  "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 still contains GitHub App configuration" >&2
  exit 1
fi

if grep -nE 'SUFFIX=[0-9a-f]{5}\b|acracarunner[0-9a-f]{5}\b' "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 regressed to a five-character suffix example" >&2
  exit 1
fi

if grep -nE 'job-ghrunner-[0-9a-f]{5}\b|env-acarunner-[0-9a-f]{5}\b|acracarunner[0-9a-f]{5}\.azurecr\.io\b' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 regressed to a five-character suffix example" >&2
  exit 1
fi

if grep -F -- 'ACR="acracarunner$SUFFIX"' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 reconstructs ACR from SUFFIX instead of reading the saved actual ACR name" >&2
  exit 1
fi

if grep -F -- '## 4. 파라미터 의미 빠르게 읽기' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 keeps parameter explanations in a separate table" >&2
  exit 1
fi

if grep -F -- 'githubAPIURL=' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 uses invalid KEDA metadata key githubAPIURL" >&2
  exit 1
fi

for text in \
  '--cpu 2.0' \
  '--memory 4Gi'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

printf 'PASS: image build and Event Job docs\n'
