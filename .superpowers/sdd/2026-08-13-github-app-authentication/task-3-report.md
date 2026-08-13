# Task 3 Report

## Status
Completed.

## Changes
- Updated `tests/docs/test-prerequisites-foundation.sh` to enforce the GitHub App contract for module 01 and reject lingering PAT-based instructions.
- Rewrote `docs/01-prerequisites-github.md` so module 01 now documents repository-scoped GitHub App creation, PEM loading, JWT generation, installation token exchange, and repository verification with API version `2026-03-10`.
- Preserved the existing module 01 Azure subscription, provider, repository, and workshop clone steps.

## TDD Evidence
### Red
Command:
```bash
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/github-app-authentication && bash tests/docs/test-prerequisites-foundation.sh
```
Output:
```text
FAIL: module 01 missing GitHub Apps
```
Exit status: `1`

### Green
Command:
```bash
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/github-app-authentication && bash tests/docs/test-prerequisites-foundation.sh
```
Output:
```text
PASS: prerequisites and foundation docs
```
Exit status: `0`

## Validation
- `bash tests/docs/test-prerequisites-foundation.sh` ✅
- `bash -n tests/docs/test-prerequisites-foundation.sh` ✅
- `git diff --check` ✅

## Self-Review Findings
- Reviewed the final diff to confirm scope stayed limited to `docs/01-prerequisites-github.md` and `tests/docs/test-prerequisites-foundation.sh`.
- Confirmed module 01 now exports `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and `GITHUB_APP_PRIVATE_KEY`.
- Confirmed the verification snippet uses the Task 1 GitHub App JWT flow and `X-GitHub-Api-Version: 2026-03-10`.
- Confirmed PAT-specific instructions are removed from module 01 and the contract test now fails if they return.

## Concerns
- `tests/validate-workshop.sh` remains intentionally red until later tasks migrate the operational PAT flow outside module 01.

## Round 1 Fix Evidence
- Added an exact contract assertion for `Where can this GitHub App be installed? | **Only on this account**`.
- Added a focused rejection that fails if module 01 prints `GITHUB_APP_PRIVATE_KEY` directly, while preserving the JWT signing use of the PEM contents.
- Verified the safe redaction pattern remains `${GITHUB_APP_PRIVATE_KEY:+SET}`.
- Validation rerun:
  - `bash tests/docs/test-prerequisites-foundation.sh` → `PASS: prerequisites and foundation docs`
  - `bash -n tests/docs/test-prerequisites-foundation.sh` → pass
  - `git diff --check` → pass
