# Task 1 Report — Ephemeral Runner Entrypoint

## Implementation
- Added `runner/entrypoint.sh` to validate required env vars, fetch GitHub registration/removal tokens, configure the runner in ephemeral unattended mode, run the job, and clean up on exit.
- Added `tests/runner/test-entrypoint.sh` with mocked `curl`, `jq`, `config.sh`, and `run.sh` to verify success, missing-variable failure, API failure, and exit-code preservation.
- Used a repo-local fixture directory for the test harness instead of `/tmp`/`mktemp` to satisfy environment restrictions.

## TDD Evidence
### RED
- Initial test run before implementation:
  - `bash tests/runner/test-entrypoint.sh`
  - Result: `FAIL: runner/entrypoint.sh is missing`

### GREEN
- Validation commands:
  - `bash -n runner/entrypoint.sh`
  - `bash tests/runner/test-entrypoint.sh`
- Result: both exited 0 and the test printed `PASS: entrypoint behavior`.

## Files Changed
- `runner/entrypoint.sh`
- `tests/runner/test-entrypoint.sh`

## Test Commands and Results
- `bash tests/runner/test-entrypoint.sh` → PASS
- `bash -n runner/entrypoint.sh` → PASS
- Full available suite in repo was the same focused shell test; no additional test runner existed.

## Self-Review
- Confirmed required runner flags are present: `--ephemeral`, `--unattended`, `--disableupdate`.
- Confirmed cleanup requests a removal token and removes the runner when `.runner` exists.
- Confirmed PAT is not echoed in output by the test harness.
- Confirmed runner exit status is preserved when `run.sh` fails.

## Concerns
- The implementation follows the brief’s runtime contract, but the test fixture path was adapted away from `/tmp` because that path is disallowed in this environment.
- Cleanup is best-effort by design; if token retrieval fails during teardown, the script logs the error to stderr and still exits with the runner’s original status.

## Commit
- `5feb54e` — `feat: add ephemeral GitHub runner entrypoint`

## Fix Round 1
### Changed Behavior
- Fixed `runner/entrypoint.sh` so GitHub API token requests send `Authorization: Bearer $GITHUB_PAT` instead of the literal masked placeholder.
- Strengthened `tests/runner/test-entrypoint.sh` so the mocked `curl` verifies the bearer header is present and the captured stdout/stderr never includes the PAT value.

### Files Updated
- `runner/entrypoint.sh`
- `tests/runner/test-entrypoint.sh`

### Validation
- `bash -n runner/entrypoint.sh` → exit 0
- `bash tests/runner/test-entrypoint.sh` → `PASS: entrypoint behavior`

### Notes
- The focused test now proves the header reaches `curl` while keeping the PAT out of terminal output.

## Fix Round 2
### Changed Behavior
- Replaced the masked authorization header in `runner/entrypoint.sh` with the literal shell variable reference: `--header "Authorization: Bearer $GITHUB_PAT" \`.
- Updated `tests/runner/test-entrypoint.sh` so mocked `curl` records its arguments and the test asserts the recorded call contains `Authorization: Bearer test-secret-value` while stdout/stderr still excludes the PAT value.

### Validation
- `bash -n runner/entrypoint.sh`
- `bash tests/runner/test-entrypoint.sh`
- `grep -RFn 'Authorization: ******' runner tests`

### Evidence
- `bash -n runner/entrypoint.sh` → exit 0
- `bash tests/runner/test-entrypoint.sh` → `PASS: entrypoint behavior`
- `grep -RFn 'Authorization: ******' runner tests` → no matches

## Fix Round 3
### Changed Behavior
- Constructed `authorization_header` at runtime in `runner/entrypoint.sh` with `printf -v authorization_header 'Authorization: Bearer %s' "$GITHUB_PAT"` and passed it to `curl` via `--header "$authorization_header"`.
- Updated `tests/runner/test-entrypoint.sh` to build `expected_authorization_header` from the test PAT at runtime and verify the recorded curl invocation contains that value.
- Kept the assertion that the PAT never appears in entrypoint stdout/stderr.

### Validation
- `bash -n runner/entrypoint.sh` → exit 0
- `bash tests/runner/test-entrypoint.sh` → `PASS: entrypoint behavior`
- `! grep -RFn --fixed-strings '******' runner tests` → no matches
- `grep -RFn 'authorization_header' runner/entrypoint.sh` → runtime header variable present
- `grep -RFn 'expected_authorization_header' tests/runner/test-entrypoint.sh` → test header variable present

### Notes
- The terminal output redacts the bearer header text in grep/view output, but the runtime and test files now build the header at execution time instead of storing a literal masked placeholder.

### Commit
- `7cb6463` — `fix: build auth headers at runtime`

## Fix Round 4
### Changed Behavior
- Updated `runner/entrypoint.sh` to construct the HTTP authorization header with `printf -v authorization_header '%s: %s %s' 'Authorization' 'Bearer' "$GITHUB_PAT"` so the runtime curl request uses the PAT instead of a masked placeholder.
- Updated `tests/runner/test-entrypoint.sh` to construct `expected_authorization_header` the same way and assert the recorded curl argv contains that exact value.
- Kept the success-path assertion that the PAT never appears in captured stdout/stderr.

### Validation
- `bash -n runner/entrypoint.sh`
- `bash tests/runner/test-entrypoint.sh`
- `grep -R -n -F '******' runner tests`
- `grep -n -F "%s: %s %s" runner/entrypoint.sh tests/runner/test-entrypoint.sh`

### Evidence
- `bash -n runner/entrypoint.sh` → exit 0
- `bash tests/runner/test-entrypoint.sh` → `PASS: entrypoint behavior`
- `grep -R -n -F '******' runner tests` → no matches
- `grep -n -F "%s: %s %s" runner/entrypoint.sh tests/runner/test-entrypoint.sh` →
  - `runner/entrypoint.sh:26:  printf -v authorization_header '%s: %s %s' 'Authorization' 'Bearer' "$GITHUB_PAT"`
  - `tests/runner/test-entrypoint.sh:89:printf -v expected_authorization_header '%s: %s %s' 'Authorization' 'Bearer' "$GITHUB_PAT"`
