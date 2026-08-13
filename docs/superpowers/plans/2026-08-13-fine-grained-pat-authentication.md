# Fine-Grained PAT Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace GitHub App authentication with one repository-scoped Fine-grained PAT for KEDA scaling and ephemeral runner registration while preventing workflow processes from inheriting the PAT.

**Architecture:** Store one Fine-grained PAT as an Azure Container Apps secret and reference it from both KEDA's `personalAccessToken` authentication and the runner container's `GITHUB_PAT` bootstrap input. The entrypoint copies the PAT into a non-exported wrapper-shell variable, unsets the exported input before `run.sh`, and uses the private variable only to request short-lived registration and removal tokens.

**Tech Stack:** Bash, curl, jq, Azure CLI Container Apps extension, KEDA `github-runner` scaler, GitHub REST API `2026-03-10`, GitHub Actions.

## Global Constraints

- Runner scope remains `repo`.
- The lab repository remains private and the Fine-grained PAT is limited to that single repository.
- Required repository permissions are Actions read-only, Administration read and write, and Metadata read-only.
- Recommend a 30-day PAT expiration for the workshop.
- KEDA metadata key remains exactly `githubApiURL`.
- KEDA authentication parameter is exactly `personalAccessToken`.
- The shared ACA secret name is exactly `personal-access-token`.
- Runner image version remains `2.336.0`.
- Event Job settings remain `min-executions=0`, `max-executions=5`, `polling-interval=30`, and `targetWorkflowQueueLength=1`.
- Workflow processes must not inherit `GITHUB_PAT`, the PAT value, registration tokens, or removal tokens.
- GitHub REST requests continue to use API version `2026-03-10`.
- Preserve the original runner process exit status even when cleanup fails.
- Workshop duration totals approximately 90 minutes.
- Existing Azure RBAC, six-hex-character suffix, saved actual ACR-name recovery, screenshot wording, and validation CI behavior remain intact.
- Do not add Azure Key Vault, an external token broker, separate scaler and runner PATs, classic PATs, JIT configuration, or live billable Azure tests.

## File Structure

- Modify `runner/entrypoint.sh`: replace App JWT and installation-token logic with secure PAT-backed registration/removal-token requests.
- Modify `runner/Dockerfile`: remove runner-image OpenSSL installation because JWT signing is removed.
- Modify `tests/runner/test-entrypoint.sh`: mock PAT-authenticated GitHub calls and prove PAT isolation.
- Modify `tests/test-artifacts.sh`: require the PAT interface and reject runner-side GitHub App code.
- Modify `docs/01-prerequisites-github.md`: document Fine-grained PAT creation, EMU policy notes, safe loading, and API verification.
- Modify `tests/docs/test-prerequisites-foundation.sh`: enforce module 01's PAT contract while preserving module 02 checks.
- Modify `docs/03-runner-image.md`: describe the PAT bootstrap and revised image dependencies.
- Modify `docs/04-event-job-keda.md`: configure one ACA PAT secret for KEDA and runner bootstrap.
- Modify `tests/docs/test-build-deploy.sh`: enforce module 03 and 04 PAT configuration.
- Modify `docs/05-parallel-scale-validation.md`: replace App-specific explanations and troubleshooting with PAT guidance.
- Modify `tests/docs/test-scale-validation.sh`: enforce PAT-based scale-validation guidance.
- Modify `README.md`: update prerequisites, terminology, module timing, and total duration to 90 minutes.
- Modify `tests/docs/test-overview.sh`: enforce the revised overview contract.
- Modify `docs/06-security-limitations-cleanup.md`: document PAT isolation, rotation, revocation, and cleanup.
- Modify `tests/docs/test-security-cleanup.sh`: enforce the PAT lifecycle guidance.
- Modify `tests/validate-workshop.sh`: reject operational GitHub App configuration and require consistent PAT configuration.
- Keep `tests/test-validate-workshop.sh` and `.github/workflows/validate-workshop.yml` unchanged; they continue invoking the integrated validator.

---

### Task 1: Replace Runner GitHub App Bootstrap with Secure PAT Bootstrap

**Files:**
- Modify: `tests/runner/test-entrypoint.sh`
- Modify: `runner/entrypoint.sh`
- Modify: `runner/Dockerfile`
- Modify: `tests/test-artifacts.sh`

**Interfaces:**
- Consumes environment variables: `GITHUB_PAT`, `GH_URL`, `REGISTRATION_TOKEN_API_URL`, optional `RUNNER_LABELS`, optional `RUNNER_NAME_PREFIX`.
- Produces shell function: `github_api_token(url)` returning the `.token` value from a PAT-authenticated GitHub POST.
- Derives: `REMOVAL_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL%/registration-token}/remove-token"`.
- Preserves: `./config.sh --unattended --ephemeral --disableupdate`, cleanup-on-exit behavior, runner labels, runner naming, and runner exit status.

