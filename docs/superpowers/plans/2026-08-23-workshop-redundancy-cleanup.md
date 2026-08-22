# Workshop Redundancy Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove duplicated workshop legends, recovery state, and workflow disclosures without changing the Azure/GitHub architecture or executable behavior.

**Architecture:** README remains the authoritative overview and tag legend. Each module keeps only the recovery variables and instructional content needed for its own execution, while checked-in sample files remain the authoritative workflow source. Security-critical Module 03 runner source disclosures stay embedded and byte-matched.

**Tech Stack:** Markdown, Bash regression tests, Python/YAML validators, Git

**Spec:** `docs/superpowers/specs/2026-08-23-workshop-redundancy-cleanup-design.md`

## Global Constraints

- Preserve execution results, security warnings, troubleshooting, and service endpoint/firewall/RBAC validation.
- Keep Module 03 Dockerfile and entrypoint disclosures byte-matched with `runner/Dockerfile` and `runner/entrypoint.sh`.
- Do not change Azure resources, GitHub App authentication, runner behavior, KQL logic, or workflow behavior.
- Keep the workshop duration at 150 minutes.
- Use test-first changes and run `tests/validate-workshop.sh` before completion.

---

### Task 1: Centralize the Tag Legend

**Files:**
- Modify: `docs/01-prerequisites-github.md`
- Modify: `docs/02-azure-foundation.md`
- Modify: `docs/03-runner-image.md`
- Modify: `docs/04-event-job-keda.md`
- Modify: `docs/05-parallel-scale-validation.md`
- Modify: `docs/06-azure-sample-deployment.md`
- Modify: `docs/07-security-limitations-cleanup.md`
- Test: `tests/docs/test-overview.sh`

**Interfaces:**
- Consumes: README `## 태깅 범례`
- Produces: Module documents with no local `## 태그 범례` table

- [ ] **Step 1: Write the failing test**

Add this loop after the README heading checks in `tests/docs/test-overview.sh`:

```bash
for module in "$ROOT"/docs/0[1-7]-*.md; do
  if grep -F -- '## 태그 범례' "$module" >/dev/null; then
    fail "module duplicates the README tag legend: ${module#$ROOT/}"
  fi
done
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: FAIL with `module duplicates the README tag legend`.

- [ ] **Step 3: Remove the seven duplicated legends**

Delete each module's `## 태그 범례` heading and the table beginning with:

```markdown
| 태그 | 의미 |
|------|------|
```

Do not remove icon labels used within execution sections.

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: `PASS: README contract`.

- [ ] **Step 5: Commit**

```bash
git add docs/0[1-7]-*.md tests/docs/test-overview.sh
git commit -m "docs: centralize workshop tag legend" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Reduce Module 03 Recovery State

**Files:**
- Modify: `docs/03-runner-image.md:23-111`
- Modify: `tests/docs/test-build-deploy.sh`
- Test: `tests/docs/test-runner-image.sh`

**Interfaces:**
- Consumes: `SUFFIX`, actual `ACR`
- Produces: `RG`, `IMAGE`, `ACR_SERVER`, `ACR_ID`

- [ ] **Step 1: Write the failing recovery-contract test**

Replace Module 03 recovery assertions in `tests/docs/test-build-deploy.sh` with:

```bash
for text in \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved ACR name: " ACR' \
  'RG="rg-acarunner-$SUFFIX"' \
  'IMAGE="github-actions-runner:2.336.0"' \
  'ACR_SERVER=$(az acr show --name "$ACR" --query loginServer --output tsv)' \
  'ACR_ID=$(az acr show --name "$ACR" --query id --output tsv)'; do
  assert_contains "$IMAGE_TEXT" "$text" 'module 03 minimal recovery contract missing'
done

for removed_text in \
  'Saved Storage account name if changed' \
  'Saved Key Vault name if changed' \
  'STORAGE_ID=$(az storage account show' \
  'KEY_VAULT_ID=$(az keyvault show' \
  'UAMI_RID=$(az identity show' \
  'LOG_ID=$(az monitor log-analytics workspace show'; do
  if grep -F -- "$removed_text" "$IMAGE_DOC" >/dev/null; then
    fail "module 03 recovery still restores unused state: $removed_text"
  fi
