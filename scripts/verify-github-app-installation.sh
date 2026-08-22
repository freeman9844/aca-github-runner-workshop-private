#!/usr/bin/env bash
set -euo pipefail

GITHUB_APP_KEY_SECRET="${GITHUB_APP_KEY_SECRET:-github-app-private-key}"

printf '[1/4] 입력값 확인\n'

# 인증에 필요한 Cloud Shell 명령이 모두 설치되어 있는지 먼저 확인합니다.
for required_command in az openssl curl jq; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$required_command" >&2
    exit 1
  fi
done

# 앞 단계에서 입력한 Azure와 GitHub 식별자가 현재 Cloud Shell에 있는지 확인합니다.
for required_variable in \
  SUBSCRIPTION_ID \
  KEY_VAULT \
  GITHUB_OWNER \
  GITHUB_REPO \
  GITHUB_APP_ID \
  GITHUB_APP_INSTALLATION_ID; do
  if [[ ! -v "$required_variable" ]] || [[ -z "${!required_variable}" ]]; then
    printf 'ERROR: required variable is not set: %s\n' "$required_variable" >&2
    exit 1
  fi
done

# App ID와 Installation ID가 GitHub에서 사용하는 양의 정수 형식인지 검사합니다.
if [[ ! "$GITHUB_APP_ID" =~ ^[1-9][0-9]*$ ]] ||
  [[ ! "$GITHUB_APP_INSTALLATION_ID" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: App ID and Installation ID must be positive integers.\n' >&2
  exit 1
fi

az account set --subscription "$SUBSCRIPTION_ID"
printf '      Organization=%s, Repository=%s\n' "$GITHUB_OWNER" "$GITHUB_REPO"

printf '[2/4] Key Vault private key 확인\n'

# 임시 private key 파일을 만들고 script 종료 시 secret과 JWT를 항상 정리합니다.
TEMP_PRIVATE_KEY_DIR="$(mktemp -d)"
TEMP_PRIVATE_KEY_FILE="$TEMP_PRIVATE_KEY_DIR/github-app-private-key.pem"
cleanup() {
  rm -f -- "$TEMP_PRIVATE_KEY_FILE"
  rmdir -- "$TEMP_PRIVATE_KEY_DIR" 2>/dev/null || true
  unset app_jwt
  unset installation_token
}
trap cleanup EXIT

# Key Vault secret을 보호된 임시 파일로 내려받아 JWT 서명에 사용합니다.
az keyvault secret download \
  --vault-name "$KEY_VAULT" \
  --name "$GITHUB_APP_KEY_SECRET" \
  --file "$TEMP_PRIVATE_KEY_FILE" \
  --encoding utf-8 \
  --output none
chmod 600 "$TEMP_PRIVATE_KEY_FILE"

# 다운로드한 값이 줄바꿈이 보존된 유효한 PEM private key인지 확인합니다.
openssl pkey -in "$TEMP_PRIVATE_KEY_FILE" -check -noout

# GitHub App JWT에 사용할 base64url 인코딩 함수를 정의합니다.
base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# 현재 시간을 기준으로 10분 이내에 만료되는 GitHub App JWT payload를 만듭니다.
now_epoch="$(date +%s)"
printf -v payload_json '{"iat":%s,"exp":%s,"iss":%s}' \
  "$((now_epoch - 60))" "$((now_epoch + 540))" "$GITHUB_APP_ID"
signing_input="$(
  printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url_encode
).$(
  printf '%s' "$payload_json" | base64url_encode
)"

# Key Vault에서 받은 private key로 JWT에 RS256 서명합니다.
app_jwt="${signing_input}.$(
  printf '%s' "$signing_input" |
    openssl dgst -binary -sha256 -sign "$TEMP_PRIVATE_KEY_FILE" |
    base64url_encode
)"

printf '[3/4] GitHub App 설치와 권한 확인\n'

# JWT로 Installation 정보와 App 권한 및 organization 범위를 확인합니다.
installation_json="$(
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $app_jwt" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID"
)"
if ! jq -e \
  --argjson app_id "$GITHUB_APP_ID" \
  --arg owner "$GITHUB_OWNER" \
  '
    .app_id == $app_id and
    ((.account.login | ascii_downcase) == ($owner | ascii_downcase)) and
    .repository_selection == "selected" and
    .permissions.administration == "write" and
    .permissions.actions == "read"
  ' <<<"$installation_json" >/dev/null; then
  printf 'ERROR: App ID, Installation ID, organization 또는 App 권한이 예상값과 다릅니다.\n' >&2
  exit 1
fi
installation_owner="$(jq -r '.account.login' <<<"$installation_json")"
printf '      Owner=%s, Administration=write, Actions=read\n' "$installation_owner"

installation_token="$(
  curl -fsSL \
    --request POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $app_jwt" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens" |
    jq -er '.token'
)"

printf '[4/4] 접근 repository 확인\n'

# Installation token으로 접근 가능한 repository가 실습 저장소 하나뿐인지 확인합니다.
repositories_json="$(
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $installation_token" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/installation/repositories?per_page=100"
)"
if ! jq -e \
  --arg owner "$GITHUB_OWNER" \
  --arg repo "$GITHUB_REPO" \
  '
    .total_count == 1 and
    (.repositories | length == 1) and
    ((.repositories[0].owner.login | ascii_downcase) == ($owner | ascii_downcase)) and
    ((.repositories[0].name | ascii_downcase) == ($repo | ascii_downcase))
  ' <<<"$repositories_json" >/dev/null; then
  printf 'ERROR: App repository access를 Only select repositories로 설정하고 %s/%s 하나만 선택하세요.\n' \
    "$GITHUB_OWNER" "$GITHUB_REPO" >&2
  exit 1
fi

printf 'PASS: Key Vault secret과 GitHub App 설치 범위 확인: App %s, Installation %s, Repository %s/%s\n' \
  "$GITHUB_APP_ID" "$GITHUB_APP_INSTALLATION_ID" "$GITHUB_OWNER" "$GITHUB_REPO"