- [ ] **Step 1: Rewrite the entrypoint fixture to model PAT authentication**

Remove the OpenSSL mock from `tests/runner/test-entrypoint.sh`. Replace the curl mock's App JWT and installation-token classification with a direct PAT check:

```bash
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
```

Update fixture permissions so the removed OpenSSL mock is no longer named:

```bash
chmod +x "$FIXTURE/bin/curl" "$FIXTURE/bin/jq" \
  "$FIXTURE/runner/entrypoint.sh" "$FIXTURE/runner/config.sh" \
  "$FIXTURE/runner/run.sh"
```

Update `run_entrypoint()` so the child receives only the new authentication input:

```bash
PATH="$FIXTURE/bin:$PATH" \
  GITHUB_PAT="${GITHUB_PAT-}" \
  GH_URL="${GH_URL-}" \
  REGISTRATION_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL-}" \
  RUNNER_LABELS="${RUNNER_LABELS-}" \
  RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX-}" \
  ./entrypoint.sh
```

- [ ] **Step 2: Replace App-specific assertions with failing PAT contract assertions**

Use `export GITHUB_PAT="pat-secret-value"` in success fixtures. Assert:

```bash
[[ "$output" == *"GITHUB_PAT is required"* ]] ||
  fail "missing PAT error is unclear"

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

[[ "$output" != *"pat-secret-value"* ]] || fail "PAT leaked to output"
if grep -E '(^|_)GITHUB_PAT=|pat-secret-value|registration-token-value|remove-token-value' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "GitHub credentials reached the runner process"
fi
```

Keep existing assertions for `--ephemeral`, `--unattended`, `--disableupdate`,
labels, cleanup, API failure, and runner exit status. Remove numeric App ID,
PEM, App JWT, installation-token, and fresh-installation-token assertions.

Add a malformed-response case:

```bash
make_fixture
export MOCK_CURL_MALFORMED=1
if output="$(run_entrypoint 2>&1)"; then
  fail "malformed GitHub API response should fail"
fi
[[ ! -f "$MOCK_CALLS/config.log" ]] ||
  fail "runner configured after malformed API response"
unset MOCK_CURL_MALFORMED
rm -rf "$FIXTURE"
```

Add a cleanup-failure status test:

```bash
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
```

Extend the mock `run.sh` so signal behavior can be exercised:

```bash
if [[ "${MOCK_RUN_WAIT:-0}" == "1" ]]; then
  trap 'printf "terminated\n" >"$MOCK_CALLS/run-terminated.log"; exit 143' TERM
  touch "$MOCK_CALLS/run-started"
  while :; do
    sleep 1
  done
fi
```

Make the last command in `run_entrypoint()` an `exec` so a backgrounded helper
PID is the entrypoint PID:

```bash
exec env \
  PATH="$FIXTURE/bin:$PATH" \
  GITHUB_PAT="${GITHUB_PAT-}" \
  GH_URL="${GH_URL-}" \
  REGISTRATION_TOKEN_API_URL="${REGISTRATION_TOKEN_API_URL-}" \
  RUNNER_LABELS="${RUNNER_LABELS-}" \
  RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX-}" \
  ./entrypoint.sh
```

Add a TERM test:

```bash
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
```

- [ ] **Step 3: Update artifact tests to define the new runner contract**

Change `tests/test-artifacts.sh` to require:

```bash
grep -F 'apt-get install -y --no-install-recommends ca-certificates curl jq' \
  "$DOCKERFILE" >/dev/null
grep -F 'GITHUB_PAT' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'github_pat="$GITHUB_PAT"' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'unset GITHUB_PAT' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'Authorization' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F "trap 'forward_signal INT 130' INT" "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F "trap 'forward_signal TERM 143' TERM" "$ROOT/runner/entrypoint.sh" >/dev/null
```

Reject runner-side App implementation:

```bash
if grep -E 'GITHUB_APP_|github_app_jwt|INSTALLATION_TOKEN_API_URL|openssl dgst' \
  "$ROOT/runner/entrypoint.sh" >/dev/null; then
  echo "FAIL: runner entrypoint still contains GitHub App authentication" >&2
  exit 1
fi

if grep -F 'openssl' "$DOCKERFILE" >/dev/null; then
  echo "FAIL: runner image still installs OpenSSL for removed App JWT signing" >&2
  exit 1
fi
```

- [ ] **Step 4: Run the focused tests and confirm they fail**

Run:

```bash
bash tests/runner/test-entrypoint.sh
bash tests/test-artifacts.sh
```

Expected: both fail because the implementation still requires GitHub App
credentials and the image still installs OpenSSL.

