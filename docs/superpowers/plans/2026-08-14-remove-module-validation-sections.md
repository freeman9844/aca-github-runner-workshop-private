# Module Validation Section Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove redundant standalone validation and completion-summary sections while retaining safety-critical checks beside the operations they protect.

**Architecture:** This is a documentation-only restructuring guarded by shell contract tests. Each task first changes a documentation test to reject the old standalone heading and require any safety-critical command that must remain, then updates the corresponding module and runs the focused test.

**Tech Stack:** Markdown, Bash, grep, existing workshop validators

## Global Constraints

- Preserve Module 01 repository, Actions, and runner-administration permission checks.
- Preserve Module 04 duplicate queue-watcher and existing Job checks.
- Preserve Module 05 in full.
- Preserve Module 06 resource-group deletion completion and GitHub cleanup checks.
- Do not change Azure, GitHub, KEDA, runner, PAT, or security behavior.
- Do not remove expected outputs that directly identify command failure.
- Use the existing test scripts and validators only; add no new tools.

---

### Task 1: Remove Summary-Only Sections from Modules 01 and 06

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh`
- Modify: `tests/docs/test-security-cleanup.sh`
- Modify: `docs/01-prerequisites-github.md`
- Modify: `docs/06-security-limitations-cleanup.md`

**Interfaces:**
- Consumes: existing Module 01 permission-check commands and Module 06 cleanup commands
- Produces: Module 01 ending after permission verification and Module 06 ending after troubleshooting, without summary-only sections

- [ ] **Step 1: Add failing assertions for removed headings**

Add this assertion to `tests/docs/test-prerequisites-foundation.sh` after the
required Module 01 text loop:

```bash
if grep -Fx '## 8. 검증' "$PREREQ" >/dev/null; then
  fail "module 01 still has a redundant final validation section"
fi
```

In `tests/docs/test-security-cleanup.sh`, remove
`'## 7. 전체 워크숍 완료 확인'` from the required-text loop and add:

```bash
if grep -Fx '## 7. 전체 워크숍 완료 확인' "$DOC" >/dev/null; then
  echo "FAIL: module 06 still has a redundant workshop completion summary" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected:

- Module 01 test fails with `module 01 still has a redundant final validation section`.
- Module 06 test fails with `module 06 still has a redundant workshop completion summary`.

- [ ] **Step 3: Remove the Module 01 summary-only validation section**

Delete the complete block beginning with:

```markdown
## 8. 검증
```

and ending immediately before:

```markdown
## 트러블슈팅
```

Keep `## 7. 저장소·Actions·runner administration 권한 검증` unchanged.

- [ ] **Step 4: Remove the Module 06 completion summary**

Delete the complete block beginning with:

```markdown
## 7. 전체 워크숍 완료 확인
```

and ending before the final navigation line. Keep `## 5. 리소스 그룹 삭제 완료
여부 확인`, `## 6. GitHub 측 정리 체크리스트`, and `## 트러블슈팅`.

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected:

```text
PASS: prerequisites and foundation docs
PASS: security and cleanup doc
```

- [ ] **Step 6: Commit Task 1**

```bash
git add docs/01-prerequisites-github.md \
  docs/06-security-limitations-cleanup.md \
  tests/docs/test-prerequisites-foundation.sh \
  tests/docs/test-security-cleanup.sh
git commit -m "docs: remove module completion summaries" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Consolidate Module 02 Safety Checks

**Files:**
- Modify: `tests/docs/test-prerequisites-foundation.sh`
- Modify: `docs/02-azure-foundation.md`

**Interfaces:**
- Consumes: Module 02 ACR and UAMI creation steps
- Produces: inline ACR security, ARM authentication, and `AcrPull` checks with no standalone `## 6. 검증`

- [ ] **Step 1: Add failing Module 02 structure and safety assertions**

Add the following to `tests/docs/test-prerequisites-foundation.sh`:

```bash
if grep -Fx '## 6. 검증' "$FOUNDATION" >/dev/null; then
  fail "module 02 still has a standalone validation section"
fi

for text in \
  'az acr show \' \
  'adminUserEnabled:adminUserEnabled' \
  'az acr config authentication-as-arm show \' \
  'az role assignment list \' \
  'roleDefinitionName'; do
  grep -F -- "$text" "$FOUNDATION" >/dev/null ||
    fail "module 02 lost safety check: $text"
done
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: FAIL with `module 02 still has a standalone validation section`.

- [ ] **Step 3: Move ACR checks into Section 4**

After the `ACR_SERVER` and `ACR_ID` assignments in
`## 4. ACR 만들기와 ARM authentication 활성화`, keep these commands:

```bash
az acr show \
  --name "$ACR" \
  --query "{loginServer:loginServer,adminUserEnabled:adminUserEnabled}" \
  --output json

az acr config authentication-as-arm show \
  --registry "$ACR" \
  --query status \
  --output tsv
```

Update that section's expected output to require:

- `<registry>.azurecr.io`
- `"adminUserEnabled": false`
- `enabled`

- [ ] **Step 4: Move the role-assignment check into Section 5**

Immediately after `az role assignment create`, keep:

```bash
az role assignment list \
  --assignee "$UAMI_PID" \
  --scope "$ACR_ID" \
  --query "[].{role:roleDefinitionName,principalType:principalType,scope:scope}" \
  --output table
```

Update the expected output in Section 5 to state that the table contains
`AcrPull` and `ServicePrincipal`.

- [ ] **Step 5: Delete the remaining standalone Module 02 validation block**

Delete `## 6. 검증`, including:

- the resource-group inventory command,
- the duplicate diagnostic-setting query,
- the duplicate ACR and ARM authentication commands,
- the duplicate `AcrPull` query,
- the combined expected-output list.

Do not change the troubleshooting or ACR collision recovery sections.

- [ ] **Step 6: Run the focused test and verify GREEN**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected:

```text
PASS: prerequisites and foundation docs
```

- [ ] **Step 7: Commit Task 2**

```bash
git add docs/02-azure-foundation.md tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: inline Azure foundation safety checks" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Consolidate Module 03 and 04 Checks

**Files:**
- Modify: `tests/docs/test-build-deploy.sh`
- Modify: `docs/03-runner-image.md`
- Modify: `docs/04-event-job-keda.md`

**Interfaces:**
- Consumes: Module 03 ACR build step and Module 04 Event Job creation step
- Produces: inline image/ACR and Job-definition checks with no standalone validation headings

- [ ] **Step 1: Add failing heading-removal assertions**

Add to `tests/docs/test-build-deploy.sh`:

```bash
for heading in \
  '## 5. 태그와 ACR 보안 설정 검증' \
  '## 5. secret을 노출하지 않고 Job 상태 검증'; do
  if grep -Fx "$heading" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "standalone validation heading remains: $heading"
  fi
done
```

Extend the required Module 03 text list with:

```bash
'az acr repository show-tags' \
'adminUserEnabled:adminUserEnabled'
```

Extend the required Module 04 text list with:

```bash
'triggerType:properties.configuration.triggerType' \
'properties.configuration.eventTriggerConfig.scale.rules' \
'az containerapp job execution list'
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: FAIL identifying at least one remaining standalone validation heading.

- [ ] **Step 3: Merge Module 03 checks into the build step**

Move these commands directly after `az acr build` inside
`## 4. ACR Tasks로 runner image 빌드`:

```bash
az acr repository show-tags \
  --name "$ACR" \
  --repository github-actions-runner \
  --output table

az acr show \
  --name "$ACR" \
  --query "{loginServer:loginServer,adminUserEnabled:adminUserEnabled}" \
  --output table
```

Merge the tag and `adminUserEnabled=False` expectations into Section 4, delete
`## 5. 태그와 ACR 보안 설정 검증`, and rename
`## 6. 왜 이 구성을 유지하나요?` to `## 5. 왜 이 구성을 유지하나요?`.

- [ ] **Step 4: Merge Module 04 checks into Job creation**

After:

```bash
az containerapp job create "${JOB_CREATE_ARGS[@]}"
unset JOB_CREATE_ARGS GITHUB_PAT
```

keep the concise Job query and initial execution list:

```bash
az containerapp job show \
  --name "$JOB" \
  --resource-group "$RG" \
  --query "{
    triggerType:properties.configuration.triggerType,
    replicaTimeout:properties.configuration.replicaTimeout,
    minExecutions:properties.configuration.eventTriggerConfig.scale.minExecutions,
    maxExecutions:properties.configuration.eventTriggerConfig.scale.maxExecutions,
    pollingInterval:properties.configuration.eventTriggerConfig.scale.pollingInterval,
    rules:properties.configuration.eventTriggerConfig.scale.rules,
    image:properties.template.containers[0].image
  }" \
  --output yaml

az containerapp job execution list \
  --name "$JOB" \
  --resource-group "$RG" \
  --output table
```

Merge the current expected YAML and zero-execution explanation into Section 4.
Delete `## 5. secret을 노출하지 않고 Job 상태 검증` and rename
`## 6. GitHub 쪽에서 미리 확인할 것` to
`## 5. GitHub 쪽에서 미리 확인할 것`.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected:

```text
PASS: image build and Event Job docs
```

- [ ] **Step 6: Commit Task 3**

```bash
git add docs/03-runner-image.md \
  docs/04-event-job-keda.md \
  tests/docs/test-build-deploy.sh
git commit -m "docs: inline image and Job safety checks" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Run Integrated Validation and Review the Final Structure

**Files:**
- Verify: `docs/01-prerequisites-github.md`
- Verify: `docs/02-azure-foundation.md`
- Verify: `docs/03-runner-image.md`
- Verify: `docs/04-event-job-keda.md`
- Verify: `docs/05-parallel-scale-validation.md`
- Verify: `docs/06-security-limitations-cleanup.md`
- Verify: `tests/validate-workshop.sh`
- Verify: `tests/test-validate-workshop.sh`

**Interfaces:**
- Consumes: Tasks 1-3
- Produces: a validated workshop with no redundant standalone validation sections

- [ ] **Step 1: Confirm removed headings are absent**

Run:

```bash
for contract in \
  'docs/01-prerequisites-github.md|## 8. 검증' \
  'docs/02-azure-foundation.md|## 6. 검증' \
  'docs/03-runner-image.md|## 5. 태그와 ACR 보안 설정 검증' \
  'docs/04-event-job-keda.md|## 5. secret을 노출하지 않고 Job 상태 검증' \
  'docs/06-security-limitations-cleanup.md|## 7. 전체 워크숍 완료 확인'; do
  file="${contract%%|*}"
  heading="${contract#*|}"
  ! grep -Fx "$heading" "$file"
done
```

Expected: no output and exit status 0.

- [ ] **Step 2: Confirm preserved validation flows remain**

Run:

```bash
grep -F '## 7. 저장소·Actions·runner administration 권한 검증' \
  docs/01-prerequisites-github.md
grep -F '## 8. runner lifecycle marker를 명시적으로 검증' \
  docs/05-parallel-scale-validation.md
grep -F '## 5. 리소스 그룹 삭제 완료 여부 확인' \
  docs/06-security-limitations-cleanup.md
```

Expected: all three headings are printed.

- [ ] **Step 3: Run the complete validators**

Run:

```bash
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
bash -n runner/entrypoint.sh
git diff --check master...HEAD
```

Expected:

```text
PASS: complete workshop validation
PASS: integrated workshop validator
```

and exit status 0.

- [ ] **Step 4: Review the branch diff**

Run:

```bash
git status --short --branch
git --no-pager diff master...HEAD --stat
git --no-pager diff master...HEAD -- \
  docs/01-prerequisites-github.md \
  docs/02-azure-foundation.md \
  docs/03-runner-image.md \
  docs/04-event-job-keda.md \
  docs/06-security-limitations-cleanup.md \
  tests/docs/test-prerequisites-foundation.sh \
  tests/docs/test-build-deploy.sh \
  tests/docs/test-security-cleanup.sh
```

Expected: only the design/plan artifacts, five workshop modules, and three
documentation tests are changed.

- [ ] **Step 5: Request code review**

Use `superpowers:requesting-code-review` with base branch `master` and review
the complete branch diff. Fix every Critical or Important finding before
integration.
