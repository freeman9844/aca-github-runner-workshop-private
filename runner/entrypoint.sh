#!/usr/bin/env bash
set -Eeuo pipefail

# GitHub API를 호출하기 전에 필수 입력을 검사하여 누락된 secret이나 repository URL로 요청하지 않게 합니다.
required_variables=(
  GITHUB_APP_ID
  GITHUB_APP_INSTALLATION_ID
  GITHUB_APP_PRIVATE_KEY
  GH_URL
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'ERROR: %s is required\n' "$variable_name" >&2
    exit 64
  fi
done

github_app_id="$GITHUB_APP_ID"
github_app_installation_id="$GITHUB_APP_INSTALLATION_ID"
github_app_private_key="$GITHUB_APP_PRIVATE_KEY"
unset GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY

# 허용된 GitHub repository URL 형식만 받아 owner와 repository 이름을 안전하게 추출합니다.
if [[ "$GH_URL" =~ ^https://github\.com/([^/?#]+)/([^/?#]+)$ ]]; then
  github_owner="${BASH_REMATCH[1]}"
  github_repo="${BASH_REMATCH[2]}"
else
  printf 'ERROR: GH_URL must match https://github.com/OWNER/REPO\n' >&2
  exit 64
fi

REGISTRATION_TOKEN_API_URL="https://api.github.com/repos/$github_owner/$github_repo/actions/runners/registration-token"
RUNNER_LABELS="${RUNNER_LABELS:-aca-runner}"
RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX:-aca-runner}"
RUNNER_NAME="${RUNNER_NAME_PREFIX}-$(hostname)-${RANDOM}"
CLEANED_UP=0
runner_pid=""

base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

create_app_jwt() {
  local now_epoch
  local issued_at
  local expires_at
  local header_json
  local payload_json
  local header_segment
  local payload_segment
  local signing_input
  local signature_segment

  now_epoch="$(date +%s)"
  issued_at="$((now_epoch - 60))"
  expires_at="$((now_epoch + 540))"
  header_json='{"alg":"RS256","typ":"JWT"}'
  printf -v payload_json \
    '{"iat":%s,"exp":%s,"iss":%s}' \
    "$issued_at" "$expires_at" "$github_app_id"

  header_segment="$(printf '%s' "$header_json" | base64url_encode)"
  payload_segment="$(printf '%s' "$payload_json" | base64url_encode)"
  signing_input="${header_segment}.${payload_segment}"
  signature_segment="$(
    printf '%s' "$signing_input" \
      | openssl dgst -binary -sha256 \
        -sign <(printf '%s\n' "$github_app_private_key") \
      | base64url_encode
  )"

  printf '%s.%s\n' "$signing_input" "$signature_segment"
}

github_api_post_token() {
  local url="$1"
  local bearer_token="$2"
  local response
  local authorization_header
  local token

  printf -v authorization_header '%s: %s %s' \
    'Authorization' 'Bearer' "$bearer_token"
  response="$(
    curl --fail --silent --show-error --request POST \
      --connect-timeout 10 \
      --max-time 30 \
      --header 'Accept: application/vnd.github+json' \
      --header "$authorization_header" \
      --header 'X-GitHub-Api-Version: 2026-03-10' \
      "$url"
  )" || return $?

  if ! token="$(
    jq --exit-status --raw-output \
      '.token | select(type == "string" and length > 0)' <<<"$response"
  )"; then
    printf 'ERROR: GitHub token response did not include a non-empty token\n' >&2
    return 1
  fi

  printf '%s\n' "$token"
}

create_installation_token() {
  local app_jwt
  app_jwt="$(create_app_jwt)"
  github_api_post_token \
    "https://api.github.com/app/installations/$github_app_installation_id/access_tokens" \
    "$app_jwt"
}

create_runner_token() {
  local action="$1"
  local installation_token="$2"
  github_api_post_token \
    "${REGISTRATION_TOKEN_API_URL%/registration-token}/${action}-token" \
    "$installation_token"
}

run_as_runner() {
  exec runuser --preserve-environment -u runner -- "$@"
}

# container 종료 시 fresh installation/removal token으로 ephemeral runner 등록 정보를 정리합니다.
cleanup_runner() {
  local prior_status=$?
  local cleanup_status=0
  local installation_token=""
  local removal_token=""

  if [[ "$CLEANED_UP" == "1" ]]; then
    return "$prior_status"
  fi
  CLEANED_UP=1

  if [[ ! -f .runner ]]; then
    return "$prior_status"
  fi

  set +e
  installation_token="$(create_installation_token)"
  cleanup_status=$?
  if [[ "$cleanup_status" == "0" ]]; then
    removal_token="$(create_runner_token remove "$installation_token")"
    cleanup_status=$?
  fi
  if [[ "$cleanup_status" == "0" ]]; then
    (run_as_runner ./config.sh remove --token "$removal_token")
    cleanup_status=$?
  fi
  set -e

  if [[ "$cleanup_status" != "0" ]]; then
    printf 'ERROR: Runner cleanup failed with status %s\n' "$cleanup_status" >&2
  fi

  if [[ "$prior_status" != "0" ]]; then
    return "$prior_status"
  fi
  return "$cleanup_status"
}

# 종료 signal을 runner process에 전달하고 Container Apps에 원래 종료 상태를 보존합니다.
forward_signal() {
  local signal_name="$1"
  local exit_status="$2"

  if [[ -n "$runner_pid" ]]; then
    kill -s "$signal_name" "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" 2>/dev/null || true
    runner_pid=""
  fi
  exit "$exit_status"
}

trap cleanup_runner EXIT
trap 'forward_signal INT 130' INT
trap 'forward_signal TERM 143' TERM

# GitHub App JWT -> installation token -> registration token 순서로 일회성 runner를 등록합니다.
registration_installation_token="$(create_installation_token)"
registration_token="$(create_runner_token registration "$registration_installation_token")"
unset registration_installation_token

(run_as_runner ./config.sh \
  --url "$GH_URL" \
  --token "$registration_token" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --no-default-labels \
  --unattended \
  --ephemeral \
  --disableupdate)

unset registration_token
printf 'Runner configured: %s\n' "$RUNNER_NAME"

# workflow job 하나를 runner 사용자로 실행한 뒤 종료 상태를 Container Apps Job 결과로 반환합니다.
set +e
(run_as_runner ./run.sh) &
runner_pid=$!
wait "$runner_pid"
runner_status=$?
runner_pid=""
set -e
printf 'Runner process exited with status %s\n' "$runner_status"
exit "$runner_status"
