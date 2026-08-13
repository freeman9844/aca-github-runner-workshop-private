# Task 2 Report

## Status
Completed.

## Changes
- Updated `tests/test-artifacts.sh` to require `openssl` in the Dockerfile install list.
- Added GitHub App contract checks for `runner/entrypoint.sh`.
- Updated `tests/validate-workshop.sh` to scan only core workshop paths for PAT configuration.
- Replaced the legacy secret-shaped string scan with a PAT-configuration rejection.

## Validation
- `bash tests/test-artifacts.sh` ✅
- `bash tests/validate-workshop.sh` ❌ expected failure on existing PAT workshop docs

## Concerns
- Workshop validation now correctly blocks PAT-based configuration in core docs until later migration tasks remove it.
