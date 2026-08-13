# GitHub App Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace PAT authentication with a repository-scoped GitHub App for KEDA scaling and ephemeral runner registration, while correcting the workshop review findings.

**Architecture:** Store one GitHub App private key as an Azure Container Apps secret. KEDA consumes it through `appKey`; the runner entrypoint copies the PEM into a non-exported wrapper-shell variable, unsets the exported secret variable, creates short-lived JWTs and installation tokens for registration, and during cleanup mints a fresh JWT, installation token, and removal token before removing local runner state. This human-approved cleanup amendment supersedes the earlier pre-acquired removal-token draft.

**Tech Stack:** Bash, OpenSSL, curl, jq, Azure CLI Container Apps extension, KEDA `github-runner` scaler, GitHub REST API `2026-03-10`, GitHub Actions.

## Global Constraints

- Runner scope remains `repo`.
- The lab repository remains private and the GitHub App is installed only on `aca-runner-lab`.
- Required repository permissions are Actions read-only, Administration read and write, and Metadata read-only.
- KEDA metadata key is exactly `githubApiURL`, not `githubAPIURL`.
- Runner image version remains `2.336.0`.
- Event Job settings remain `min-executions=0`, `max-executions=5`, `polling-interval=30`, and `targetWorkflowQueueLength=1`.
- Workflow processes must not inherit the GitHub App private key, JWT, or installation access token.
- Workshop duration totals approximately 105 minutes.
- Do not add Azure Key Vault, an external token broker, JIT runner configuration, or live billable Azure tests.
- Preserve the original runner process exit status even when cleanup fails.

## File Structure

- Modify `runner/entrypoint.sh`: GitHub App JWT, installation-token, registration-token, and cleanup flow.
- Modify `runner/Dockerfile`: explicitly install OpenSSL.
- Modify `tests/runner/test-entrypoint.sh`: mock and verify the GitHub App flow and credential isolation.
- Modify `README.md`: timing, architecture wording, prerequisites, troubleshooting, and rehearsal claim.
- Modify `docs/01-prerequisites-github.md`: replace Fine-grained PAT instructions with GitHub App setup and verification.
- Modify `docs/02-azure-foundation.md`: RBAC prerequisite detail, six-character suffix, and safe ACR collision recovery.
- Modify `docs/03-runner-image.md`: describe GitHub App bootstrap and OpenSSL dependency.
- Modify `docs/04-event-job-keda.md`: configure KEDA and the Job with GitHub App credentials.
- Modify `docs/05-parallel-scale-validation.md`: GitHub App troubleshooting and accurate screenshot wording.
- Modify `docs/06-security-limitations-cleanup.md`: production comparison, App cleanup, private-key cleanup, and section numbering.
- Modify `tests/docs/*.sh`: update document contracts for the new authentication flow and corrections.
- Modify `tests/test-artifacts.sh`: assert OpenSSL and reject PAT-based runner artifacts.
- Modify `tests/validate-workshop.sh`: reject PAT configuration in core workshop artifacts while excluding design/plan documents.
- Create `.github/workflows/validate-workshop.yml`: run the integrated validator on pushes and pull requests.

---

### Task 1: Implement GitHub App Runner Bootstrap

**Files:**
- Modify: `tests/runner/test-entrypoint.sh`
- Modify: `runner/entrypoint.sh`
- Modify: `runner/Dockerfile`

**Interfaces:**
- Consumes environment variables: `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`, `GH_URL`, `REGISTRATION_TOKEN_API_URL`, optional `RUNNER_LABELS`, optional `RUNNER_NAME_PREFIX`.
- Produces functions: `base64url()`, `github_app_jwt()`, `github_api_token(url, bearer_token)`, and existing `cleanup()`.
- Produces behavior: the exported private key is removed before `./run.sh`, while App JWTs and installation tokens stay non-exported and command-scoped.

- [ ] **Step 1: Rewrite the fixture inputs and mocks to express the GitHub App flow**

Replace the PAT-specific mock setup in `tests/runner/test-entrypoint.sh` with:

```bash
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
printf '%s\n' "$*" >>"$MOCK_CALLS/curl.log"
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
```

