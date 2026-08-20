#!/usr/bin/env bash
set -Eeuo pipefail

# GitHub API를 호출하기 전에 필수 입력을 검사하여 누락된 secret이나 repository URL로 요청하지 않게 합니다.
required_variables=(
  GITHUB_PAT
  GH_URL
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'ERROR: %s is required\n' "$variable_name" >&2
    exit 64
  fi
done

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
REMOVAL_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL%/registration-token}/remove-token"
CLEANED_UP=0

# PAT는 단기 registration/removal token을 준비하는 동안에만 wrapper 내부에 유지합니다.
github_pat="$GITHUB_PAT"
unset GITHUB_PAT
runner_pid=""
removal_token=""

# PAT를 GitHub API에 전달해 일회성 runner 등록 또는 제거에 사용할 단기 token을 발급받습니다.
github_api_token() {
  local url="$1"
  local response
  local authorization_header
  printf -v authorization_header '%s: %s %s' \
    'Authorization' 'Bearer' "$github_pat"
  response="$(
    curl --fail --silent --show-error --request POST \
      --connect-timeout 10 \
      --max-time 30 \
      --header 'Accept: application/vnd.github+json' \
      --header "$authorization_header" \
      --header 'X-GitHub-Api-Version: 2026-03-10' \
      "$url"
  )" || return $?
  jq --exit-status --raw-output \
    '.token | select(type == "string" and length > 0)' <<<"$response"
}

# container 종료 시 미리 발급한 removal token으로 ephemeral runner 등록 정보를 정리합니다.
cleanup() {
  local cleanup_status=0

  if [[ "$CLEANED_UP" == "1" ]]; then
    return 0
  fi
  CLEANED_UP=1

  if [[ ! -f .runner ]]; then
    return 0
  fi

  set +e
  ./config.sh remove --token "$removal_token"
  cleanup_status=$?
  set -e

  if [[ "$cleanup_status" != "0" ]]; then
    printf 'ERROR: Runner cleanup failed with status %s\n' "$cleanup_status" >&2
  fi
  return 0
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

trap cleanup EXIT
trap 'forward_signal INT 130' INT
trap 'forward_signal TERM 143' TERM

# 기본 label을 제외하고 custom label만 가진 고유 이름의 일회성 runner를 등록합니다.
printf 'Requesting registration token\n'
registration_token="$(github_api_token "$REGISTRATION_TOKEN_API_URL")"
printf 'Requesting removal token\n'
removal_token="$(github_api_token "$REMOVAL_TOKEN_API_URL")"
unset github_pat
unset -f github_api_token

./config.sh \
  --url "$GH_URL" \
  --token "$registration_token" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --no-default-labels \
  --unattended \
  --ephemeral \
  --disableupdate

unset registration_token
printf 'Runner configured: %s\n' "$RUNNER_NAME"

# workflow job 하나를 실행한 뒤 runner 종료 상태를 Container Apps Job 결과로 반환합니다.
set +e
./run.sh &
runner_pid=$!
wait "$runner_pid"
runner_status=$?
runner_pid=""
set -e
printf 'Runner process exited with status %s\n' "$runner_status"
exit "$runner_status"
