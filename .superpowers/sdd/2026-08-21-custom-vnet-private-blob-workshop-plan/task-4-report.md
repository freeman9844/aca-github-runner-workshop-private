# Task 4 Report

## Scope
- Align participant-facing overview/navigation/image surfaces to External ACA + Custom VNet + private Blob architecture.
- Keep the integrated static validator green.

## Changed files
- `README.md`
- `docs/05-parallel-scale-validation.md`
- `docs/06-azure-sample-deployment.md`
- `docs/07-security-limitations-cleanup.md`
- `tests/docs/test-overview.sh`
- `tests/docs/test-prerequisites-foundation.sh`
- `tests/docs/test-build-deploy.sh`
- `tests/docs/test-scale-validation.sh`
- `tests/docs/test-azure-sample-deployment.sh`
- `tests/docs/test-security-cleanup.sh`
- `tests/test-artifacts.sh`

## Deleted files
- `docs/images/06-github-actions-deployment-success.png`
- `docs/images/06-github-deployment-success-details.png`

## Image deletion proof
- Candidate scan:
  - `find docs/images -maxdepth 1 -type f \( -name '06-*deployment*' -o -name '02-*internal*' \) | sort`
  - Result:
    - `docs/images/06-github-actions-deployment-success.png`
    - `docs/images/06-github-deployment-success-details.png`
- Reference scan before deletion:
  - `rg -n '06-github-actions-deployment-success\.png|06-github-deployment-success-details\.png|02-.*internal.*' README.md docs tests samples`
  - Result: no matches
- Decision: deleted only the two files explicitly permitted by the brief's `06-*deployment*` allowance. No `02-*internal*` files existed.

## Commit
- `docs: align workshop to private Blob deployment`

## Tests and outputs
### Focused tests
- `bash tests/docs/test-overview.sh` → `PASS: README contract`
- `bash tests/docs/test-prerequisites-foundation.sh` → `PASS: prerequisites and foundation docs`
- `bash tests/docs/test-build-deploy.sh` → `PASS: build and deploy docs`
- `bash tests/docs/test-scale-validation.sh` → `PASS: scale validation doc`
- `bash tests/docs/test-azure-sample-deployment.sh` → `PASS: Azure sample deployment doc and workflow disclosure`
- `bash tests/docs/test-security-cleanup.sh` → `PASS: security cleanup doc`
- `bash tests/docs/test-execution-comments.sh` → `PASS: execution Bash blocks start with Korean comments`
- `bash tests/test-artifacts.sh` → `PASS: workflow artifacts contract`
- `python3 tests/test-workflow-yaml.py` → `PASS: workflow YAML syntax and private Blob behavior`

### Integrated validation and checks
- `bash tests/test-validate-workshop.sh` → `PASS: integrated workshop validator`
- `git grep -nE 'internal ACA|internal Environment|internal ingress|same Environment|AZURE_SAMPLE_APP|hello-aca|ENV_DEFAULT_DOMAIN|ENV_STATIC_IP|--internal-only true'` → no matches
- `git diff --check origin/master...HEAD` → no output
- `git status --short --branch` before commit showed only intended modifications/deletions

## Deferred Minor decision
- **Retained** the `Storage Blob Data Contributor` assertion in `tests/test-artifacts.sh`.
- Rationale: the workflow artifact intentionally documents the prerequisite RBAC in participant-facing content (`Sign in to Azure with managed identity` step comment), while foundation tests continue to own the authoritative scope/allocation checks. Integrated validation stayed green with this guard in place, so keeping it preserves a meaningful artifact-level contract rather than an accidental duplication.

## Self-review
- README architecture, outcomes, module table, completion checklist, timebox, troubleshooting index, cost table, and references now describe External ACA + Custom VNet + private Blob behavior only.
- Module 05/07 navigation text now points to the Private Blob module.
- Only brief-permitted obsolete deployment screenshots were deleted, and they had no remaining Markdown references.
- Forbidden internal/sample terminology was removed from participant-facing content, and the branch-wide forbidden-content search is clean.
- The integrated validator and all focused tests are green after the final edits.

## Concerns
- None.
