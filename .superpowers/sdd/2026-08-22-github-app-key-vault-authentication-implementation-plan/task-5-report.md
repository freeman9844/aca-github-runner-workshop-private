# Task 5 Report

## Scope
Updated Module 05 scale-validation guidance and the focused doc test so GitHub App failure checks replace PAT-era validation and recovery language.

## TDD flow
1. Tightened `tests/docs/test-scale-validation.sh` to require the GitHub App failure markers and reject PAT guidance.
2. Ran `bash tests/docs/test-scale-validation.sh` and confirmed RED.
3. Updated `docs/05-parallel-scale-validation.md` to:
   - remove PAT-based validation text,
   - document `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `applicationID`, `installationID`, and `appKey`,
   - add GitHub App installation / Key Vault / `401` / `403` failure checks,
   - rewrite troubleshooting for KEDA auth, Key Vault resolution, JWT clock skew, installation token, and runner registration failures.
4. Re-ran the focused test and confirmed GREEN.

## Files changed
- `docs/05-parallel-scale-validation.md`
- `tests/docs/test-scale-validation.sh`

## Focused validation
- `bash tests/docs/test-scale-validation.sh` ✅
- `bash -n tests/docs/test-scale-validation.sh` ✅
- `git diff --check` ✅

## Self-review
- Verified the doc still preserves the matrix workflow, `0 → N → 0` execution flow, CLI log checks, and Log Analytics mechanics.
- Verified the new validation block keeps `appKey -> github-app-private-key` as the authoritative scaler auth mapping.
- Verified PAT-era strings are removed from Module 05.

## Concern
- None.

## Fix round 1
- Restored `GITHUB_APP_ID` and `GITHUB_APP_INSTALLATION_ID` in the Module 05 session-reconnect recovery block with explicit prompts and output.
- Split Module 05 failure guidance into separate KEDA auth, Key Vault resolution, and runner registration paths.
- Added the Key Vault resolution path checks for `identityref`, `Key Vault Secrets User`, private DNS/private endpoint, and `publicNetworkAccess=Disabled`.
- Strengthened `tests/docs/test-scale-validation.sh` so the recovery prompts must appear in the recovery section, not only later in troubleshooting.
- Re-ran `bash tests/docs/test-scale-validation.sh` and `bash -n tests/docs/test-scale-validation.sh` successfully.
