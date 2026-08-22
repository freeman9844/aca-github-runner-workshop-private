# Task 3 Report: Update Downstream Module Ownership References

## Scope

- Updated downstream ownership wording in Modules 03-06 only.
- Added/updated focused doc tests in:
  - `tests/docs/test-build-deploy.sh`
  - `tests/docs/test-scale-validation.sh`
  - `tests/docs/test-azure-sample-deployment.sh`
- Left README and Modules 01/02 unchanged.

## TDD Record

### RED

Added failing assertions first for the new ownership language, then ran:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-azure-sample-deployment.sh
```

Observed expected failures:

```text
FAIL: module 03 must identify Module 01 as the suffix source: Module 01에서 저장한 `SUFFIX`
FAIL: module 05 must identify Module 01 as the suffix source: Module 01에서 저장한 `SUFFIX`
FAIL: module 06 must identify Module 01 as the suffix source: Module 01에서 저장한 `SUFFIX`
```

### GREEN

Updated docs to reflect the new ownership split:

- Module 03 recovery now points to Module 01 for `SUFFIX`/actual `KEY_VAULT` and Module 02 for actual `ACR`, while keeping Storage collision recovery with Module 02.
- Module 04 recovery/troubleshooting now points to Module 01 Key Vault creation/secret upload and Module 02 private-access completion.
- Modules 05 and 06 recovery now point to Module 01 for `SUFFIX` and Module 02 for actual ACR/Storage collision recovery.

Re-ran the same focused tests:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-azure-sample-deployment.sh
```

All passed:

```text
PASS: build and deploy docs
PASS: scale validation doc
PASS: Private Blob 배포와 결과 확인 doc and workflow disclosure
```

## Files Changed

- `docs/03-runner-image.md`
- `docs/04-event-job-keda.md`
- `docs/05-parallel-scale-validation.md`
- `docs/06-azure-sample-deployment.md`
- `tests/docs/test-build-deploy.sh`
- `tests/docs/test-scale-validation.sh`
- `tests/docs/test-azure-sample-deployment.sh`

## Self-Review

- Verified the diff only touches Modules 03-06 and the three specified tests.
- Verified wording preserves Module 02 ownership for actual ACR/Storage collision recovery.
- Verified Module 04 now explicitly describes split Key Vault ownership and troubleshooting order.
- Ran `git diff --check` with no formatting issues.

## Commit

Planned commit message:

```text
docs: align Key Vault ownership references
```