- [ ] **Step 5: Rewrite `runner/entrypoint.sh` for PAT-backed token requests**

Replace App validation and JWT functions with:

```bash
required_variables=(
  GITHUB_PAT
  GH_URL
  REGISTRATION_TOKEN_API_URL
)

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
github_pat="$GITHUB_PAT"
unset GITHUB_PAT

github_api_token() {
  local url="$1"
  local authorization_header
  printf -v authorization_header '%s: %s %s' \
    'Authorization' 'Bearer' "$github_pat"
  curl --fail --silent --show-error --request POST \
    --header 'Accept: application/vnd.github+json' \
    --header "$authorization_header" \
    --header 'X-GitHub-Api-Version: 2026-03-10' \
    "$url" |
    jq --exit-status --raw-output \
      '.token | select(type == "string" and length > 0)'
}
```

Update registration:

```bash
printf 'Requesting registration token\n'
registration_token="$(github_api_token "$REGISTRATION_TOKEN_API_URL")"
```

Update cleanup:

```bash
cleanup() {
  local cleanup_status=0 removal_token=""

  if [[ "$CLEANED_UP" == "1" ]]; then
    return 0
  fi
  CLEANED_UP=1

  if [[ ! -f .runner ]]; then
    return 0
  fi

  set +e
  removal_token="$(github_api_token "$REMOVAL_TOKEN_API_URL")"
  cleanup_status=$?
  if [[ "$cleanup_status" == "0" ]]; then
    ./config.sh remove --token "$removal_token"
    cleanup_status=$?
  fi
  set -e

  if [[ "$cleanup_status" != "0" ]]; then
    printf 'ERROR: Runner cleanup failed with status %s\n' "$cleanup_status" >&2
  fi
  return 0
}
```

Preserve signal exit codes while explicitly forwarding signals to the runner
child:

```bash
runner_pid=""

forward_signal() {
  local signal_name="$1"
  local exit_status="$2"
  if [[ -n "$runner_pid" ]]; then
    kill -s "$signal_name" "$runner_pid" 2>/dev/null || true
  fi
  exit "$exit_status"
}

trap cleanup EXIT
trap 'forward_signal INT 130' INT
trap 'forward_signal TERM 143' TERM
```

Run the child in the background so its PID is available to the traps:

```bash
printf 'Runner configured: %s\n' "$RUNNER_NAME"
set +e
./run.sh &
runner_pid=$!
wait "$runner_pid"
runner_status=$?
runner_pid=""
set -e
printf 'Runner process exited with status %s\n' "$runner_status"
exit "$runner_status"
```

- [ ] **Step 6: Remove OpenSSL from the runner image**

Change the Dockerfile package line to:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 7: Run focused validation**

Run:

```bash
bash -n runner/entrypoint.sh
bash tests/runner/test-entrypoint.sh
bash tests/test-artifacts.sh
```

Expected:

```text
PASS: entrypoint behavior
PASS: runner image and workflow artifacts
```

- [ ] **Step 8: Commit the runner migration**

```bash
git add runner/entrypoint.sh runner/Dockerfile \
  tests/runner/test-entrypoint.sh tests/test-artifacts.sh
git commit -m "feat: authenticate runner bootstrap with fine-grained PAT" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Replace Module 01 GitHub App Setup with Fine-Grained PAT Setup

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh`
- Modify: `docs/01-prerequisites-github.md`

**Interfaces:**
- Produces Cloud Shell variables: `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_PAT`.
- Produces verified capabilities: private repository metadata read, Actions read, and runner administration token creation.
- Preserves all Azure subscription, extension, provider, private-repository, clone, navigation, and module 02 guidance.

- [ ] **Step 1: Rewrite module 01 contract tests for Fine-grained PAT setup**

Replace the GitHub App string list in
`tests/docs/test-prerequisites-foundation.sh` with:

```bash
for text in \
  'Visibility | **Private**' \
  'Fine-grained personal access token' \
  'Personal access tokens' \
  'Fine-grained tokens' \
  'Generate new token' \
  'Resource owner' \
  'Expiration | **30 days**' \
  'Only select repositories' \
  'aca-runner-lab' \
  'Actions | Read-only' \
  'Administration | Read and write' \
  'Metadata | Read-only' \
  'Enterprise Managed User' \
  'organization approval' \
  'read -rsp "Fine-grained PAT: " GITHUB_PAT' \
  'printf '\''\n'\''' \
  'GITHUB_OWNER' \
  'GITHUB_REPO' \
  'GITHUB_PAT' \
  'X-GitHub-Api-Version: 2026-03-10' \
  '/actions/runs?per_page=1' \
  '/actions/runners/registration-token' \
  'Repository access: OK' \
  'Actions read: OK' \
  'Runner administration: OK' \
  'read -rp "Workshop repository URL: " WORKSHOP_REPO_URL' \
  'git clone "$WORKSHOP_REPO_URL" ~/aca-github-runner-workshop' \
  'az extension add --name containerapp --upgrade --only-show-errors' \
  'az provider register -n Microsoft.App --wait' \
  'az provider register -n Microsoft.OperationalInsights --wait' \
  'az provider register -n Microsoft.Insights --wait'; do
  grep -F -- "$text" "$PREREQ" >/dev/null ||
    { echo "FAIL: module 01 missing $text" >&2; exit 1; }
done
```