done
```

Define `IMAGE_DOC="$ROOT/docs/03-runner-image.md"` if the test does not already expose the path.

- [ ] **Step 2: Run the focused tests to verify failure**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: FAIL because Module 03 still restores Storage, Key Vault, Log Analytics, VNet, and UAMI state.

- [ ] **Step 3: Replace the Module 03 recovery block**

Keep the existing `<details>` wrapper but use this execution block:

```bash
# 저장해 둔 suffix와 실제 ACR 이름으로 image build 변수를 복원합니다.
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved ACR name: " ACR

RG="rg-acarunner-$SUFFIX"
IMAGE="github-actions-runner:2.336.0"
ACR_SERVER=$(az acr show --name "$ACR" --query loginServer --output tsv)
ACR_ID=$(az acr show --name "$ACR" --query id --output tsv)

export SUFFIX RG ACR IMAGE ACR_SERVER ACR_ID
printf 'SUFFIX=%s ACR=%s ACR_SERVER=%s IMAGE=%s\n' \
  "$SUFFIX" "$ACR" "$ACR_SERVER" "$IMAGE"
```

Update the explanation and expected output so they mention only these values.

- [ ] **Step 4: Run Module 03 tests**

Run:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-runner-image.sh
```

Expected: both PASS; Dockerfile and entrypoint disclosures still byte-match.

- [ ] **Step 5: Commit**

```bash
git add docs/03-runner-image.md tests/docs/test-build-deploy.sh
git commit -m "docs: minimize runner image recovery state" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Remove Module 05 Workflow Duplication

**Files:**
- Modify: `docs/05-parallel-scale-validation.md:15-558`
- Modify: `tests/docs/test-scale-validation.sh`

**Interfaces:**
- Consumes: `SUFFIX`
- Produces: `RG`, `LOG`, `JOB`, `LOG_ID`
- Preserves: `samples/parallel-runner-workflow.yml` as the only full workflow source

- [ ] **Step 1: Write failing recovery and heading tests**

Replace the Module 05 recovery assertions with:

```bash
for text in \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'RG="rg-acarunner-$SUFFIX"' \
  'LOG="log-acarunner-$SUFFIX"' \
  'JOB="job-ghrunner-$SUFFIX"' \
  'LOG_ID=$(az monitor log-analytics workspace show'; do
  assert_contains "$recovery_section" "$text" \
    'module 05 minimal recovery contract missing'
done

for removed_text in \
  'Saved ACR name' \
  'Saved GITHUB_APP_ID' \
  'Saved GITHUB_APP_INSTALLATION_ID' \
  'Saved Storage account name if changed' \
  'Saved Key Vault name if changed' \
  'STORAGE_ID=$(az storage account show' \
  'KEY_VAULT_ID=$(az keyvault show'; do
  if grep -F -- "$removed_text" "$recovery_section" >/dev/null; then
    fail "module 05 recovery still restores unused state: $removed_text"
  fi
done
```

Add heading checks:

```bash
for heading in \
  '## 1. 샘플 workflow를 Cloud Shell에서 열고 GitHub 웹 UI로 생성' \
  '## 2. 실행 전 baseline 이력과 active execution 0 상태 확인' \
  '## 3. GitHub Actions에서 `ACA Runner Scale Test`를 수동 실행' \
  '## 4. 첫 30~90초 동안 Running execution만 반복 조회' \
  '## 5. 가장 최근 execution을 잡아 CLI 로그 확인' \
  '## 6. Log Analytics에서 resource-specific `ContainerAppConsoleLogs`를 KQL로 확인' \
  '## 7. GitHub에서 네 개 Job 성공과 runner hostname 차이 확인' \
  '## 8. Running execution이 다시 0으로 돌아오는지 확인'; do
  assert_contains "$DOC_TEXT" "$heading" 'module 05 compact heading sequence missing'
done

