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
printf '%s\n' "$*" | sed -E 's/Authorization: Bearer [^ ]+/Authorization: ******/g' >>"$MOCK_CALLS/curl.log"
if [[ "${MOCK_CURL_FAIL:-0}" == "1" ]]; then
  printf 'mock GitHub API failure\n' >&2
  exit 22
fi
case "$*" in
  *"/app/installations/"*"/access_tokens"*)
    printf '{"token":"installation-token-value"}\n'
    ;;
  *"/remove-token"*)
    printf '{"token":"remove-token-value"}\n'
    ;;
  *"/registration-token"*)
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
grep -F -- "/app/installations/67890/access_tokens" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "installation token was not requested"
grep -F -- "Authorization: ******" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "installation token was not used"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null || fail "cleanup missing"
[[ -f "$MOCK_CALLS/run.log" ]] || fail "runner process was not started"
[[ "$output" != *"mock-private-key"* ]] || fail "private key leaked to output"
[[ "$output" != *"installation-token-value"* ]] || fail "installation token leaked to output"
if grep -E 'GITHUB_APP_PRIVATE_KEY|installation-token-value|mock-private-key' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "long-lived GitHub App credentials reached the runner process"
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
rm -rf "$FIXTURE" "$ROOT/tests/runner/aca-runner-entrypoint-test.log"

printf 'PASS: entrypoint behavior\n'