Add negative checks:

```bash
if grep -E 'GITHUB_APP_|GitHub Apps|Generate a private key|installation ID|PEM' \
  "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 still documents GitHub App authentication' >&2
  exit 1
fi

if grep -nE '^[[:space:]]*(printf|echo|cat)\b.*\$GITHUB_PAT([^[:alnum:]_]|$)' \
  "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 prints the Fine-grained PAT' >&2
  exit 1
fi
```

Keep every existing module 02 assertion unchanged.

- [ ] **Step 2: Run the module 01 contract test and confirm it fails**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: FAIL because module 01 still documents GitHub App setup.

- [ ] **Step 3: Rewrite module 01 sections 5 through 8**

Use this section structure:

```markdown
## 5. Fine-grained PAT 만들기
## 6. Cloud Shell 변수로 PAT 안전하게 로드
## 7. 저장소·Actions·runner administration 권한 검증
## 8. 검증
```

In section 5, document this navigation and settings:

```markdown
Fine-grained personal access token (PAT)을 사용해 GitHub App 설치 없이
repository-scoped 인증을 구성합니다.

GitHub에서 **Settings → Developer settings → Personal access tokens →
Fine-grained tokens → Generate new token**으로 이동합니다.

| 항목 | 값 |
|---|---|
| Token name | `aca-runner-lab` |
| Resource owner | `aca-runner-lab`을 소유한 user 또는 organization |
| Expiration | **30 days** |
| Repository access | **Only select repositories** |
| Selected repository | `aca-runner-lab` |

| Permission | Access |
|---|---|
| Actions | Read-only |
| Administration | Read and write |
| Metadata | Read-only |
```

Include these policy statements:

```markdown
- Enterprise Managed User는 개인 계정 GitHub App 설치가 금지될 수 있으므로
  이 워크숍은 App 설치를 요구하지 않습니다.
- organization 정책이 Fine-grained PAT 승인을 요구하면 승인 완료 후 다음
  단계로 진행합니다.
- enterprise 정책이 PAT 생성을 금지하면 관리자의 정책 변경 또는 승인 없이
  이 인증 경로를 진행할 수 없습니다.
```

- [ ] **Step 4: Add non-echoing PAT input**

Use:

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rsp "Fine-grained PAT: " GITHUB_PAT
printf '\n'

export GITHUB_OWNER GITHUB_REPO GITHUB_PAT
printf 'GITHUB_OWNER=%s\nGITHUB_REPO=%s\nGITHUB_PAT=%s\n' \
  "$GITHUB_OWNER" \
  "$GITHUB_REPO" \
  "${GITHUB_PAT:+SET}"
```

State that the prompt does not echo the PAT, shell history stores only the
literal command, and participants must not paste the token into command text,
logs, screenshots, or files.

- [ ] **Step 5: Add non-secret API verification**

Use one temporary header and suppress returned tokens:

```bash
printf -v PAT_AUTH_HEADER '%s: %s %s' \
  'Authorization' 'Bearer' "$GITHUB_PAT"

curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$PAT_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO" |
  jq --exit-status '.private == true' >/dev/null
printf 'Repository access: OK\n'

curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$PAT_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runs?per_page=1" |
  jq --exit-status '.total_count >= 0' >/dev/null
printf 'Actions read: OK\n'

curl --fail --silent --show-error --request POST \
  --header 'Accept: application/vnd.github+json' \
  --header "$PAT_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token" |
  jq --exit-status '.token | type == "string" and length > 0' >/dev/null
printf 'Runner administration: OK\n'

unset PAT_AUTH_HEADER
```

Explain that the short-lived verification registration token is discarded
without being displayed and that `GITHUB_PAT` remains in the current Cloud
Shell session for module 04.

- [ ] **Step 6: Replace troubleshooting with PAT-specific causes**

Cover these exact cases:

- `401 Unauthorized`: copied token is wrong, expired, or revoked.
- `403 Forbidden`: organization approval is pending or enterprise policy
  blocks Fine-grained PAT use.
- Repository check failure: wrong resource owner or selected repository.
- Actions check failure: Actions permission is not read-only or higher.
- Runner administration failure: Administration is not read and write.
- Empty variable after reconnect: rerun the non-echoing input block.

- [ ] **Step 7: Run the documentation contract test**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected:

```text
PASS: prerequisites and foundation docs
```

- [ ] **Step 8: Commit module 01**

```bash
git add docs/01-prerequisites-github.md \
  tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: replace GitHub App setup with fine-grained PAT" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Configure the Runner Image and Event Job for the Shared PAT

