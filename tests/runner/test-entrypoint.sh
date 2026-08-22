#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENTRYPOINT="$ROOT/runner/entrypoint.sh"
BASE_PATH="$PATH"
REAL_DATE="$(command -v date)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

base64url_decode() {
  local value="$1"
  local remainder
  remainder="$((${#value} % 4))"
  if [[ "$remainder" == "2" ]]; then
    value="${value}=="
  elif [[ "$remainder" == "3" ]]; then
    value="${value}="
  elif [[ "$remainder" == "1" ]]; then
    fail "invalid base64url payload length"
  fi
  printf '%s' "$value" | tr '_-' '/+' | openssl base64 -d -A
}

json_field() {
  local field="$1"
  python3 -c 'import json, sys; print(json.loads(sys.stdin.read())[sys.argv[1]])' \
    "$field"
}

assert_all_lines_equal() {
  local file="$1"
  local expected="$2"
  [[ -f "$file" ]] || fail "missing file: $file"
  while IFS= read -r line; do
    [[ "$line" == "$expected" ]] || fail "expected every line in $file to equal $expected"
  done <"$file"
}

assert_output_contains() {
  local output="$1"
  local needle="$2"
  local description="$3"
  [[ "$output" == *"$needle"* ]] || fail "$description"
}

make_fixture() {
  FIXTURE="$ROOT/tests/runner/.fixture-entrypoint"
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/bin" "$FIXTURE/runner"
  cp "$ENTRYPOINT" "$FIXTURE/runner/entrypoint.sh"

  openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:2048 \
    -out "$FIXTURE/github-app-private-key.pem" \
    >/dev/null 2>&1
  export GITHUB_APP_PRIVATE_KEY
  GITHUB_APP_PRIVATE_KEY="$(<"$FIXTURE/github-app-private-key.pem")"
  export GITHUB_APP_ID=12345
  export GITHUB_APP_INSTALLATION_ID=67890

  cat >"$FIXTURE/bin/date" <<EOF2
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "+%s" ]]; then
  printf '%s\n' "\${MOCK_DATE_EPOCH:-1700000000}"
  exit 0
fi
exec "$REAL_DATE" "\$@"
EOF2

  cat >"$FIXTURE/bin/curl" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
url=""
authorization=""
connect_timeout=""
max_time=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --header)
      if [[ "${2:-}" == Authorization:\ Bearer\ * ]]; then
        authorization="${2#Authorization: Bearer }"
      fi
      shift 2
      ;;
    --connect-timeout)
      connect_timeout="${2:-}"
      shift 2
      ;;
    --max-time)
      max_time="${2:-}"
      shift 2
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

[[ "$connect_timeout" == "10" ]] || {
  printf 'missing connect timeout\n' >&2
  exit 2
}
[[ "$max_time" == "30" ]] || {
  printf 'missing max time\n' >&2
  exit 2
}

case "$url" in
  "https://api.github.com/app/installations/67890/access_tokens")
    if [[ "${MOCK_INSTALLATION_FAIL:-0}" == "1" ]]; then
      printf 'mock installation-token failure\n' >&2
      exit 22
    fi
    if [[ "${MOCK_TOKEN_MALFORMED_ENDPOINT:-}" == "installation" ]]; then
      printf '{}\n'
      exit 0
    fi
    count_file="$MOCK_CALLS/installation-token.count"
    token_count=0
    [[ -f "$count_file" ]] && token_count="$(<"$count_file")"
    token_count="$((token_count + 1))"
    printf '%s\n' "$token_count" >"$count_file"
    printf 'curl endpoint=installation-token auth_type=app jwt=<redacted>\n' >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/installation-token-$token_count.jwt"
    printf '%s\n' "$url" >"$MOCK_CALLS/installation-token-$token_count.url"
    printf '{"token":"installation-token-%s"}\n' "$token_count"
    ;;
  *"/registration-token")
    if [[ "${MOCK_REGISTRATION_FAIL:-0}" == "1" ]]; then
      printf 'mock registration-token failure\n' >&2
      exit 22
    fi
    if [[ "${MOCK_TOKEN_MALFORMED_ENDPOINT:-}" == "registration" ]]; then
      printf '{}\n'
      exit 0
    fi
    printf 'curl endpoint=registration-token auth_type=installation token=%s\n' "$authorization" >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/registration-token.auth"
    printf '{"token":"registration-token-value"}\n'
    ;;
  *"/remove-token")
    if [[ "${MOCK_REMOVE_TOKEN_FAIL:-0}" == "1" ]]; then
      printf 'mock remove-token failure\n' >&2
      exit 22
    fi
    if [[ "${MOCK_TOKEN_MALFORMED_ENDPOINT:-}" == "remove" ]]; then
      printf '{}\n'
      exit 0
    fi
    printf 'curl endpoint=remove-token auth_type=installation token=%s\n' "$authorization" >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/remove-token.auth"
    printf '{"token":"remove-token-value"}\n'
    ;;
  *)
    printf 'unexpected URL: %s\n' "$url" >&2
    exit 2
    ;;