Change the mock `run.sh` to capture its inherited environment:

```bash
cat >"$FIXTURE/runner/run.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
env | sort >"$MOCK_CALLS/run-env.log"
printf 'run\n' >>"$MOCK_CALLS/run.log"
exit "${MOCK_RUN_EXIT:-0}"
EOF2
```

Add `"$FIXTURE/bin/openssl"` to the `chmod +x` command.

- [ ] **Step 2: Write failing tests for required values and malformed values**

Change `run_entrypoint()` to pass:

```bash
GITHUB_APP_ID="${GITHUB_APP_ID-}" \
GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID-}" \
GITHUB_APP_PRIVATE_KEY="${GITHUB_APP_PRIVATE_KEY-}" \
```

Remove `GITHUB_PAT`.

Add assertions:

```bash
[[ "$output" == *"GITHUB_APP_ID is required"* ]] ||
  fail "missing-variable error is unclear"

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
```

- [ ] **Step 3: Write the failing successful-flow assertions**

Use valid fixture values:

```bash
export GITHUB_APP_ID="12345"
export GITHUB_APP_INSTALLATION_ID="67890"
export GITHUB_APP_PRIVATE_KEY=$'-----BEGIN RSA PRIVATE KEY-----\nmock-private-key\n-----END RSA PRIVATE KEY-----'
export GH_URL="https://github.com/example/private-repo"
export REGISTRATION_TOKEN_API_URL="https://api.github.com/repos/example/private-repo/actions/runners/registration-token"
export RUNNER_LABELS="aca-runner"
export RUNNER_NAME_PREFIX="aca"
output="$(run_entrypoint 2>&1)"
```

Assert:

```bash
grep -F -- "/app/installations/67890/access_tokens" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "installation token was not requested"
grep -F -- "Authorization: Bearer installation-token-value" "$MOCK_CALLS/curl.log" >/dev/null ||
  fail "installation token was not used"
grep -F -- "remove --token remove-token-value" "$MOCK_CALLS/config.log" >/dev/null ||
  fail "cleanup missing"
[[ "$output" != *"mock-private-key"* ]] || fail "private key leaked to output"
[[ "$output" != *"installation-token-value"* ]] || fail "installation token leaked to output"
if grep -E 'GITHUB_APP_PRIVATE_KEY|installation-token-value|mock-private-key' \
  "$MOCK_CALLS/run-env.log" >/dev/null; then
  fail "long-lived GitHub App credentials reached the runner process"
fi
```

Keep the existing `--ephemeral`, `--unattended`, `--disableupdate`, label, API failure, cleanup, and runner exit-status assertions.

- [ ] **Step 4: Run the entrypoint test and confirm it fails**

Run:

```bash
bash tests/runner/test-entrypoint.sh
```

Expected: FAIL because `runner/entrypoint.sh` still requires `GITHUB_PAT` and does not request an installation token.

- [ ] **Step 5: Add OpenSSL to the image**

Change the install line in `runner/Dockerfile` to:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 6: Replace PAT validation with GitHub App validation**

At the top of `runner/entrypoint.sh`, use:

```bash
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
```

Keep the registration-token URL suffix validation.

- [ ] **Step 7: Implement JWT and API token helpers**

Replace `github_token()` with:

```bash
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
```

- [ ] **Step 8: Keep startup credentials scoped and mint cleanup credentials on demand**

Human-approved amendment: do **not** switch the working implementation back to a pre-acquired removal token. Keep the PEM only in a non-exported wrapper-shell variable, request the registration token with a command-scoped installation token, and mint fresh cleanup credentials only after `run.sh` exits.

During startup, use:

```bash
INSTALLATION_TOKEN_API_URL="https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens"
github_app_private_key="$GITHUB_APP_PRIVATE_KEY"
unset GITHUB_APP_PRIVATE_KEY

printf 'Requesting registration token\n'
registration_token="$(
  installation_token="$(github_installation_token)"
  github_api_token "$REGISTRATION_TOKEN_API_URL" "$installation_token"
)"
```