**Files:**
- Modify: `tests/docs/test-build-deploy.sh`
- Modify: `docs/03-runner-image.md`
- Modify: `docs/04-event-job-keda.md`

**Interfaces:**
- Consumes module 01 variables: `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_PAT`.
- Stores ACA secret: `personal-access-token`.
- Produces KEDA auth mapping: `personalAccessToken=personal-access-token`.
- Produces runner environment mapping: `GITHUB_PAT=secretref:personal-access-token`.
- Preserves all Azure resource recovery, image, UAMI, ACR, scaling, CPU, memory, and safe Job-recreation settings.

- [ ] **Step 1: Rewrite module 03 and 04 contract assertions**

In `tests/docs/test-build-deploy.sh`, replace module 03 App/OpenSSL assertions
with:

```bash
for text in \
  'ca-certificates`, `curl`, `jq`' \
  'Fine-grained PAT' \
  'GITHUB_PAT' \
  'non-exported wrapper-shell variable' \
  'unset' \
  'workflow process cannot inherit the PAT'; do
  grep -F -- "$text" "$IMAGE_DOC" >/dev/null ||
    { echo "FAIL: module 03 missing $text" >&2; exit 1; }
done

if grep -E 'GitHub App|GITHUB_APP_|installation token|openssl' \
  "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 still describes GitHub App bootstrap" >&2
  exit 1
