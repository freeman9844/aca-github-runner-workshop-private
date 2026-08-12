# Task 6 Report

- Task: Document Parallel Scaling and Log Validation
- Commit: current `HEAD`
- Commit message: `docs: add parallel scale validation module`
- TDD:
  - Created `tests/docs/test-scale-validation.sh` first.
  - Verified the initial failure: `FAIL: module 05 missing`.
  - Added `docs/05-parallel-scale-validation.md` only after the failing doc test was confirmed.
- Implemented:
  - Korean module 05 covering GitHub web UI workflow creation from `samples/parallel-runner-workflow.yml` so the PAT can stay least-privilege.
  - Baseline/history versus active execution guidance, repeated `Running` queries, CLI execution logs, resource-specific `ContainerAppConsoleLogs` KQL, lifecycle marker validation, GitHub hostname checks, and no persistent online runner verification.
  - Expected output, troubleshooting, and previous/next navigation links for the module.
- Validation:
  - `bash tests/docs/test-scale-validation.sh` → `PASS: parallel scale validation doc`
  - `bash tests/docs/test-overview.sh` → `PASS: README contract`
  - `bash tests/docs/test-prerequisites-foundation.sh` → `PASS: prerequisites and foundation docs`
  - `bash tests/docs/test-build-deploy.sh` → `PASS: image build and Event Job docs`
  - `bash tests/test-artifacts.sh` → `PASS: runner image and workflow artifacts`
  - `bash tests/runner/test-entrypoint.sh` → `PASS: entrypoint behavior`