Keep cleanup aligned with the checked-in implementation:

```bash
cleanup() {
  local cleanup_status=0 installation_token="" removal_token=""

  if [[ "$CLEANED_UP" == "1" ]]; then
    return 0
  fi
  CLEANED_UP=1

  if [[ ! -f .runner ]]; then
    return 0
  fi

  set +e
  installation_token="$(github_installation_token)"
  cleanup_status=$?
  if [[ "$cleanup_status" == "0" ]]; then
    removal_token="$(github_api_token "$REMOVAL_TOKEN_API_URL" "$installation_token")"
    cleanup_status=$?
  fi
  if [[ "$cleanup_status" == "0" ]]; then
    ./config.sh remove --token "$removal_token"
    cleanup_status=$?
  fi
  set -e
}
```

- [ ] **Step 9: Run targeted runner tests**

Run:

```bash
bash -n runner/entrypoint.sh
bash tests/runner/test-entrypoint.sh
bash tests/test-artifacts.sh
```

Expected: entrypoint test passes; artifact test fails until Task 2 updates its OpenSSL contract.

- [ ] **Step 10: Commit runner authentication**

```bash
git add runner/Dockerfile runner/entrypoint.sh tests/runner/test-entrypoint.sh
git commit -m "feat: authenticate runner with GitHub App" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Update Artifact and Integrated Authentication Contracts

**Files:**
- Modify: `tests/test-artifacts.sh`
- Modify: `tests/validate-workshop.sh`

**Interfaces:**
- Consumes runner behavior from Task 1.
- Produces repository-wide prohibition of PAT configuration in core workshop files.

- [ ] **Step 1: Update the Dockerfile artifact assertion**

Change:

```bash
grep -F 'apt-get install -y --no-install-recommends ca-certificates curl jq' "$DOCKERFILE" >/dev/null
```

to:

```bash
grep -F 'apt-get install -y --no-install-recommends ca-certificates curl jq openssl' \
  "$DOCKERFILE" >/dev/null
```

Add:

```bash
grep -F 'GITHUB_APP_ID' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'GITHUB_APP_INSTALLATION_ID' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'github_app_jwt' "$ROOT/runner/entrypoint.sh" >/dev/null
if grep -F 'GITHUB_PAT' "$ROOT/runner/entrypoint.sh" >/dev/null; then
  echo "FAIL: runner entrypoint still depends on GITHUB_PAT" >&2
  exit 1
fi
```

- [ ] **Step 2: Define core workshop paths for secret-pattern checks**

In `tests/validate-workshop.sh`, add:

```bash
core_workshop_paths=(
  README.md
  docs/01-prerequisites-github.md
  docs/02-azure-foundation.md
  docs/03-runner-image.md
  docs/04-event-job-keda.md
  docs/05-parallel-scale-validation.md
  docs/06-security-limitations-cleanup.md
  runner
  samples
)
```

Use this array instead of scanning all of `docs`, so tracked design and plan documents can describe the migration without failing the workshop contract.

- [ ] **Step 3: Add a PAT-configuration rejection**

Add:

```bash
pat_configuration_pattern='GITHUB_PAT|personalAccessToken=|personal-access-token'
if grep -RInE "$pat_configuration_pattern" "${core_workshop_paths[@]}"; then
  echo 'FAIL: PAT-based workshop configuration found' >&2
  exit 1