esac
EOF2

  cat >"$FIXTURE/bin/jq" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
payload="$(cat)"
token="$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' <<<"$payload")"
if [[ -z "$token" ]]; then
  printf 'mock jq: token missing\n' >&2
  exit 1
fi
printf '%s\n' "$token"
EOF2

  cat >"$FIXTURE/bin/runuser" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
user=""
preserve_environment=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --preserve-environment)
      preserve_environment=1
      shift
      ;;
    -u)
      user="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf 'unexpected runuser argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[[ "$preserve_environment" == "1" ]] || {
  printf 'runuser missing --preserve-environment\n' >&2
  exit 2
}
[[ -n "$user" ]] || {
  printf 'runuser missing user\n' >&2
  exit 2
}

printf '%s\n' "$user" >>"$MOCK_CALLS/runuser-users.log"
if [[ "${1:-}" == "./run.sh" ]]; then
  printf 'run user=%s\n' "$user" >>"$MOCK_CALLS/events.log"
elif [[ "${1:-}" == "./config.sh" && "${2:-}" == "remove" ]]; then
  printf 'remove user=%s\n' "$user" >>"$MOCK_CALLS/events.log"
fi

forward_to_child() {
  local signal_name="$1"
  local forwarded_status=0
  kill -s "$signal_name" "$child_pid" 2>/dev/null || true
  wait "$child_pid" || forwarded_status=$?
  exit "$forwarded_status"
}

child_status=0
"$@" &
child_pid=$!
trap 'forward_to_child TERM' TERM
trap 'forward_to_child INT' INT
wait "$child_pid" || child_status=$?
trap - TERM INT
exit "$child_status"
EOF2

  cat >"$FIXTURE/runner/config.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_CALLS/config.log"
if [[ "${1:-}" == "remove" ]]; then
  rm -f .runner
  exit 0
fi
touch .runner
EOF2

  cat >"$FIXTURE/runner/run.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
env | sort >"$MOCK_CALLS/run-env.log"
printf 'run\n' >>"$MOCK_CALLS/run.log"
if [[ "${MOCK_RUN_WAIT:-0}" == "1" ]]; then
  trap 'printf "terminated\n" >"$MOCK_CALLS/run-terminated.log"; exit 143' TERM
  printf '%s\n' "$$" >"$MOCK_CALLS/run-pid"
  touch "$MOCK_CALLS/run-started"
  while :; do
    sleep 1
  done
fi
exit "${MOCK_RUN_EXIT:-0}"
EOF2

  chmod +x \
    "$FIXTURE/bin/curl" \
    "$FIXTURE/bin/date" \
    "$FIXTURE/bin/jq" \
    "$FIXTURE/bin/runuser" \
    "$FIXTURE/runner/config.sh" \
    "$FIXTURE/runner/entrypoint.sh" \
    "$FIXTURE/runner/run.sh"
  export MOCK_CALLS="$FIXTURE/calls"
  mkdir -p "$MOCK_CALLS"
}