if grep -F -- '## 2. matrix 4 Job 전체 YAML 확인' "$DOC" >/dev/null; then
  fail 'module 05 still duplicates the checked-in workflow YAML'
fi
```

Update `step_four`, `step_five`, and `step_seven` extraction boundaries to their new step numbers.

- [ ] **Step 2: Run the focused test to verify failure**

Run:

```bash
bash tests/docs/test-scale-validation.sh
```

Expected: FAIL because the old Step 2 and oversized recovery block remain.

- [ ] **Step 3: Minimize Module 05 recovery**

Use:

```bash
# 저장한 suffix로 scale validation에 필요한 Job과 Log Analytics 값을 복원합니다.
read -rp "Saved SUFFIX: " SUFFIX

RG="rg-acarunner-$SUFFIX"
LOG="log-acarunner-$SUFFIX"
JOB="job-ghrunner-$SUFFIX"
LOG_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RG" \
  --workspace-name "$LOG" \
  --query customerId \
  --output tsv)

export SUFFIX RG LOG JOB LOG_ID
printf 'RG=%s\nLOG=%s\nJOB=%s\nLOG_ID=%s\n' \
  "$RG" "$LOG" "$JOB" "$LOG_ID"
```

Update the surrounding explanation and expected output accordingly.

- [ ] **Step 4: Delete the duplicated YAML step and renumber**

Delete `## 2. matrix 4 Job 전체 YAML 확인` through its expected-output list. Rename the remaining headings from Step 3~9 to Step 2~8 without changing their bodies.

- [ ] **Step 5: Run the focused test**

Run:

```bash
bash tests/docs/test-scale-validation.sh
```

Expected: `PASS: scale validation doc`.

- [ ] **Step 6: Commit**

```bash
git add docs/05-parallel-scale-validation.md tests/docs/test-scale-validation.sh
git commit -m "docs: remove duplicate scale workflow guidance" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Remove Module 06 Workflow Duplication

**Files:**
- Modify: `docs/06-azure-sample-deployment.md:16-438`
- Modify: `tests/docs/test-azure-sample-deployment.sh`

**Interfaces:**
- Consumes: `SUFFIX`, original `SUBSCRIPTION_ID`, optional actual Storage account name
- Produces: `RG`, `VNET`, `INFRA_SUBNET`, `STORAGE`, `STORAGE_CONTAINER`, `UAMI`, `STORAGE_ID`, `UAMI_PID`, `UAMI_CLIENT_ID`, `SUBNET_ID`
- Preserves: `samples/azure-sample-deploy-workflow.yml` as the only full workflow source

- [ ] **Step 1: Write the failing recovery and disclosure tests**

Replace the workflow byte-match extraction with these assertions:

```bash
assert_contains "$DOC_TEXT" \
  "sed -n '1,220p' samples/azure-sample-deploy-workflow.yml" \
  'module 06 must print the authoritative workflow sample'

if grep -F -- '<summary>aca-runner-vnet-blob.yml 전체 내용 보기</summary>' "$DOC" >/dev/null; then
  fail 'module 06 still duplicates the authoritative workflow sample'
fi
```

Replace recovery assertions with:

```bash
for text in \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved subscription ID: " SUBSCRIPTION_ID' \
  'Saved Storage account name if changed' \
  'STORAGE_ID=$(az storage account show' \
  'UAMI_PID=$(az identity show' \
  'UAMI_CLIENT_ID=$(az identity show' \
  'SUBNET_ID=$(az network vnet subnet show'; do
  assert_contains "$recovery_section" "$text" \
    'module 06 minimal recovery contract missing'
done

for removed_text in \
  'Saved ACR name' \
  'Saved Key Vault name if changed' \
  'KEY_VAULT_ID=$(az keyvault show' \
  'KEY_VAULT_SECRET_URI=' \
  'ENV="env-acarunner-$SUFFIX"'; do
  if grep -F -- "$removed_text" "$recovery_section" >/dev/null; then
    fail "module 06 recovery still restores unused state: $removed_text"
  fi