fi
```

Do not scan tests or historical design/plan files because those files intentionally describe and reject the removed configuration.

- [ ] **Step 4: Run targeted contracts**

Run:

```bash
bash tests/test-artifacts.sh
bash tests/validate-workshop.sh
```

Expected: artifact test passes; integrated validation fails on existing PAT documentation until later tasks update it.

- [ ] **Step 5: Commit test contracts**

```bash
git add tests/test-artifacts.sh tests/validate-workshop.sh
git commit -m "test: require GitHub App authentication artifacts" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Replace Module 01 PAT Setup with GitHub App Setup

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh`
- Modify: `docs/01-prerequisites-github.md`

**Interfaces:**
- Produces shell variables consumed by module 04: `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`.

- [ ] **Step 1: Replace module 01 contract strings**

In `tests/docs/test-prerequisites-foundation.sh`, remove PAT-specific strings and require:

```bash
'GitHub Apps' \
'Webhook | **Inactive**' \
'Actions | Read-only' \
'Administration | Read and write' \
'Metadata | Read-only' \
'Only select repositories' \
'aca-runner-lab' \
'GITHUB_APP_ID' \
'GITHUB_APP_INSTALLATION_ID' \
'GITHUB_APP_PRIVATE_KEY_PATH' \
'GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"' \
'openssl dgst -sha256' \
'/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens' \
'X-GitHub-Api-Version: 2026-03-10'
```

Add:

```bash
if grep -E 'Fine-grained PAT|GITHUB_PAT|personal access token' "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 still documents PAT authentication' >&2
  exit 1
fi
```

- [ ] **Step 2: Run the module 01 contract and confirm it fails**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: FAIL because module 01 still contains PAT setup.

- [ ] **Step 3: Replace module 01 goals and GitHub App creation section**

Document:

```markdown
## 5. Repository-scoped GitHub App 만들기

| 항목 | 값 |
|---|---|
| GitHub App name | `aca-runner-lab-<unique-name>` |
| Homepage URL | 실습 repository URL |
| Webhook | **Inactive** |
| Where can this GitHub App be installed? | **Only on this account** |
```

State that the App may be owned by the participant's personal account or organization and must be installed only on `aca-runner-lab`.

- [ ] **Step 4: Add permissions, installation, and key instructions**

Document the exact permissions table from the global constraints. Add steps to:

1. Create the App.
2. Generate a private key.
3. Download the PEM directly into Cloud Shell or upload it to Cloud Shell.
4. Install the App with **Only select repositories** and select `aca-runner-lab`.
5. Read App ID from App settings.
6. Read installation ID from the installation settings URL.

Warn that the PEM is the App's signing credential and must not be committed or printed.

- [ ] **Step 5: Add Cloud Shell variable loading**

Use:

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rp "GitHub App ID: " GITHUB_APP_ID
read -rp "GitHub App installation ID: " GITHUB_APP_INSTALLATION_ID
read -rp "GitHub App private key PEM path: " GITHUB_APP_PRIVATE_KEY_PATH

[[ -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]] || {
  printf 'Private key file not found: %s\n' "$GITHUB_APP_PRIVATE_KEY_PATH" >&2
  return 1 2>/dev/null || exit 1
}

GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"
export GITHUB_OWNER GITHUB_REPO GITHUB_APP_ID
export GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY

printf 'GITHUB_OWNER=%s\nGITHUB_REPO=%s\nGITHUB_APP_ID=%s\nINSTALLATION_ID=%s\nPRIVATE_KEY=%s\n' \
  "$GITHUB_OWNER" \
  "$GITHUB_REPO" \
  "$GITHUB_APP_ID" \
  "$GITHUB_APP_INSTALLATION_ID" \
  "${GITHUB_APP_PRIVATE_KEY:+SET}"
```

- [ ] **Step 6: Add GitHub App verification commands**

Provide local `base64url()` and JWT generation commands equivalent to Task 1. Exchange the JWT:

```bash
printf -v APP_AUTH_HEADER '%s: %s %s' 'Authorization' 'Bearer' "$APP_JWT"
GITHUB_APP_INSTALLATION_TOKEN="$(
  curl --fail --silent --show-error --request POST \
    --header 'Accept: application/vnd.github+json' \
    --header "$APP_AUTH_HEADER" \
    --header 'X-GitHub-Api-Version: 2026-03-10' \
    "https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens" |
    jq --exit-status --raw-output '.token'
)"
```

Verify repository access:

```bash
printf -v INSTALLATION_AUTH_HEADER '%s: %s %s' \
  'Authorization' 'Bearer' "$GITHUB_APP_INSTALLATION_TOKEN"
curl --fail --silent --show-error \
  --header 'Accept: application/vnd.github+json' \
  --header "$INSTALLATION_AUTH_HEADER" \
  --header 'X-GitHub-Api-Version: 2026-03-10' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO" |
  jq '{full_name, private, visibility}'
unset APP_AUTH_HEADER INSTALLATION_AUTH_HEADER APP_JWT
unset GITHUB_APP_INSTALLATION_TOKEN
```