run_entrypoint() {
  (
    cd "$FIXTURE/runner"
    exec env -i \
      PATH="$FIXTURE/bin:$BASE_PATH" \
      HOME="$FIXTURE/runner" \
      MOCK_CALLS="$MOCK_CALLS" \
      MOCK_DATE_EPOCH="${MOCK_DATE_EPOCH-}" \
      MOCK_INSTALLATION_FAIL="${MOCK_INSTALLATION_FAIL-}" \
      MOCK_REGISTRATION_FAIL="${MOCK_REGISTRATION_FAIL-}" \
      MOCK_REMOVE_TOKEN_FAIL="${MOCK_REMOVE_TOKEN_FAIL-}" \
      MOCK_RUN_EXIT="${MOCK_RUN_EXIT-}" \
      MOCK_RUN_WAIT="${MOCK_RUN_WAIT-}" \
      MOCK_TOKEN_MALFORMED_ENDPOINT="${MOCK_TOKEN_MALFORMED_ENDPOINT-}" \
      GH_URL="${GH_URL-}" \
      GITHUB_APP_ID="${GITHUB_APP_ID-}" \
      GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID-}" \
      GITHUB_APP_PRIVATE_KEY="${GITHUB_APP_PRIVATE_KEY-}" \
      RUNNER_LABELS="${RUNNER_LABELS-}" \
      RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX-}" \
      ./entrypoint.sh
  )
}

[[ -f "$ENTRYPOINT" ]] || fail "runner/entrypoint.sh is missing"

for missing_variable in GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY; do
  make_fixture
  export GH_URL="https://github.com/example/private-repo"
  export RUNNER_LABELS="aca-runner"
  export RUNNER_NAME_PREFIX="aca"
  unset "$missing_variable"
  if output="$(run_entrypoint 2>&1)"; then
    fail "missing $missing_variable should fail"
  fi
  assert_output_contains "$output" "$missing_variable is required" "missing $missing_variable error is unclear"
  rm -rf "$FIXTURE"
done

make_fixture
export GH_URL="https://attacker.example/example/private-repo"
if output="$(run_entrypoint 2>&1)"; then
  fail "untrusted GH_URL should fail"
fi
assert_output_contains "$output" "GH_URL must match https://github.com/OWNER/REPO" "untrusted GH_URL error is unclear"
[[ ! -f "$MOCK_CALLS/events.log" ]] || fail "token exchange started before GH_URL validation"
rm -rf "$FIXTURE"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export RUNNER_LABELS="aca-runner"
export RUNNER_NAME_PREFIX="aca"
output="$(run_entrypoint 2>&1)"

grep -F -- "--ephemeral" "$MOCK_CALLS/config.log" >/dev/null || fail "ephemeral flag missing"
grep -F -- "--unattended" "$MOCK_CALLS/config.log" >/dev/null || fail "unattended flag missing"
grep -F -- "--disableupdate" "$MOCK_CALLS/config.log" >/dev/null || fail "disableupdate flag missing"
grep -F -- "--labels aca-runner" "$MOCK_CALLS/config.log" >/dev/null || fail "runner label missing"
grep -F -- "--no-default-labels" "$MOCK_CALLS/config.log" >/dev/null ||
  fail "runner default labels were not disabled"
[[ "$(<"$MOCK_CALLS/registration-token.auth")" == "installation-token-1" ]] ||
  fail "registration token request did not use the first installation token"
[[ "$(<"$MOCK_CALLS/remove-token.auth")" == "installation-token-2" ]] ||
  fail "cleanup did not use a fresh installation token"
[[ "$(<"$MOCK_CALLS/installation-token-1.url")" == "https://api.github.com/app/installations/67890/access_tokens" ]] ||
  fail "installation token endpoint is incorrect"

jwt="$(<"$MOCK_CALLS/installation-token-1.jwt")"
IFS='.' read -r jwt_header jwt_payload jwt_signature <<<"$jwt"
[[ -n "$jwt_header" && -n "$jwt_payload" && -n "$jwt_signature" ]] ||
  fail "app JWT must have three base64url segments"

payload_json="$(base64url_decode "$jwt_payload")"
[[ "$(json_field iss <<<"$payload_json")" == "12345" ]] || fail "JWT iss claim is incorrect"
[[ "$(json_field iat <<<"$payload_json")" == "1699999940" ]] || fail "JWT iat claim is incorrect"
[[ "$(json_field exp <<<"$payload_json")" == "1700000540" ]] || fail "JWT exp claim is incorrect"

