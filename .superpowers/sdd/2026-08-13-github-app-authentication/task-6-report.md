# Task 6 Report

## Summary
- Updated module 05 doc contracts and content to describe the checked-in screenshot as an intermediate GitHub Actions state while preserving the requirement to verify four successful jobs.
- Replaced module 05 PAT-based troubleshooting with GitHub App installation, permission, ID, installation ID, private key, and KEDA credential guidance.
- Updated module 06 production comparison, GitHub cleanup checklist, and final section numbering for the GitHub App workflow.

## TDD Evidence
1. Updated `tests/docs/test-scale-validation.sh` and `tests/docs/test-security-cleanup.sh` first.
2. Verified RED:
   - `bash tests/docs/test-scale-validation.sh` → `FAIL: module 05 missing Worker 1은 성공했고 Worker 4는 아직 진행 중인 중간 상태`
   - `bash tests/docs/test-security-cleanup.sh` → `FAIL: module 06 missing | ACA secret의 GitHub App private key | Azure Key Vault 또는 외부 token broker | stronger key isolation and centralized rotation |`
3. Updated the docs to satisfy the new contracts.
4. Verified GREEN:
   - `bash tests/docs/test-scale-validation.sh`
   - `bash tests/docs/test-security-cleanup.sh`

## Self-review
- Confirmed module 05 no longer references PAT and now describes the successful-matrix image as an intermediate state.
- Confirmed module 06 removes the obsolete PAT production row and PAT cleanup step, adds GitHub App cleanup guidance, and renumbers the final section to 7.
- Reviewed `git diff` before commit for the four task files.

## Validation
- PASS: `bash tests/docs/test-scale-validation.sh`
- PASS: `bash tests/docs/test-security-cleanup.sh`

## Round 1 Fix Evidence
- Removed the remaining operational `PAT 만료` guidance from module 06 and replaced it with GitHub App installation permission, App ID/installation ID/private key mismatch, and ACA Job secret synchronization troubleshooting.
- Updated `tests/docs/test-security-cleanup.sh` to require the App-specific signals and reject any PAT wording in module 06.
- Verified:
  - `bash tests/docs/test-security-cleanup.sh`
  - `bash tests/docs/test-scale-validation.sh`
  - `git diff --check`

## Commit
- `aff6feaefa04bdb5f82fffaca15d29b523d1c618` — `docs: correct GitHub App validation and cleanup`