- [ ] **Step 7: Update troubleshooting**

Replace 401/403 PAT causes with:

- App not installed on `aca-runner-lab`.
- Wrong App ID or installation ID.
- PEM does not belong to the App.
- Required App permissions were not granted or installation permissions were not accepted.

- [ ] **Step 8: Run module 01 tests**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: PASS.

- [ ] **Step 9: Commit module 01**

```bash
git add docs/01-prerequisites-github.md tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: replace PAT setup with GitHub App" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Correct Azure Foundation Prerequisites and Naming Recovery

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh`
- Modify: `docs/02-azure-foundation.md`
- Modify: `README.md`
- Modify: `tests/docs/test-overview.sh`

**Interfaces:**
- Produces six-character lowercase hexadecimal `SUFFIX`.
- Documents the required role-assignment capability used by `az role assignment create`.

- [ ] **Step 1: Add failing RBAC and suffix contracts**

Require:

```bash
'Microsoft.Authorization/roleAssignments/write' \
'Role Based Access Control Administrator' \
'SUFFIX="$(openssl rand -hex 3)"' \
'ACR="acracarunner$SUFFIX"'
```

Reject:

```bash
if grep -F 'RANDOM % 100000' "$FOUNDATION" >/dev/null; then
  echo 'FAIL: module 02 still uses low-entropy RANDOM suffixes' >&2
  exit 1
fi
```

In `tests/docs/test-overview.sh`, require `105분` and role-assignment permission wording instead of `약 90분`.

- [ ] **Step 2: Run document contracts and confirm they fail**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-overview.sh
```

Expected: FAIL on existing timing, RBAC, and suffix text.

- [ ] **Step 3: Update README prerequisites and timing**

Replace the Contributor row with two rows:

```markdown
| Azure Contributor | 실습용 Azure 리소스를 만들고 관리할 수 있어야 합니다. |
| Azure RBAC 역할 할당 권한 | ACR 범위에 `AcrPull`을 할당할 수 있도록 `Microsoft.Authorization/roleAssignments/write`가 필요합니다. `Role Based Access Control Administrator`, `User Access Administrator`, `Owner` 등이 해당합니다. |
```

Change approximately 90 minutes to approximately 105 minutes. Increase module 01 from 10 to 25 minutes and the first-part total from 25 to 40 minutes. Recalculate every displayed total to 105 minutes.

Replace the dated rehearsal claim with an honest validation note that distinguishes checked-in automated validation from a live Azure/GitHub App rehearsal. Do not claim that the new authentication path was live-tested unless it is actually executed.

- [ ] **Step 4: Update module 02 suffix generation and examples**

Use:

```bash
SUFFIX="$(openssl rand -hex 3)"
```

Update example suffixes from `01234` to a six-character example such as `a1b2c3`.

- [ ] **Step 5: Correct ACR collision recovery**

Replace the instruction to rerun the entire suffix block with:

```markdown
이미 앞 단계의 RG, workspace, environment를 만들었다면 전체 `SUFFIX`를 바꾸지 마세요.
ACR 이름만 새 전역 고유 값으로 변경한 뒤 `az acr create`부터 다시 실행합니다.

```bash
ACR="acracarunner$(openssl rand -hex 4)"
```

리소스 이름을 모두 새 suffix로 통일하려면 기존 실습 리소스를 정리하고 모듈 02의 1단계부터 다시 시작합니다.
```

Final-review amendment: this step's collision recovery must also print the new `ACR` value and explicitly tell participants to save/replace it, because the actual `ACR` name becomes a workshop value tracked separately from `SUFFIX` once it changes. Modules 03 and 04 must read this saved actual `ACR` name (`read -rp "Saved ACR name: " ACR`) during their reconnect-recovery blocks instead of reconstructing `ACR="acracarunner$SUFFIX"`, while `RG`, `LOG`, `ENV`, `UAMI`, and `JOB` continue to derive from `SUFFIX` only. See Task 5's Step 1 for the corresponding module 03/04 update.

- [ ] **Step 6: Add RBAC prerequisite warning before role assignment**

Immediately before `az role assignment create`, state that Contributor cannot assign Azure roles and the participant must have `Microsoft.Authorization/roleAssignments/write` at the ACR scope or above.

- [ ] **Step 7: Run document contracts**

Run:

```bash
bash tests/docs/test-overview.sh
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: PASS.

