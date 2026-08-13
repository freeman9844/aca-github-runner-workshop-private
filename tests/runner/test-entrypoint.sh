#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENTRYPOINT="$ROOT/runner/entrypoint.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_fixture() {
  FIXTURE="$ROOT/tests/runner/.fixture-entrypoint"
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/bin" "$FIXTURE/runner"
  cp "$ENTRYPOINT" "$FIXTURE/runner/entrypoint.sh"

  cat >"$FIXTURE/bin/openssl" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  base64)
    /usr/bin/base64 -w0
    ;;
  dgst)
    cat >/dev/null
    printf 'mock-signature'
    ;;
  *)
    printf 'unexpected openssl invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
EOF2

  cat >"$FIXTURE/bin/curl" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
url=""
authorization=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --header)
      if [[ "${2:-}" == Authorization:\ Bearer\ * ]]; then
        authorization="${2#Authorization: Bearer }"
      fi
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

if [[ "${MOCK_CURL_FAIL:-0}" == "1" ]]; then
  printf 'mock GitHub API failure\n' >&2
  exit 22
fi

if [[ "$authorization" == installation-token-value-* ]]; then
  auth_type="installation_token"
elif [[ "$authorization" == *.*.* ]]; then
  auth_type="app_jwt"
else
  auth_type="unexpected"
fi

case "$url" in
  *"/app/installations/"*"/access_tokens")
    count_file="$MOCK_CALLS/access_tokens.count"
    count=0
    if [[ -f "$count_file" ]]; then
      count="$(<"$count_file")"
    fi
    count="$((count + 1))"
    printf '%s\n' "$count" >"$count_file"
    printf 'curl endpoint=access_tokens call=%s auth_type=%s\n' "$count" "$auth_type" >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/access_tokens_${count}.auth"
    printf '%s|%s|%s\n' "$url" "access_tokens" "$auth_type" >>"$MOCK_CALLS/curl.log"
    printf '{"token":"installation-token-value-%s"}\n' "$count"
    ;;
  *"/remove-token")
    printf 'curl endpoint=remove-token auth_type=%s\n' "$auth_type" >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/remove-token.auth"
    printf '%s|%s|%s\n' "$url" "remove-token" "$auth_type" >>"$MOCK_CALLS/curl.log"
    printf '{"token":"remove-token-value"}\n'
    ;;
  *"/registration-token")
    printf 'curl endpoint=registration-token auth_type=%s\n' "$auth_type" >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/registration-token.auth"
    printf '%s|%s|%s\n' "$url" "registration-token" "$auth_type" >>"$MOCK_CALLS/curl.log"
    printf '{"token":"registration-token-value"}\n'
    ;;
  *)
    printf 'unexpected URL\n' >&2
    exit 2
    ;;
esac
EOF2

  cat >"$FIXTURE/bin/jq" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
sed -n 's/.*"token":"\([^"]*\)".*/\1/p'
EOF2

  cat >"$FIXTURE/runner/config.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_CALLS/config.log"
if [[ "${1:-}" != "remove" ]]; then
  touch .runner
fi
EOF2

  cat >"$FIXTURE/runner/run.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
printf 'run\n' >>"$MOCK_CALLS/events.log"
env | sort >"$MOCK_CALLS/run-env.log"
printf 'run\n' >>"$MOCK_CALLS/run.log"
exit "${MOCK_RUN_EXIT:-0}"
EOF2

  chmod +x "$FIXTURE/bin/openssl" "$FIXTURE/bin/curl" "$FIXTURE/bin/jq" \
    "$FIXTURE/runner/entrypoint.sh" "$FIXTURE/runner/config.sh" "$FIXTURE/runner/run.sh"
  export MOCK_CALLS="$FIXTURE/calls"
  mkdir -p "$MOCK_CALLS"
}

run_entrypoint() {
  (
    cd "$FIXTURE/runner"
    PATH="$FIXTURE/bin:$PATH" \
      GITHUB_APP_ID="${GITHUB_APP_ID-}" \
      GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID-}" \
      GITHUB_APP_PRIVATE_KEY="${GITHUB_APP_PRIVATE_KEY-}" \
      GH_URL="${GH_URL-}" \
      REGISTRATION_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL-}" \
      RUNNER_LABELS="${RUNNER_LABELS-}" \
      RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX-}" \
      ./entrypoint.sh
  )
}

[[ -f "$ENTRYPOINT" ]] || fail "runner/entrypoint.sh is missing"

make_fixture
if output="$(run_entrypoint 2>&1)"; then
  fail "missing variables should fail"
fi
[[ "$output" == *"GITHUB_APP_ID is required"* ]] ||
  fail "missing-variable error is unclear"
rm -rf "$FIXTURE"

make_fixture
export GITHUB_APP_ID="not-a-number"
export GITHUB_APP_INSTALLATION_ID="123456"
export GITHUB_APP_PRIVATE_KEY=$'-----BEGIN RSA PRIVATE KEY-----\nmock\n-----END RSA PRIVATE KEY-----'
export GH_URL="https://github.com/example/private-repo"
export REGISTRATION_TOKEN_API_URL="https://api.github.com/repos/example/private-repo/actions/runners/registration-token"
if output="$(run_entrypoint 2>&1)"; then
  fail "non-numeric app ID should fail"