done
```

Extract `recovery_section` from `## 0.` through `## 1.` as Module 05 already does.

- [ ] **Step 2: Run the focused test to verify failure**

Run:

```bash
bash tests/docs/test-azure-sample-deployment.sh
```

Expected: FAIL because the workflow disclosure and unused recovery variables remain.

- [ ] **Step 3: Minimize Module 06 recovery**

Use:

```bash
# 저장한 suffix와 원래 workshop subscription ID를 복원합니다.
read -rp "Saved SUFFIX: " SUFFIX
read -rp "Saved subscription ID: " SUBSCRIPTION_ID

RG="rg-acarunner-$SUFFIX"
VNET="vnet-acarunner-$SUFFIX"
INFRA_SUBNET="snet-aca-infra"
STORAGE="stacarunner$SUFFIX"
STORAGE_CONTAINER="runner-artifacts"
UAMI="id-acarunner-$SUFFIX"

# Storage 이름 충돌 복구가 있었다면 실제 이름을 사용합니다.
read -rp "Saved Storage account name if changed (press Enter to keep ${STORAGE}): " SAVED_STORAGE
if [[ -n "$SAVED_STORAGE" ]]; then
  STORAGE="$SAVED_STORAGE"
fi
unset SAVED_STORAGE

az account set --subscription "$SUBSCRIPTION_ID"
STORAGE_ID=$(az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --query id \
  --output tsv)
UAMI_PID=$(az identity show \
  --resource-group "$RG" \
  --name "$UAMI" \
  --query principalId \
  --output tsv)
UAMI_CLIENT_ID=$(az identity show \
  --resource-group "$RG" \
  --name "$UAMI" \
  --query clientId \
  --output tsv)
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$INFRA_SUBNET" \
  --query id \
  --output tsv)

export SUFFIX SUBSCRIPTION_ID RG VNET INFRA_SUBNET STORAGE STORAGE_CONTAINER UAMI
export STORAGE_ID UAMI_PID UAMI_CLIENT_ID SUBNET_ID
```

Update the explanation, output, and warning text to remove ACR, Key Vault, and Environment references.

- [ ] **Step 4: Delete the workflow disclosure**

Delete the `<details>` block whose summary is `aca-runner-vnet-blob.yml 전체 내용 보기`. Keep the leak guard and writable Azure CLI configuration explanations immediately before the acceptance bullets.

- [ ] **Step 5: Run the focused test**

Run:

```bash
bash tests/docs/test-azure-sample-deployment.sh
python3 tests/test-workflow-yaml.py
```

Expected: both PASS; the sample workflow behavior remains unchanged.

- [ ] **Step 6: Commit**

```bash
git add docs/06-azure-sample-deployment.md tests/docs/test-azure-sample-deployment.sh
git commit -m "docs: remove duplicate Blob workflow guidance" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Validate the Complete Workshop

**Files:**
- Test: `tests/docs/test-execution-comments.sh`
- Verify: all changed docs and tests

**Interfaces:**
- Consumes: completed Tasks 1-4
- Produces: a green, internally consistent workshop

- [ ] **Step 1: Run the complete validator**

Run:

```bash
bash tests/validate-workshop.sh
```

Expected: all checks PASS. If the execution Bash block count changed, the only permitted update is the exact expected integer in `tests/docs/test-execution-comments.sh`.

- [ ] **Step 2: Check document integrity**

Run:

```bash
git diff --check
grep -RFn -- '## 태그 범례' docs/0[1-7]-*.md && exit 1 || true
grep -Fn -- '## 2. matrix 4 Job 전체 YAML 확인' docs/05-parallel-scale-validation.md && exit 1 || true
grep -Fn -- '<summary>aca-runner-vnet-blob.yml 전체 내용 보기</summary>' docs/06-azure-sample-deployment.md && exit 1 || true
```

Expected: no whitespace errors and no removed duplicate sections.

- [ ] **Step 3: Review the final diff**

Run:

```bash
git --no-pager diff --stat HEAD~4..HEAD
git status --short --branch
```

Expected: only the planned documents/tests changed, with no uncommitted files.