- [ ] **Step 8: Commit foundation corrections**

```bash
git add README.md docs/02-azure-foundation.md \
  tests/docs/test-overview.sh tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: correct workshop prerequisites and timing" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Configure the ACA Job and KEDA with GitHub App Credentials

**Files:**
- Modify: `tests/docs/test-build-deploy.sh`
- Modify: `docs/03-runner-image.md`
- Modify: `docs/04-event-job-keda.md`

**Interfaces:**
- Consumes variables from module 01.
- Produces KEDA metadata `applicationID`, `installationID` and auth `appKey=github-app-private-key`.
- Produces container environment variables consumed by Task 1.

- [ ] **Step 1: Replace PAT deployment contracts**

In `tests/docs/test-build-deploy.sh`, remove:

```bash
'personalAccessToken=personal-access-token'
'GITHUB_PAT=secretref:personal-access-token'
```

Require:

```bash
'applicationID=$GITHUB_APP_ID' \
'installationID=$GITHUB_APP_INSTALLATION_ID' \
'appKey=github-app-private-key' \
'github-app-private-key=$GITHUB_APP_PRIVATE_KEY' \
'GITHUB_APP_ID=$GITHUB_APP_ID' \
'GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID' \
'GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key'
```

Reject `GITHUB_PAT`, `personalAccessToken`, and `personal-access-token` in module 04.

- [ ] **Step 2: Run the build/deploy contract and confirm it fails**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: FAIL because module 04 still configures a PAT.

- [ ] **Step 3: Update module 03 runner explanation**

Document that the image uses OpenSSL to sign a short-lived GitHub App JWT and that App credentials are removed from the environment before the workflow runner starts.

Update the package description to include `openssl`.

- [ ] **Step 4: Replace module 04 reconnect inputs**

Use:

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rp "GitHub App ID: " GITHUB_APP_ID
read -rp "GitHub App installation ID: " GITHUB_APP_INSTALLATION_ID
read -rp "GitHub App private key PEM path: " GITHUB_APP_PRIVATE_KEY_PATH
GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"
export GITHUB_OWNER GITHUB_REPO GITHUB_APP_ID
export GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY
```

Validate the PEM file exists before reading it.

Final-review amendment: the module 03 and module 04 Azure-variable reconnect blocks (the section preceding this GitHub App reconnect block) must prompt for the saved actual `ACR` name instead of reconstructing `ACR="acracarunner$SUFFIX"`:

```bash
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved ACR name: " ACR
```

`RG`, `LOG`, `ENV`, `UAMI`, and `JOB` still derive from `SUFFIX` only. This keeps reconnect recovery correct when module 02's ACR collision recovery has renamed `ACR` to a value no longer derivable from `SUFFIX`.

- [ ] **Step 5: Replace KEDA authentication**

In `JOB_CREATE_ARGS`, set:

```bash
--scale-rule-metadata \
"githubApiURL=https://api.github.com"
"owner=$GITHUB_OWNER"
"runnerScope=repo"
"repos=$GITHUB_REPO"
"labels=aca-runner"
"targetWorkflowQueueLength=1"
"applicationID=$GITHUB_APP_ID"
"installationID=$GITHUB_APP_INSTALLATION_ID"

--scale-rule-auth "appKey=github-app-private-key"
--secrets "github-app-private-key=$GITHUB_APP_PRIVATE_KEY"
```

- [ ] **Step 6: Replace runner environment variables**

Use:

```bash
--env-vars
"GITHUB_APP_ID=$GITHUB_APP_ID"
"GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID"
"GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key"
"GH_URL=https://github.com/$GITHUB_OWNER/$GITHUB_REPO"
"REGISTRATION_TOKEN_API_URL=https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token"
"RUNNER_LABELS=aca-runner"
"RUNNER_NAME_PREFIX=aca"
```

Immediately after the create command:

```bash
unset JOB_CREATE_ARGS GITHUB_APP_PRIVATE_KEY
```

- [ ] **Step 7: Add safe recovery guidance**

State that `az containerapp job create` is not an idempotent update command. For an existing Job, inspect it first:

```bash
az containerapp job show --name "$JOB" --resource-group "$RG" --output none
```

If a partial lab deployment must be recreated, delete only the named workshop Job and rerun module 04:

```bash
az containerapp job delete \
  --name "$JOB" \
  --resource-group "$RG" \
  --yes
```

Do not instruct participants to recreate the whole resource group for a Job configuration error.

- [ ] **Step 8: Update troubleshooting**

Replace PAT causes with App installation, permission, ID, and private-key mismatch causes. Keep lowercase `githubApiURL` guidance and label troubleshooting.

- [ ] **Step 9: Run build/deploy contracts**

Run:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/test-artifacts.sh
```

Expected: PASS.

- [ ] **Step 10: Commit Job and KEDA documentation**

```bash
git add docs/03-runner-image.md docs/04-event-job-keda.md \
  tests/docs/test-build-deploy.sh
git commit -m "docs: configure KEDA with GitHub App" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 6: Correct Validation and Cleanup Documentation

**Files:**
- Modify: `tests/docs/test-scale-validation.sh`
- Modify: `tests/docs/test-security-cleanup.sh`
- Modify: `docs/05-parallel-scale-validation.md`
- Modify: `docs/06-security-limitations-cleanup.md`

**Interfaces:**
- Consumes the GitHub App configuration from modules 01 and 04.
- Produces accurate screenshots, troubleshooting, and cleanup instructions.

- [ ] **Step 1: Update module 05 contracts**

Require GitHub App troubleshooting terms:

```bash
'GitHub App installation' \
'GITHUB_APP_ID' \
'GITHUB_APP_INSTALLATION_ID'
```

Replace the success-caption assertion with:

```bash
'Worker 1은 성공했고 Worker 4는 아직 진행 중인 중간 상태'
```

Reject `PAT` in module 05.

- [ ] **Step 2: Update module 06 contracts**

Require:

```bash
'GitHub App installation 삭제' \
'GitHub App private key PEM 삭제' \
'## 7. 전체 워크숍 완료 확인'
```

Reject the old Fine-grained PAT production-comparison row and `## 8. 전체 워크숍 완료 확인`.

- [ ] **Step 3: Run the contracts and confirm they fail**

Run:

```bash
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected: FAIL on old PAT troubleshooting, screenshot wording, and section numbering.

- [ ] **Step 4: Correct module 05 screenshot wording**

Change the reference text to accurately say that the checked-in image captures an intermediate state where Worker 1 has succeeded and Worker 4 is still progressing. Do not describe it as proof that all four jobs succeeded.

Keep the textual expected result that the participant must ultimately verify all four jobs succeed.

- [ ] **Step 5: Replace module 05 PAT troubleshooting**

Use App-specific causes:

- App installation removed or not granted to the lab repository.
- App permission changes not accepted for the installation.
- App ID, installation ID, or private key mismatch.
- KEDA App credentials invalid.

- [ ] **Step 6: Update module 06 production comparison**

Replace the PAT-to-App row with:

```markdown
| ACA secret의 GitHub App private key | Azure Key Vault 또는 외부 token broker | stronger key isolation and centralized rotation |
| registration token 방식 | GitHub JIT runner | reduced registration lifecycle exposure |
```

- [ ] **Step 7: Update GitHub cleanup**

Replace PAT revocation with:

1. Remove the App installation from `aca-runner-lab`.
2. Delete the workshop-only GitHub App if it is not reused.
3. Delete the downloaded PEM and Cloud Shell copies.
4. Remove stale runner records and the lab workflow/repository as applicable.

Renumber `## 8. 전체 워크숍 완료 확인` to `## 7. 전체 워크숍 완료 확인`.

