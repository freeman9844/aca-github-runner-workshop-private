#!/usr/bin/env bash
set -Eeuo pipefail

required_variables=(GITHUB_PAT GH_URL REGISTRATION_TOKEN_API_URL)
for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'ERROR: %s is required\n' "$variable_name" >&2
    exit 64
  fi
done

if [[ "$REGISTRATION_TOKEN_API_URL" != */registration-token ]]; then
  printf 'ERROR: REGISTRATION_TOKEN_API_URL must end with /registration-token\n' >&2
  exit 64
fi

RUNNER_LABELS="${RUNNER_LABELS:-aca-runner}"
RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX:-aca-runner}"
RUNNER_NAME="${RUNNER_NAME_PREFIX}-$(hostname)-${RANDOM}"
REMOVAL_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL%/registration-token}/remove-token"
CLEANED_UP=0

github_token() {
  local url="$1"
  curl --fail --silent --show-error --request POST \
    --header 'Accept: application/vnd.github+json' \
    --header "Authorization: Bearer ${GITHUB_PAT}" \
    --header 'X-GitHub-Api-Version: 2022-11-28' \
    "$url" |
    jq --exit-status --raw-output '.token'
}

cleanup() {
  local cleanup_status=0
  local removal_token=""

  if [[ "$CLEANED_UP" == "1" ]]; then
    return 0
  fi
  CLEANED_UP=1

  if [[ ! -f .runner ]]; then
    return 0
  fi

  printf 'Runner cleanup: requesting removal token\n'
  set +e
  removal_token="$(github_token "$REMOVAL_TOKEN_API_URL")"
  cleanup_status=$?
  if [[ "$cleanup_status" == "0" && -n "$removal_token" ]]; then
    ./config.sh remove --token "$removal_token"
    cleanup_status=$?
  fi
  set -e

  if [[ "$cleanup_status" != "0" ]]; then
    printf 'ERROR: Runner cleanup failed with status %s\n' "$cleanup_status" >&2
  fi
  return 0
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Requesting registration token\n'
registration_token="$(github_token "$REGISTRATION_TOKEN_API_URL")"

./config.sh \
  --url "$GH_URL" \
  --token "$registration_token" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --unattended \
  --ephemeral \
  --disableupdate

printf 'Runner configured: %s\n' "$RUNNER_NAME"
set +e
./run.sh
runner_status=$?
set -e
printf 'Runner process exited with status %s\n' "$runner_status"
exit "$runner_status"