signed_input="${jwt%.*}"
base64url_decode "$jwt_signature" >"$FIXTURE/jwt-signature.bin"
printf '%s' "$signed_input" >"$FIXTURE/jwt-signed-input.txt"
openssl pkey -pubout \
  -in "$FIXTURE/github-app-private-key.pem" \
  -out "$FIXTURE/github-app-public-key.pem" \
  >/dev/null 2>&1
openssl dgst -sha256 \
  -verify "$FIXTURE/github-app-public-key.pem" \
  -signature "$FIXTURE/jwt-signature.bin" \
  "$FIXTURE/jwt-signed-input.txt" \
  >/dev/null 2>&1 || fail "app JWT signature did not verify"

assert_all_lines_equal "$MOCK_CALLS/runuser-users.log" "runner"

mapfile -t events <"$MOCK_CALLS/events.log"
[[ "${events[0]}" == "curl endpoint=installation-token auth_type=app jwt=<redacted>" ]] ||
  fail "first call must request the installation token"
[[ "${events[1]}" == "curl endpoint=registration-token auth_type=installation token=installation-token-1" ]] ||
  fail "registration must use the first installation token"
[[ "${events[2]}" == "run user=runner" ]] ||
  fail "run.sh must start under runuser"
[[ "${events[3]}" == "curl endpoint=installation-token auth_type=app jwt=<redacted>" ]] ||
  fail "cleanup must request a fresh installation token"
[[ "${events[4]}" == "curl endpoint=remove-token auth_type=installation token=installation-token-2" ]] ||
  fail "cleanup must use the second installation token for removal"
[[ "${events[5]}" == "remove user=runner" ]] ||
  fail "cleanup must remove the runner through runuser"

[[ "$output" != *"installation-token-1"* ]] || fail "installation token leaked to output"
[[ "$output" != *"installation-token-2"* ]] || fail "cleanup installation token leaked to output"
[[ "$output" != *"registration-token-value"* ]] || fail "registration token leaked to output"
[[ "$output" != *"remove-token-value"* ]] || fail "removal token leaked to output"
if grep -F -- "$jwt" "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "app JWT reached the runner process"
fi
if grep -E '(^|_)GITHUB_APP_ID=|(^|_)GITHUB_APP_INSTALLATION_ID=|(^|_)GITHUB_APP_PRIVATE_KEY=' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "GitHub App environment variables reached the runner process"
fi
if grep -E 'installation-token-|registration-token-value|remove-token-value' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "GitHub tokens reached the runner process"
fi
rm -rf "$FIXTURE"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export MOCK_TOKEN_MALFORMED_ENDPOINT=installation
if output="$(run_entrypoint 2>&1)"; then
  fail "malformed installation token response should fail"
fi
assert_output_contains "$output" "mock jq: token missing" "malformed token failure was not reported"
[[ ! -f "$MOCK_CALLS/config.log" ]] || fail "runner configured after malformed token response"
unset MOCK_TOKEN_MALFORMED_ENDPOINT
rm -rf "$FIXTURE"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export MOCK_INSTALLATION_FAIL=1
if output="$(run_entrypoint 2>&1)"; then
  fail "installation token HTTP failure should fail"
fi
assert_output_contains "$output" "mock installation-token failure" "installation token HTTP failure was not reported"
[[ ! -f "$MOCK_CALLS/config.log" ]] || fail "runner configured after installation token failure"
unset MOCK_INSTALLATION_FAIL
rm -rf "$FIXTURE"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export MOCK_REGISTRATION_FAIL=1
if output="$(run_entrypoint 2>&1)"; then
  fail "registration token HTTP failure should fail"