fi
[[ "$output" == *"GITHUB_APP_ID must be numeric"* ]] ||
  fail "numeric app ID validation is unclear"
rm -rf "$FIXTURE"

make_fixture
export GITHUB_APP_ID="12345"
export GITHUB_APP_INSTALLATION_ID="67890"
export GITHUB_APP_PRIVATE_KEY=$'-----BEGIN RSA PRIVATE KEY-----\nmock-private-key\n-----END RSA PRIVATE KEY-----'
export GH_URL="https://github.com/example/private-repo"
export REGISTRATION_TOKEN_API_URL="https://api.github.com/repos/example/private-repo/actions/runners/registration-token"
export RUNNER_LABELS="aca-runner"
export RUNNER_NAME_PREFIX="aca"
output="$(run_entrypoint 2>&1)"
grep -F -- "--ephemeral" "$MOCK_CALLS/config.log" >/dev/null || fail "ephemeral flag missing"
grep -F -- "--unattended" "$MOCK_CALLS/config.log" >/dev/null || fail "unattended flag missing"
grep -F -- "--disableupdate" "$MOCK_CALLS/config.log" >/dev/null || fail "disableupdate flag missing"
grep -F -- "--labels aca-runner" "$MOCK_CALLS/config.log" >/dev/null || fail "runner label missing"
grep -F -- "https://api.github.com/app/installations/67890/access_tokens|access_tokens|app_jwt" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "installation token was not requested with the app JWT"
grep -F -- "https://api.github.com/repos/example/private-repo/actions/runners/registration-token|registration-token|installation_token" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "registration token did not use the installation token"
grep -F -- "https://api.github.com/repos/example/private-repo/actions/runners/remove-token|remove-token|installation_token" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "removal token did not use the installation token"
[[ "$(<"$MOCK_CALLS/registration-token.auth")" == "installation-token-value-1" ]] ||
  fail "registration token did not use the startup installation token"
[[ "$(<"$MOCK_CALLS/remove-token.auth")" == "installation-token-value-2" ]] ||
  fail "cleanup did not use a fresh installation token"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null || fail "cleanup missing"
[[ -f "$MOCK_CALLS/run.log" ]] || fail "runner process was not started"
run_line="$(grep -n '^run$' "$MOCK_CALLS/events.log" | cut -d: -f1)"
cleanup_installation_line="$(grep -n 'endpoint=access_tokens call=2 auth_type=app_jwt' "$MOCK_CALLS/events.log" | cut -d: -f1)"
cleanup_removal_line="$(grep -n 'endpoint=remove-token auth_type=installation_token' "$MOCK_CALLS/events.log" | cut -d: -f1)"
[[ -n "$run_line" && -n "$cleanup_installation_line" && -n "$cleanup_removal_line" ]] ||
  fail "cleanup token flow was not fully recorded"
(( run_line < cleanup_installation_line )) ||
  fail "cleanup did not request a fresh installation token after runner exit"
(( cleanup_installation_line < cleanup_removal_line )) ||
  fail "cleanup removal token order was incorrect"
[[ "$output" != *"mock-private-key"* ]] || fail "private key leaked to output"
[[ "$output" != *"installation-token-value-1"* ]] || fail "startup installation token leaked to output"
[[ "$output" != *"installation-token-value-2"* ]] || fail "cleanup installation token leaked to output"
if grep -E 'GITHUB_APP_PRIVATE_KEY|installation-token-value|mock-private-key' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "long-lived GitHub App credentials reached the runner process"
fi
if grep -F -- "$(<"$MOCK_CALLS/access_tokens_1.auth")" "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "startup GitHub App JWT reached the runner process"
fi
if grep -F -- "$(<"$MOCK_CALLS/access_tokens_2.auth")" "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "cleanup GitHub App JWT reached the runner process"
fi
rm -rf "$FIXTURE"

make_fixture
export MOCK_CURL_FAIL=1
if output="$(run_entrypoint 2>&1)"; then
  fail "GitHub API failure should fail"
fi
[[ ! -f "$MOCK_CALLS/config.log" ]] || fail "runner configured after API failure"
unset MOCK_CURL_FAIL
rm -rf "$FIXTURE"

make_fixture
export MOCK_RUN_EXIT=17
set +e
run_entrypoint >"$ROOT/tests/runner/aca-runner-entrypoint-test.log" 2>&1
status=$?
set -e
[[ "$status" == "17" ]] || fail "runner exit status was not preserved"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null || fail "failed run was not cleaned up"
[[ "$(<"$MOCK_CALLS/remove-token.auth")" == "installation-token-value-2" ]] ||
  fail "failed run cleanup did not use a fresh installation token"
rm -rf "$FIXTURE" "$ROOT/tests/runner/aca-runner-entrypoint-test.log"

printf 'PASS: entrypoint behavior\n'