- [ ] **Step 8: Run validation and cleanup contracts**

Run:

```bash
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected: PASS.

- [ ] **Step 9: Commit validation and cleanup corrections**

```bash
git add docs/05-parallel-scale-validation.md docs/06-security-limitations-cleanup.md \
  tests/docs/test-scale-validation.sh tests/docs/test-security-cleanup.sh
git commit -m "docs: correct GitHub App validation and cleanup" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 7: Add Repository CI and Complete Integrated Validation

**Files:**
- Create: `.github/workflows/validate-workshop.yml`
- Modify: `tests/docs/test-overview.sh`
- Modify: `tests/test-validate-workshop.sh`
- Modify: `tests/validate-workshop.sh`
- Modify: `.gitignore`

**Interfaces:**
- Consumes all previous tasks.
- Produces automatic push/PR validation and a clean repository after interrupted tests.

- [ ] **Step 1: Add a failing CI artifact expectation**

In `tests/test-artifacts.sh`, require:

```bash
CI_WORKFLOW="$ROOT/.github/workflows/validate-workshop.yml"
[[ -f "$CI_WORKFLOW" ]] || {
  echo "FAIL: validation workflow missing" >&2
  exit 1
}
grep -F 'bash tests/validate-workshop.sh' "$CI_WORKFLOW" >/dev/null
```

- [ ] **Step 2: Run the artifact test and confirm it fails**

Run:

```bash
bash tests/test-artifacts.sh
```

Expected: FAIL because the CI workflow does not exist.

- [ ] **Step 3: Create the CI workflow**

Create `.github/workflows/validate-workshop.yml`:

```yaml
name: Validate workshop

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4

      - name: Validate workshop
        shell: bash
        run: bash tests/validate-workshop.sh
```

- [ ] **Step 4: Ignore interrupted runner-test artifacts**

Add:

```gitignore
tests/runner/.fixture-entrypoint/
tests/runner/aca-runner-entrypoint-test.log
```

- [ ] **Step 5: Run the integrated validator**

Run:

```bash
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
```

Expected: both PASS. If PAT configuration is reported, search only the core workshop files and replace the remaining operational reference:

```bash
rg -n 'GITHUB_PAT|personalAccessToken=|personal-access-token' \
  README.md docs/0*.md runner samples
```

- [ ] **Step 6: Run repository-level final checks**

Run:

```bash
bash -n runner/entrypoint.sh
for test_file in tests/*.sh tests/docs/*.sh tests/runner/*.sh; do
  bash -n "$test_file"
done
git diff --check
git status --short
```

Expected: no syntax errors, no whitespace errors, and only intended files are modified.

- [ ] **Step 7: Commit CI and final integration**

```bash
git add .github/workflows/validate-workshop.yml .gitignore \
  tests/docs/test-overview.sh tests/test-artifacts.sh \
  tests/test-validate-workshop.sh tests/validate-workshop.sh
git commit -m "ci: validate workshop changes" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 8: Review the Complete Migration

**Files:**
- Review: all files modified in Tasks 1-7

**Interfaces:**
- Consumes the complete migration.
- Produces a release-ready workshop commit series.

- [ ] **Step 1: Review authentication boundaries**

Confirm:

- The private key is stored as an ACA secret.
- KEDA references it through `appKey`.
- The runner keeps the PEM only in a non-exported wrapper-shell variable before `run.sh`, and startup tokens never become exported workflow-process environment variables.
- Cleanup mints a fresh JWT, installation token, and removal token after `run.sh` exits when local runner state remains.
- No PAT fallback remains.

- [ ] **Step 2: Review documentation continuity**

Read modules in order and confirm every variable produced by module 01 is either preserved or explicitly restored before module 04. Confirm all suffix examples use six hexadecimal characters and all displayed timing totals equal 105 minutes.

- [ ] **Step 3: Run the final validator**

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

- [ ] **Step 4: Inspect final history and worktree**

Run:

```bash
git --no-pager log --oneline -10
git status --short
```

Expected: the planned commits are present and the worktree is clean.