fi
assert_output_contains "$output" "mock registration-token failure" "registration token HTTP failure was not reported"
[[ ! -f "$MOCK_CALLS/run.log" ]] || fail "runner started after registration token failure"
unset MOCK_REGISTRATION_FAIL
rm -rf "$FIXTURE"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export MOCK_RUN_EXIT=17
export MOCK_REMOVE_TOKEN_FAIL=1
set +e
run_entrypoint >"$ROOT/tests/runner/aca-runner-entrypoint-test.log" 2>&1
status=$?
set -e
[[ "$status" == "17" ]] || fail "runner exit status must win over cleanup failure"
grep -F 'curl endpoint=installation-token auth_type=app jwt=<redacted>' "$MOCK_CALLS/events.log" >/dev/null ||
  fail "cleanup did not request a fresh installation token after runner failure"
grep -F 'curl endpoint=remove-token auth_type=installation token=installation-token-2' \
  "$ROOT/tests/runner/aca-runner-entrypoint-test.log" >/dev/null && fail "cleanup token leaked to output"
unset MOCK_REMOVE_TOKEN_FAIL MOCK_RUN_EXIT
rm -rf "$FIXTURE" "$ROOT/tests/runner/aca-runner-entrypoint-test.log"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export MOCK_REMOVE_TOKEN_FAIL=1
set +e
output="$(run_entrypoint 2>&1)"
status=$?
set -e
[[ "$status" == "22" ]] || fail "cleanup failure should be returned after a successful runner"
assert_output_contains "$output" "mock remove-token failure" "remove-token HTTP failure was not reported"
[[ -f "$MOCK_CALLS/run.log" ]] || fail "runner did not start before cleanup failure"
unset MOCK_REMOVE_TOKEN_FAIL
rm -rf "$FIXTURE"

make_fixture
export GH_URL="https://github.com/example/private-repo"
export MOCK_RUN_WAIT=1
set +e
(
  cd "$FIXTURE/runner"
  exec env -i \
    PATH="$FIXTURE/bin:$BASE_PATH" \
    HOME="$FIXTURE/runner" \
    MOCK_CALLS="$MOCK_CALLS" \
    MOCK_DATE_EPOCH="${MOCK_DATE_EPOCH-}" \
    MOCK_INSTALLATION_FAIL="${MOCK_INSTALLATION_FAIL-}" \
    MOCK_REGISTRATION_FAIL="${MOCK_REGISTRATION_FAIL-}" \
    MOCK_REMOVE_TOKEN_FAIL="${MOCK_REMOVE_TOKEN_FAIL-}" \
    MOCK_RUN_EXIT="${MOCK_RUN_EXIT-}" \
    MOCK_RUN_WAIT="${MOCK_RUN_WAIT-}" \
    MOCK_TOKEN_MALFORMED_ENDPOINT="${MOCK_TOKEN_MALFORMED_ENDPOINT-}" \
    GH_URL="${GH_URL-}" \
    GITHUB_APP_ID="${GITHUB_APP_ID-}" \
    GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID-}" \
    GITHUB_APP_PRIVATE_KEY="${GITHUB_APP_PRIVATE_KEY-}" \
    RUNNER_LABELS="${RUNNER_LABELS-}" \
    RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX-}" \
    ./entrypoint.sh
) >"$MOCK_CALLS/signal-output.log" 2>&1 &
entrypoint_pid=$!
for _ in $(seq 1 50); do
  [[ -f "$MOCK_CALLS/run-started" ]] && break
  sleep 0.1
done
[[ -f "$MOCK_CALLS/run-started" ]] || fail "runner did not start for signal test"
kill -TERM "$entrypoint_pid"
wait "$entrypoint_pid"
status=$?
set -e
[[ "$status" == "143" ]] || fail "TERM exit status was not preserved"
[[ -f "$MOCK_CALLS/run-terminated.log" ]] || fail "TERM was not forwarded to the runner process"
run_pid="$(<"$MOCK_CALLS/run-pid")"
if kill -0 "$run_pid" 2>/dev/null; then
  fail "runner process remained alive after TERM"
fi
[[ "$(grep -c '^curl endpoint=installation-token' "$MOCK_CALLS/events.log")" == "2" ]] ||
  fail "cleanup ran more than once after TERM"
[[ "$(grep -c '^remove user=runner' "$MOCK_CALLS/events.log")" == "1" ]] ||
  fail "TERM path must clean up exactly once"
unset MOCK_RUN_WAIT
rm -rf "$FIXTURE"

printf 'PASS: entrypoint behavior\n'
