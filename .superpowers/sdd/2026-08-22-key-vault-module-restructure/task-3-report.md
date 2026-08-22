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

## Round 1 Review Fix: strengthen ownership-contract assertions

### Fix details

- Tightened `tests/docs/test-build-deploy.sh` to require Module 03's full recovery ownership split (`Module 01` for actual `KEY_VAULT`, `Module 02` for actual `ACR`) and Module 04's full split-Key-Vault sentence plus the troubleshooting order sentence.
- Tightened `tests/docs/test-scale-validation.sh` and `tests/docs/test-azure-sample-deployment.sh` to require the full recovery sentence that preserves Module 02 ownership of collision-recovered actual ACR/Storage names.
- No documentation changes were needed because the existing docs already satisfied the strengthened contracts.

### TDD evidence

#### RED (temporary ownership-phrase removal)

Temporarily removed `Module 02에서 저장한` from the Module 03 recovery sentence, then ran all three focused tests:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('/home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure/docs/03-runner-image.md')
old = 'Cloud Shell 세션이 끊기면 셸 변수는 사라집니다. 이때 Module 01에서 저장한 `SUFFIX`와 실제 `KEY_VAULT`, Module 02에서 저장한 실제 `ACR` 이름을 사용해 같은 리소스를 복구합니다.'
new = 'Cloud Shell 세션이 끊기면 셸 변수는 사라집니다. 이때 Module 01에서 저장한 `SUFFIX`와 실제 `KEY_VAULT`, 실제 `ACR` 이름을 사용해 같은 리소스를 복구합니다.'
text = p.read_text()
p.write_text(text.replace(old, new, 1))
PY
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure && \
  bash tests/docs/test-build-deploy.sh; \
  bash tests/docs/test-scale-validation.sh; \
  bash tests/docs/test-azure-sample-deployment.sh
```

Observed output:

```text
FAIL: module 03 must preserve Module 01 Key Vault ownership and Module 02 ACR ownership: Module 01에서 저장한 `SUFFIX`와 실제 `KEY_VAULT`, Module 02에서 저장한 실제 `ACR` 이름을 사용해 같은 리소스를 복구합니다.
PASS: scale validation doc
PASS: Private Blob 배포와 결과 확인 doc and workflow disclosure
```

#### GREEN

Restored the doc, then re-ran all three focused tests and `git diff --check`:

```bash
git -C /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure checkout -- docs/03-runner-image.md && \
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure && \
  bash tests/docs/test-build-deploy.sh && \
  bash tests/docs/test-scale-validation.sh && \
  bash tests/docs/test-azure-sample-deployment.sh && \
  git diff --check
```

Observed output:

```text
PASS: build and deploy docs
PASS: scale validation doc
PASS: Private Blob 배포와 결과 확인 doc and workflow disclosure
```

### Self-review

- Confirmed the strengthened assertions fail when the required Module 02 ACR ownership phrase is removed from Module 03.
- Confirmed the final diff only changes the three focused tests plus this report; docs remain unchanged.
- Confirmed `git diff --check` is clean after the final test run.
