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

if [[ "${MOCK_CURL_MALFORMED:-0}" == "1" ]]; then
  printf '{}\n'
  exit 0
fi

[[ "$authorization" == "pat-secret-value" ]] || {
  printf 'unexpected authorization\n' >&2
  exit 2
}

case "$url" in
  *"/remove-token")
    if [[ "${MOCK_REMOVE_FAIL:-0}" == "1" ]]; then
      printf 'mock remove-token failure\n' >&2
      exit 22
    fi
    printf 'curl endpoint=remove-token auth_type=pat\n' >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/remove-token.auth"
    printf '{"token":"remove-token-value"}\n'
    ;;
  *"/registration-token")
    printf 'curl endpoint=registration-token auth_type=pat\n' >>"$MOCK_CALLS/events.log"
    printf '%s\n' "$authorization" >"$MOCK_CALLS/registration-token.auth"
    printf '{"token":"registration-token-value"}\n'
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
[[ -n "$token" ]] || exit 1
printf '%s\n' "$token"
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
if [[ "${MOCK_RUN_WAIT:-0}" == "1" ]]; then
  trap 'printf "terminated\n" >"$MOCK_CALLS/run-terminated.log"; exit 143' TERM
  touch "$MOCK_CALLS/run-started"
  while :; do
    sleep 1
  done
fi
exit "${MOCK_RUN_EXIT:-0}"
EOF2

  chmod +x "$FIXTURE/bin/curl" "$FIXTURE/bin/jq" \
    "$FIXTURE/runner/entrypoint.sh" "$FIXTURE/runner/config.sh" \
    "$FIXTURE/runner/run.sh"
  export MOCK_CALLS="$FIXTURE/calls"
  mkdir -p "$MOCK_CALLS"
}

run_entrypoint() {
  cd "$FIXTURE/runner"
  exec env \
    PATH="$FIXTURE/bin:$PATH" \
    GITHUB_PAT="${GITHUB_PAT-}" \
    GH_URL="${GH_URL-}" \
    REGISTRATION_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL-}" \
    RUNNER_LABELS="${RUNNER_LABELS-}" \
    RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX-}" \
    ./entrypoint.sh
}

[[ -f "$ENTRYPOINT" ]] || fail "runner/entrypoint.sh is missing"

make_fixture
if output="$(run_entrypoint 2>&1)"; then
  fail "missing variables should fail"
fi
[[ "$output" == *"GITHUB_PAT is required"* ]] ||
  fail "missing PAT error is unclear"
rm -rf "$FIXTURE"

make_fixture
export GITHUB_PAT="pat-secret-value"
export GH_URL="https://github.com/example/private-repo"
export REGISTRATION_TOKEN_API_URL="https://api.github.com/repos/example/private-repo/actions/runners/registration-token"
export RUNNER_LABELS="aca-runner"
export RUNNER_NAME_PREFIX="aca"
output="$(run_entrypoint 2>&1)"
grep -F -- "--ephemeral" "$MOCK_CALLS/config.log" >/dev/null || fail "ephemeral flag missing"
grep -F -- "--unattended" "$MOCK_CALLS/config.log" >/dev/null || fail "unattended flag missing"
grep -F -- "--disableupdate" "$MOCK_CALLS/config.log" >/dev/null || fail "disableupdate flag missing"
grep -F -- "--labels aca-runner" "$MOCK_CALLS/config.log" >/dev/null || fail "runner label missing"
[[ "$(<"$MOCK_CALLS/registration-token.auth")" == "pat-secret-value" ]] ||
  fail "registration token request did not use the PAT"
[[ "$(<"$MOCK_CALLS/remove-token.auth")" == "pat-secret-value" ]] ||
  fail "removal token request did not use the PAT"
grep -F 'curl endpoint=registration-token auth_type=pat' \
  "$MOCK_CALLS/events.log" >/dev/null ||
  fail "registration token request missing"
grep -F 'curl endpoint=remove-token auth_type=pat' \
  "$MOCK_CALLS/events.log" >/dev/null ||
  fail "removal token request missing"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null || fail "cleanup missing"
[[ -f "$MOCK_CALLS/run.log" ]] || fail "runner process was not started"
[[ "$output" != *"pat-secret-value"* ]] || fail "PAT leaked to output"
if grep -E '(^|_)GITHUB_PAT=|pat-secret-value|registration-token-value|remove-token-value' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "GitHub credentials reached the runner process"
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
export MOCK_CURL_MALFORMED=1
if output="$(run_entrypoint 2>&1)"; then
  fail "malformed GitHub API response should fail"
fi
[[ ! -f "$MOCK_CALLS/config.log" ]] ||
  fail "runner configured after malformed API response"
unset MOCK_CURL_MALFORMED
rm -rf "$FIXTURE"

make_fixture
export MOCK_RUN_EXIT=17
set +e
( run_entrypoint ) >"$ROOT/tests/runner/aca-runner-entrypoint-test.log" 2>&1
status=$?
set -e
[[ "$status" == "17" ]] || fail "runner exit status was not preserved"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null || fail "failed run was not cleaned up"
rm -rf "$FIXTURE" "$ROOT/tests/runner/aca-runner-entrypoint-test.log"

make_fixture
export MOCK_RUN_EXIT=17
export MOCK_REMOVE_FAIL=1
set +e
output="$(run_entrypoint 2>&1)"
status=$?
set -e
[[ "$status" == "17" ]] ||
  fail "cleanup failure replaced the runner exit status"
[[ "$output" == *"Runner cleanup failed with status 22"* ]] ||
  fail "cleanup failure was not reported"
unset MOCK_RUN_EXIT MOCK_REMOVE_FAIL
rm -rf "$FIXTURE"

make_fixture
export GITHUB_PAT="pat-secret-value"
export GH_URL="https://github.com/example/private-repo"
export REGISTRATION_TOKEN_API_URL="https://api.github.com/repos/example/private-repo/actions/runners/registration-token"
export MOCK_RUN_WAIT=1
set +e
run_entrypoint >"$MOCK_CALLS/signal-output.log" 2>&1 &
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
[[ -f "$MOCK_CALLS/run-terminated.log" ]] ||
  fail "TERM was not forwarded to the runner process"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null ||
  fail "TERM path did not clean up the runner"
unset MOCK_RUN_WAIT
rm -rf "$FIXTURE"

printf 'PASS: entrypoint behavior\n'
