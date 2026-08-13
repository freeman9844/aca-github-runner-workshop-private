# Task 7 Report

## Summary
- Added a pinned GitHub Actions workflow at `.github/workflows/validate-workshop.yml` to run the integrated workshop validator on push and pull request events.
- Extended `tests/test-artifacts.sh` to require the validation workflow and confirm it invokes `bash tests/validate-workshop.sh`.
- Ignored interrupted runner test artifacts in `.gitignore` so validation leaves the repository clean.

## Checkout
- Starting checkout SHA: `32fa9afb20b05e6cd6ec9c68769a65aaf92a04a9`

## TDD Evidence
1. Updated `tests/test-artifacts.sh` first to require `.github/workflows/validate-workshop.yml` and the validator command.
2. Verified RED:
   - `cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/github-app-authentication && bash tests/test-artifacts.sh`
   - Result: `FAIL: validation workflow missing`
3. Added the pinned CI workflow and ignored runner-test artifacts.
4. Verified GREEN:
   - `cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/github-app-authentication && bash tests/test-artifacts.sh`
   - Result: `PASS: runner image and workflow artifacts`

## Validation
- PASS: `cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/github-app-authentication && bash tests/validate-workshop.sh && bash tests/test-validate-workshop.sh`
- PASS: `cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/github-app-authentication && bash -n runner/entrypoint.sh && for test_file in tests/*.sh tests/docs/*.sh tests/runner/*.sh; do bash -n "$test_file"; done && git diff --check && git status --short`

## Self-review
- Confirmed the workflow uses the pinned `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` SHA and only runs the checked-in integrated validator.
- Confirmed the artifact contract now fails when the workflow is absent and passes once the workflow is present.
- Confirmed `.gitignore` covers the runner test fixture directory and log file so interrupted local runs do not dirty the worktree.
