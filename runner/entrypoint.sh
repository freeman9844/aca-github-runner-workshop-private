#!/usr/bin/env bash
set -Eeuo pipefail

required_variables=(
  GITHUB_APP_ID
  GITHUB_APP_INSTALLATION_ID
  GITHUB_APP_PRIVATE_KEY
  GH_URL
  REGISTRATION_TOKEN_API_URL
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'ERROR: %s is required\n' "$variable_name" >&2
    exit 64
  fi
done

for variable_name in GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID; do
  if [[ ! "${!variable_name}" =~ ^[0-9]+$ ]]; then
    printf 'ERROR: %s must be numeric\n' "$variable_name" >&2
    exit 64
  fi
done

if ! grep -qE '^-----BEGIN (RSA )?PRIVATE KEY-----$' \
  <<<"$GITHUB_APP_PRIVATE_KEY"; then
  printf 'ERROR: GITHUB_APP_PRIVATE_KEY must contain a PEM private key\n' >&2
  exit 64
fi

if [[ "$REGISTRATION_TOKEN_API_URL" != */registration-token ]]; then
  printf 'ERROR: REGISTRATION_TOKEN_API_URL must end with /registration-token\n' >&2
  exit 64
fi

RUNNER_LABELS="${RUNNER_LABELS:-aca-runner}"
RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX:-aca-runner}"
RUNNER_NAME="${RUNNER_NAME_PREFIX}-$(hostname)-${RANDOM}"
REMOVAL_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL%/registration-token}/remove-token"
INSTALLATION_TOKEN_API_URL="https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens"
CLEANED_UP=0
removal_token=""

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

github_app_jwt() {
  local now issued_at expires_at header payload unsigned signature
  now="$(date +%s)"
  issued_at=$((now - 60))
  expires_at=$((now + 540))
  header="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url)"
  payload="$(
    printf '{"iat":%s,"exp":%s,"iss":"%s"}' \
      "$issued_at" "$expires_at" "$GITHUB_APP_ID" |
      base64url
  )"
  unsigned="$header.$payload"
  signature="$(
    printf '%s' "$unsigned" |
      openssl dgst -sha256 \
        -sign <(printf '%s' "$GITHUB_APP_PRIVATE_KEY") |
      base64url
  )"
  printf '%s.%s\n' "$unsigned" "$signature"
}

github_api_token() {
  local url="$1"
  local bearer_token="$2"
  local authorization_header
  printf -v authorization_header '%s: %s %s' \
    'Authorization' 'Bearer' "$bearer_token"
  curl --fail --silent --show-error --request POST \
    --header 'Accept: application/vnd.github+json' \
    --header "$authorization_header" \
    --header 'X-GitHub-Api-Version: 2026-03-10' \
    "$url" |
    jq --exit-status --raw-output '.token'
}

cleanup() {
  local cleanup_status=0

  if [[ "$CLEANED_UP" == "1" ]]; then
    return 0
  fi
  CLEANED_UP=1

  if [[ ! -f .runner ]]; then
    return 0
  fi

  if [[ -z "$removal_token" ]]; then
    printf 'ERROR: Runner cleanup token is unavailable\n' >&2
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

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Requesting GitHub App installation token\n'
app_jwt="$(github_app_jwt)"
installation_token="$(github_api_token "$INSTALLATION_TOKEN_API_URL" "$app_jwt")"

printf 'Requesting registration token\n'
registration_token="$(
  github_api_token "$REGISTRATION_TOKEN_API_URL" "$installation_token"
)"

printf 'Requesting runner removal token\n'
removal_token="$(
  github_api_token "$REMOVAL_TOKEN_API_URL" "$installation_token"
)"

unset GITHUB_APP_PRIVATE_KEY app_jwt installation_token

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
