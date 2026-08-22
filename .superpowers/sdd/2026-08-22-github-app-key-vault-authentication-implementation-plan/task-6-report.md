# Task 6 Report

- Status: completed
- Commit: `8f96831` (`test: verify App credentials stay outside workflows`)

## What changed

- Extended `Validate runner inputs` to fail if `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, or `GITHUB_APP_PRIVATE_KEY` reach the workflow step environment.
- Added RED/GREEN coverage for the validation step, workflow artifact markers, and Module 06 documentation/disclosure.
- Updated Module 06 to explain the proof boundary as normal child-environment non-inheritance only, not hostile-code isolation across the Job managed-identity/runtime boundary.

## Tests

- `bash tests/test-artifacts.sh` ✅
- `python3 tests/test-workflow-yaml.py` ✅
- `bash tests/docs/test-azure-sample-deployment.sh` ✅

## Self-review

- Confirmed the sample workflow and Module 06 disclosure still byte-match.
- Confirmed Private Blob behavior, Azure login flow, DNS validation, and checksum logic were left unchanged outside the existing validation step.

## Concerns

- None.

## Round 1 Fix

- Status: fixed
- Change: Removed `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and `GITHUB_APP_PRIVATE_KEY` from the base environment in `tests/test-workflow-yaml.py` before constructing the clean and leak cases.
- Tests:
  - `bash tests/test-artifacts.sh` ✅
  - `python3 tests/test-workflow-yaml.py` ✅
  - `bash tests/docs/test-azure-sample-deployment.sh` ✅