fi
```

Replace module 04 App assertions with:

```bash
for text in \
  'read -rsp "Fine-grained PAT: " GITHUB_PAT' \
  'personalAccessToken=personal-access-token' \
  'personal-access-token=$GITHUB_PAT' \
  'GITHUB_PAT=secretref:personal-access-token' \
  'unset JOB_CREATE_ARGS GITHUB_PAT' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null ||
    { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

if grep -E 'GITHUB_APP_|applicationID=|installationID=|appKey=|github-app-private-key|PEM' \
  "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 still contains GitHub App configuration" >&2
  exit 1
fi
```

Keep every unrelated resource, KEDA metadata, scaling, saved ACR name,
identity, CPU, memory, and Job recovery assertion.

- [ ] **Step 2: Run the build/deploy documentation test and confirm it fails**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: FAIL because modules 03 and 04 still describe App credentials.

- [ ] **Step 3: Update module 03's runner description**

Change the dependency and bootstrap bullets to:

```markdown
- 필수 유틸리티 `ca-certificates`, `curl`, `jq`만 추가 설치하고 마지막에
  `USER runner`로 내려가 non-root로 실행합니다.
- `runner/entrypoint.sh`는 Fine-grained PAT를 non-exported wrapper-shell
  variable로 복사한 뒤 exported `GITHUB_PAT`를 unset합니다.
- wrapper는 PAT로 registration token과 cleanup 시 remove token을 요청하지만,
  workflow process cannot inherit the PAT.
- `./config.sh --ephemeral --disableupdate`를 사용하므로 Job 1회당 1회성
  runner가 뜨고 컨테이너 안에서 자체 업데이트를 시도하지 않습니다.
```

Replace the English App-isolation sentence with:

```text
The exported GITHUB_PAT is unset before the workflow runner starts.
```

- [ ] **Step 4: Replace module 04 credential reload**

Rename section 2 to `Fine-grained PAT 입력값 다시 로드` and use:

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rsp "Fine-grained PAT: " GITHUB_PAT
printf '\n'

export GITHUB_OWNER GITHUB_REPO GITHUB_PAT
```

Explain that the token must be the approved, unexpired token from module 01
with access only to the lab repository.

- [ ] **Step 5: Replace module 04 KEDA and runner authentication arguments**

Keep the existing metadata through `targetWorkflowQueueLength=1`, then use:

```bash
  # scaler는 Job secret에 저장된 Fine-grained PAT로 GitHub queue를 조회합니다.
  --scale-rule-auth "personalAccessToken=personal-access-token"
  --secrets "personal-access-token=$GITHUB_PAT"

  # entrypoint는 같은 secret으로 short-lived runner token을 발급한 뒤
  # workflow process를 시작하기 전에 exported GITHUB_PAT를 제거합니다.
  --env-vars
  "GITHUB_PAT=secretref:personal-access-token"
  "GH_URL=https://github.com/$GITHUB_OWNER/$GITHUB_REPO"
  "REGISTRATION_TOKEN_API_URL=https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token"
  "RUNNER_LABELS=aca-runner"
  "RUNNER_NAME_PREFIX=aca"
```

Remove `applicationID`, `installationID`, `appKey`, App ID environment
variables, and PEM secret references. End the command block with:

```bash
az containerapp job create "${JOB_CREATE_ARGS[@]}"
unset JOB_CREATE_ARGS GITHUB_PAT
```

- [ ] **Step 6: Replace module 04 validation and troubleshooting terminology**

State that `job show` does not query secret values and therefore does not
display the PAT. Troubleshooting must cover:

- Queue does not scale: token expired, revoked, pending approval, or wrong
  selected repository.
- Rule exists but does not scale: verify `githubApiURL`, owner, repo scope,
  repo, label, queue length, and `personalAccessToken`.
- Execution authentication failure: reload the module 01 PAT and recreate only
  the workshop Job.
- `403`: verify Actions read-only, Administration read and write, Metadata
  read-only, and organization approval.
- Recently rotated token: recreate the Job so the ACA secret and both
  consumers use the new token.

- [ ] **Step 7: Run focused documentation validation**

Run:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/test-artifacts.sh
```

Expected:

```text
PASS: image build and Event Job docs
PASS: runner image and workflow artifacts
```

- [ ] **Step 8: Commit image and deployment documentation**

```bash
git add docs/03-runner-image.md docs/04-event-job-keda.md \
  tests/docs/test-build-deploy.sh
git commit -m "docs: configure KEDA and runner with shared PAT" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Update Workshop Overview, Scale Guidance, and PAT Lifecycle

**Files:**
- Modify: `tests/docs/test-overview.sh`
- Modify: `README.md`
- Modify: `tests/docs/test-scale-validation.sh`
- Modify: `docs/05-parallel-scale-validation.md`
- Modify: `tests/docs/test-security-cleanup.sh`
- Modify: `docs/06-security-limitations-cleanup.md`

**Interfaces:**
- Consumes the authentication terms defined by modules 01, 03, and 04.
- Produces a 90-minute workshop schedule.
- Produces participant guidance for PAT approval, rotation, revocation, and stale runner cleanup.
- Preserves matrix workflow, `0 → N → 0`, screenshots, logging, Azure cleanup, private repository, and Docker limitations.

- [ ] **Step 1: Rewrite overview timing and prerequisite tests**

In `tests/docs/test-overview.sh`, require:

```bash
grep -F '약 90분' "$README" >/dev/null
grep -F '| Fine-grained PAT 생성·승인 |' "$README" >/dev/null
grep -F '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | Cloud Shell 변수, `Private repository`, Fine-grained PAT 준비 | 15분 |' "$README" >/dev/null
grep -F '|  | **합계** |  | **90분** |' "$README" >/dev/null
grep -F '| 1부 | GitHub 준비 + Azure 기반 리소스 준비 | 30분 |' "$README" >/dev/null
grep -F '| 합계 | 코어 워크숍 | 90분 |' "$README" >/dev/null
grep -F 'Fine-grained PAT 인증 경로의 라이브 Azure/GitHub 리허설' \
  "$README" >/dev/null
```

Reject:

```bash
if grep -E '약 105분|GitHub App 생성 권한|라이브 Azure/GitHub App 리허설' \
  "$README" >/dev/null; then
  echo 'FAIL: README still advertises the GitHub App workshop' >&2
  exit 1
fi
```

- [ ] **Step 2: Rewrite scale-validation authentication tests**

In `tests/docs/test-scale-validation.sh`, require:

```bash
for text in \
  'Fine-grained PAT' \
  'GITHUB_PAT' \
  'personal-access-token' \
  'token approval' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    { echo "FAIL: module 05 missing $text" >&2; exit 1; }
done
```

Reject:

```bash
if grep -E 'GitHub App|GITHUB_APP_|KEDA GitHub App credential|private key' \
  "$DOC" >/dev/null; then
  echo "FAIL: module 05 still contains GitHub App guidance" >&2
  exit 1
fi
```

Keep screenshot, matrix, execution, log, lifecycle-marker, and scale-in
assertions unchanged.

- [ ] **Step 3: Rewrite security and cleanup tests**

In `tests/docs/test-security-cleanup.sh`, require:

```bash
for text in \
  'Fine-grained PAT' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only' \
  'Only select repositories' \
  '30 days' \
  'PAT rotation' \
  'ACA secret을 새 PAT로 먼저 갱신' \
  '기존 PAT를 revoke' \
  'PAT 삭제' \
  'Azure Key Vault' \
  'external token broker'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    { echo "FAIL: module 06 missing $text" >&2; exit 1; }
done
```

Reject:

```bash
if grep -E 'GitHub App|GITHUB_APP_|App ID/installation ID|private key PEM' \
  "$DOC" >/dev/null; then
  echo "FAIL: module 06 still contains GitHub App cleanup" >&2
  exit 1
fi
```

Keep `.gitignore`, Azure cleanup, resource-group safety, suffix, production
networking, Docker limitations, and section-number assertions.

- [ ] **Step 4: Run the three documentation tests and confirm they fail**

Run:

```bash
bash tests/docs/test-overview.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected: all fail on the current GitHub App terminology or 105-minute timing.

- [ ] **Step 5: Update README timing and prerequisites**

Change module 01 from 25 to 15 minutes and remove the separate 5-minute buffer
row. Use these totals:

```markdown
| 00 | (현재 문서) | 전체 개요, 아키텍처, 목표, 비용, 이동 경로 | 5분 |
| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | Cloud Shell 변수, `Private repository`, Fine-grained PAT 준비 | 15분 |
| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | RG, Log Analytics, ACA environment, ACR, UAMI, `AcrPull` 구성 | 15분 |
| 03 | [Runner image 빌드](docs/03-runner-image.md) | runner/entrypoint 이해와 ACR Tasks 빌드 | 10분 |
| 04 | [Event Job + KEDA 구성](docs/04-event-job-keda.md) | ACA Event Job, secret, KEDA `github-runner` rule 설정 | 15분 |
| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4 Job, 0 → N → 0, GitHub·CLI·로그 확인 | 20분 |
| 06 | [보안·제약·정리](docs/06-security-limitations-cleanup.md) | 보안 주의사항, 한계, 리소스 삭제와 최종 확인 | 10분 |
|  | **합계** |  | **90분** |
```

Use this timetable:

```markdown
| 시작 | 개요 및 실습 범위 확인 | 5분 |
| 1부 | GitHub 준비 + Azure 기반 리소스 준비 | 30분 |
| 2부 | runner image 빌드 + Event Job/KEDA 구성 | 25분 |
| 3부 | 병렬 workflow 검증 + 로그 확인 | 20분 |
| 마무리 | 보안·제약 정리 + 리소스 삭제 | 10분 |
| 합계 | 코어 워크숍 | 90분 |
```

Replace the App prerequisite with:

```markdown
| Fine-grained PAT 생성·승인 | lab repository만 선택한 Fine-grained PAT를 만들 수 있어야 하며, organization 정책이 요구하면 승인을 받아야 합니다. |
```

Change the validation note to say the Fine-grained PAT Azure/GitHub path has
not been separately live-rehearsed unless a live rehearsal is actually run
during implementation.

- [ ] **Step 6: Replace module 05 authentication explanations**

Explain that browser-based workflow creation keeps repository-write activity
separate from the PAT used by KEDA and runner bootstrap. Do not imply that the
PAT grants Contents write permission.

Replace troubleshooting with:

- Queued job remains: PAT revoked, expired, pending `token approval`, wrong repository,
  or label mismatch.
- `401/403`: check approval and the three exact repository permissions.
- KEDA cannot monitor queue: verify ACA secret `personal-access-token` and
  `personalAccessToken` mapping.
- Runner registration fails: verify Administration read and write.
- Secret rotation: recreate only the Job with the replacement PAT.

Preserve every existing matrix, screenshot, active execution, CLI log, KQL,
lifecycle-marker, scale-in, and stale runner statement.

- [ ] **Step 7: Rewrite module 06 PAT security and cleanup**

Use this production comparison:

```markdown
| Workshop choice | Production extension | Reason |
|---|---|---|
| ACA secret의 단일 Fine-grained PAT | separate credentials, Azure Key Vault 또는 external token broker | stronger credential isolation and centralized rotation |
| registration token 방식 | GitHub JIT runner | reduced registration lifecycle exposure |
```

Security rules must state:

- Limit repository access to `Only select repositories`.
- Keep Actions read-only, Administration read and write, Metadata read-only.
- Prefer 30 days for the workshop and rotate before expiration.
- Never print the PAT, registration token, or remove token.
- Restrict workflow changes to trusted authors.

Add the heading `### PAT rotation` and this rotation order:

```markdown
1. 새 Fine-grained PAT를 같은 repository와 permission으로 생성하고 필요한
   organization approval을 완료합니다.
2. ACA secret을 새 PAT로 먼저 갱신하고 Job이 queue 감시와 runner 등록을
   정상 수행하는지 확인합니다.
3. 정상 동작 확인 후 기존 PAT를 revoke합니다.
```

GitHub cleanup must include:

```markdown
1. 실습용 Fine-grained PAT를 revoke하여 PAT 삭제를 완료합니다.
2. Cloud Shell에서 `unset GITHUB_PAT`를 실행합니다.
3. `.github/workflows/aca-runner-scale-test.yml`, stale runner record, lab
   repository 보존 여부를 정리합니다.
```

Update the module completion table so module 01 says Fine-grained PAT
verification and module 06 says PAT lifecycle cleanup.

Remove all remaining `GitHub App` wording from module 06, including the API
limits row and production recommendations. Describe high-scale production
options as separate credentials or an external token broker instead.

- [ ] **Step 8: Run focused documentation validation**

Run:

```bash
bash tests/docs/test-overview.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected:

```text
PASS: README contract
PASS: parallel scale validation doc
PASS: security and cleanup doc
```

- [ ] **Step 9: Commit cross-workshop guidance**

```bash
git add README.md docs/05-parallel-scale-validation.md \
  docs/06-security-limitations-cleanup.md \
  tests/docs/test-overview.sh tests/docs/test-scale-validation.sh \
  tests/docs/test-security-cleanup.sh
git commit -m "docs: align workshop guidance with fine-grained PAT" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Invert Integrated Validation and Verify the Complete Migration

**Files:**
- Modify: `tests/validate-workshop.sh`
- Test unchanged: `tests/test-validate-workshop.sh`
- Test unchanged: `.github/workflows/validate-workshop.yml`

**Interfaces:**
- Consumes all runner and documentation contracts from Tasks 1 through 4.
- Produces one integrated validation command: `bash tests/validate-workshop.sh`.
- Rejects operational GitHub App configuration while allowing the PAT design and plan records under `docs/superpowers/`.

- [ ] **Step 1: Add integrated checks for leftover App configuration**

Replace the PAT-rejection block in `tests/validate-workshop.sh` with:

```bash
github_app_configuration_pattern='GITHUB_APP_ID|GITHUB_APP_INSTALLATION_ID|GITHUB_APP_PRIVATE_KEY|applicationID=|installationID=|appKey=|github-app-private-key|/app/installations/|github_app_jwt|openssl dgst'
if grep -RInE "$github_app_configuration_pattern" "${core_workshop_paths[@]}"; then
  echo 'FAIL: GitHub App workshop configuration found' >&2
  exit 1
fi
```

Add required PAT checks:

```bash
for text in \
  'GITHUB_PAT' \
  'github_pat="$GITHUB_PAT"' \
  'unset GITHUB_PAT'; do
  grep -F -- "$text" runner/entrypoint.sh >/dev/null || {
    printf 'FAIL: runner entrypoint missing %s\n' "$text" >&2
    exit 1
  }
done

for text in \
  'personalAccessToken=personal-access-token' \
  'personal-access-token=$GITHUB_PAT' \
  'GITHUB_PAT=secretref:personal-access-token'; do
  grep -F -- "$text" docs/04-event-job-keda.md >/dev/null || {
    printf 'FAIL: module 04 missing %s\n' "$text" >&2
    exit 1
  }
done
```

Do not add `docs/superpowers/` to `core_workshop_paths`; the specification and
plan necessarily discuss both old and new authentication designs.

- [ ] **Step 2: Run the integrated validator against the completed focused changes**

Run:

```bash
bash tests/validate-workshop.sh
```

Expected:

```text
PASS: complete workshop validation
```

If it fails, use the reported focused test or forbidden-pattern match to fix
the corresponding Task 1 through 4 file before continuing.

- [ ] **Step 3: Run the complete validator after Tasks 1 through 4**

Run:

```bash
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
```

Expected:

```text
PASS: complete workshop validation
PASS: integrated workshop validator
```

- [ ] **Step 4: Search operational files for forbidden App implementation**

Run:

```bash
grep -RInE \
  'GITHUB_APP_ID|GITHUB_APP_INSTALLATION_ID|GITHUB_APP_PRIVATE_KEY|applicationID=|installationID=|appKey=|github-app-private-key|/app/installations/|github_app_jwt|openssl dgst' \
  README.md docs/01-prerequisites-github.md docs/03-runner-image.md \
  docs/04-event-job-keda.md docs/05-parallel-scale-validation.md \
  docs/06-security-limitations-cleanup.md runner \
  && exit 1 || true
```

Expected: no matches.

- [ ] **Step 5: Verify the working tree contains only intended migration changes**

Run:

```bash
git status --short
git diff --check
git diff --stat
```

Expected: only the authentication migration files listed in this plan are
modified, and `git diff --check` reports no whitespace errors.

- [ ] **Step 6: Commit the integrated validator**

```bash
git add tests/validate-workshop.sh
git commit -m "test: validate fine-grained PAT workshop configuration" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 7: Run final validation from the committed tree**

Run:

```bash
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
git status --short
```

Expected: both validators pass and the working tree is clean.
