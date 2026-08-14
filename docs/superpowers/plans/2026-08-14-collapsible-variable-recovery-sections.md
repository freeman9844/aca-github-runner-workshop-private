# Collapsible Variable Recovery Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize the existing variable recovery instructions in Modules 03 through 06 as an optional Step 0 whose detailed content is collapsed by default.

**Architecture:** Keep each module's recovery commands in the module that consumes them, but wrap the recovery body in one native GitHub Markdown `<details>` block. Module 04 merges its Azure and GitHub recovery steps into one Step 0 with two internal subsections; required workshop actions are renumbered from Step 1. Existing Bash documentation contract tests enforce the disclosure structure, retained safety commands, and heading order.

**Tech Stack:** GitHub-flavored Markdown, HTML `<details>/<summary>`, Bash documentation contract tests

## Global Constraints

- Modify only Modules 03, 04, 05, and 06, which already contain session variable recovery instructions.
- Do not add recovery sections to Modules 01 or 02.
- Every affected module must use exactly `## 0. 세션 재연결 시 변수 복구 (선택)`.
- Every affected module must use exactly one `<details>` block with `<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>`.
- Preserve existing recovery commands, resource-name derivation, expected output, warnings, and PAT non-echoing behavior.
- The first required action in every affected module starts at Step 1.
- Do not place required non-recovery actions inside a collapsed block.
- Include blank lines after `<summary>` and before `</details>`.

## File Structure

- `docs/03-runner-image.md`: Collapsed Azure variable recovery Step 0 and required-step renumbering.
- `docs/04-event-job-keda.md`: Combined Azure and GitHub/PAT recovery Step 0, collapsed body, and required-step renumbering.
- `docs/05-parallel-scale-validation.md`: Existing optional Step 0 body wrapped in the common disclosure block.
- `docs/06-security-limitations-cleanup.md`: Cleanup variable recovery standardized and collapsed.
- `tests/docs/test-build-deploy.sh`: Module 03 and 04 disclosure, heading, ordering, and retained-command contracts.
- `tests/docs/test-scale-validation.sh`: Module 05 disclosure and placement contracts.
- `tests/docs/test-security-cleanup.sh`: Module 06 disclosure and placement contracts.

---

### Task 1: Collapse and Renumber Module 03 and Module 04 Recovery

**Files:**
- Modify: `docs/03-runner-image.md:24-179`
- Modify: `docs/04-event-job-keda.md:24-288`
- Test: `tests/docs/test-build-deploy.sh`

**Interfaces:**
- Consumes: Existing saved `SUFFIX`, actual `ACR`, Azure lookup commands, and non-echoing `GITHUB_PAT` input documented in Modules 03 and 04.
- Produces: One common collapsed Step 0 in each module; Module 03 required Steps 1-4; Module 04 required Steps 1-3.

- [ ] **Step 1: Add failing disclosure and heading contracts**

Add this helper and its calls after the Module 03/04 file existence checks in
`tests/docs/test-build-deploy.sh`:

```bash
assert_collapsed_recovery() {
  local doc="$1"
  local module="$2"
  local heading_line summary_line close_line first_step_line

  grep -Fx '## 0. 세션 재연결 시 변수 복구 (선택)' "$doc" >/dev/null ||
    fail "$module missing optional Step 0 recovery heading"
  [[ "$(grep -Fc '<details>' "$doc")" -eq 1 ]] ||
    fail "$module must contain exactly one details block"
  [[ "$(grep -Fc '</details>' "$doc")" -eq 1 ]] ||
    fail "$module must close exactly one details block"
  grep -Fx '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$doc" >/dev/null ||
    fail "$module missing recovery disclosure summary"

  heading_line="$(grep -nF -m1 '## 0. 세션 재연결 시 변수 복구 (선택)' "$doc" | cut -d: -f1)"
  summary_line="$(grep -nF -m1 '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$doc" | cut -d: -f1)"
  close_line="$(grep -nF -m1 '</details>' "$doc" | cut -d: -f1)"
  first_step_line="$(grep -nE -m1 '^## 1\\. ' "$doc" | cut -d: -f1)"

  (( heading_line < summary_line && summary_line < close_line && close_line < first_step_line )) ||
    fail "$module recovery details must close before required Step 1"
}

assert_collapsed_recovery "$IMAGE_DOC" "module 03"
assert_collapsed_recovery "$JOB_DOC" "module 04"
```

Add exact required-heading contracts:

```bash
for heading in \
  '## 1. runner 이미지 파일 읽기' \
  '## 2. 로컬 정적 검사 먼저 실행' \
  '## 3. ACR Tasks로 runner image 빌드' \
  '## 4. 왜 이 구성을 유지하나요?'; do
  grep -Fx "$heading" "$IMAGE_DOC" >/dev/null ||
    fail "module 03 missing renumbered heading: $heading"
done

for heading in \
  '## 1. 기존 Job과 중복 queue watcher 확인' \
  '## 2. ACA Event Job 생성' \
  '## 3. GitHub 쪽에서 미리 확인할 것'; do
  grep -Fx "$heading" "$JOB_DOC" >/dev/null ||
    fail "module 04 missing renumbered heading: $heading"
done

for old_heading in \
  '## 1. 저장해 둔 `SUFFIX`와 `ACR`로 Azure 변수 복구' \
  '## 2. Fine-grained PAT 입력값 다시 로드' \
  '## 2. runner 이미지 파일 읽기' \
  '## 3. 기존 Job과 중복 queue watcher 확인'; do
  if grep -Fx "$old_heading" "$IMAGE_DOC" "$JOB_DOC" >/dev/null; then
    fail "old recovery or step heading remains: $old_heading"
  fi
done

grep -Fx '### Azure 리소스 변수' "$JOB_DOC" >/dev/null ||
  fail "module 04 missing Azure recovery subsection"
grep -Fx '### GitHub 인증 변수' "$JOB_DOC" >/dev/null ||
  fail "module 04 missing GitHub recovery subsection"
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: FAIL with `module 03 missing optional Step 0 recovery heading`.

- [ ] **Step 3: Convert Module 03 recovery to collapsed Step 0**

Replace the current Module 03 recovery heading and opening body with:

```markdown
## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

👁️ **설명**
```

Insert the closing tag after the existing sentence ending with
`입력한 실제 ACR 값이 그대로 출력되어야 합니다.`:

```markdown

</details>
```

Rename the required Module 03 headings exactly:

```markdown
## 1. runner 이미지 파일 읽기
## 2. 로컬 정적 검사 먼저 실행
## 3. ACR Tasks로 runner image 빌드
## 4. 왜 이 구성을 유지하나요?
```

Do not change the recovery Bash block, `read -rp` prompts, Azure lookups,
exports, example values, image tag, or troubleshooting content.

- [ ] **Step 4: Combine and collapse Module 04 recovery**

Replace the current Module 04 Step 1 heading and opening with:

```markdown
## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

### Azure 리소스 변수

👁️ **설명**
```

Replace the current `## 2. Fine-grained PAT 입력값 다시 로드` heading with:

```markdown
### GitHub 인증 변수
```

Insert the closing tag after the existing PAT expected-output bullet ending
with `lab repository 하나에만 접근할 수 있어야 합니다.`:

```markdown

</details>
```

Rename the required Module 04 headings exactly:

```markdown
## 1. 기존 Job과 중복 queue watcher 확인
## 2. ACA Event Job 생성
## 3. GitHub 쪽에서 미리 확인할 것
```

Update the duplicate-watcher troubleshooting reference from:

```markdown
3단계의 `az containerapp job list` query
```

to:

```markdown
1단계의 `az containerapp job list` query
```

Do not alter the PAT input commands:

```bash
read -rp "GitHub owner: " GITHUB_OWNER
read -rp "Private repository name: " GITHUB_REPO
read -rsp "Fine-grained PAT: " GITHUB_PAT
printf '\n'

export GITHUB_OWNER GITHUB_REPO GITHUB_PAT
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: `PASS: image build and Event Job docs`

- [ ] **Step 6: Commit Module 03 and 04**

```bash
git add docs/03-runner-image.md docs/04-event-job-keda.md tests/docs/test-build-deploy.sh
git commit -m "docs: collapse image and job variable recovery" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Collapse Module 05 and Module 06 Recovery

**Files:**
- Modify: `docs/05-parallel-scale-validation.md:15-42`
- Modify: `docs/06-security-limitations-cleanup.md:15-40`
- Test: `tests/docs/test-scale-validation.sh`
- Test: `tests/docs/test-security-cleanup.sh`

**Interfaces:**
- Consumes: Existing Module 05 `SUFFIX`/Log Analytics recovery and Module 06 cleanup target recovery.
- Produces: The same common Step 0 disclosure contract in Modules 05 and 06 without changing required-step numbering.

- [ ] **Step 1: Add failing Module 05 disclosure contracts**

Add this helper after the Module 05 file and screenshot existence checks in
`tests/docs/test-scale-validation.sh`:

```bash
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -Fx '## 0. 세션 재연결 시 변수 복구 (선택)' "$DOC" >/dev/null ||
  fail "module 05 missing optional Step 0 recovery heading"
[[ "$(grep -Fc '<details>' "$DOC")" -eq 1 ]] ||
  fail "module 05 must contain exactly one details block"
[[ "$(grep -Fc '</details>' "$DOC")" -eq 1 ]] ||
  fail "module 05 must close exactly one details block"
grep -Fx '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$DOC" >/dev/null ||
  fail "module 05 missing recovery disclosure summary"

details_close_line="$(grep -nF -m1 '</details>' "$DOC" | cut -d: -f1)"
legend_line="$(grep -nF -m1 '## 태그 범례' "$DOC" | cut -d: -f1)"
(( details_close_line < legend_line )) ||
  fail "module 05 recovery details must close before the tag legend"
```

- [ ] **Step 2: Add failing Module 06 disclosure contracts**

Add a `fail` helper after the Module 06 file checks in
`tests/docs/test-security-cleanup.sh`:

```bash
fail() {
  echo "FAIL: $*" >&2
  exit 1
}
```

Then add:

```bash
grep -Fx '## 0. 세션 재연결 시 변수 복구 (선택)' "$DOC" >/dev/null ||
  fail "module 06 missing optional Step 0 recovery heading"
[[ "$(grep -Fc '<details>' "$DOC")" -eq 1 ]] ||
  fail "module 06 must contain exactly one details block"
[[ "$(grep -Fc '</details>' "$DOC")" -eq 1 ]] ||
  fail "module 06 must close exactly one details block"
grep -Fx '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$DOC" >/dev/null ||
  fail "module 06 missing recovery disclosure summary"

if grep -Fx '## 0. 정리 전에 변수 복구' "$DOC" >/dev/null; then
  fail "module 06 still uses the old recovery heading"
fi

details_close_line="$(grep -nF -m1 '</details>' "$DOC" | cut -d: -f1)"
legend_line="$(grep -nF -m1 '## 태그 범례' "$DOC" | cut -d: -f1)"
(( details_close_line < legend_line )) ||
  fail "module 06 recovery details must close before the tag legend"
```

- [ ] **Step 3: Run both focused tests and verify RED**

Run:

```bash
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected:

```text
FAIL: module 05 must contain exactly one details block
```

After the first command fails, run the second command separately. It must fail
with:

```text
FAIL: module 06 missing optional Step 0 recovery heading
```

- [ ] **Step 4: Wrap Module 05 Step 0 body**

Keep the existing common heading and insert:

```markdown
## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

👁️ **설명**
```

Insert the closing tag after the existing expected-output bullet ending with
`원래 실습에서 사용한 suffix 기록을 다시 확인합니다.`:

```markdown

</details>
```

Do not change the `SUFFIX`, `RG`, `LOG`, `JOB`, `LOG_ID`, or `printf`
commands. Keep `## 태그 범례` and Steps 1 through 11 outside the disclosure.

- [ ] **Step 5: Standardize and wrap Module 06 Step 0 body**

Replace:

```markdown
## 0. 정리 전에 변수 복구
```

with:

```markdown
## 0. 세션 재연결 시 변수 복구 (선택)

<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>
```

Insert the closing tag after the warning list ending with
`잘못된 RG를 지우면 다른 실습/리소스까지 함께 삭제될 수 있습니다.`:

```markdown

</details>
```

Keep both cleanup recovery commands unchanged:

```bash
SUFFIX="<your-saved-suffix>"
RG="rg-acarunner-$SUFFIX"

printf '정리 대상 RG=%s\n' "$RG"
```

```bash
az group list --query "[?starts_with(name, 'rg-acarunner-')].name" --output table
```

Keep `## 태그 범례` and Steps 1 through 6 outside the disclosure.

- [ ] **Step 6: Run both focused tests and verify GREEN**

Run:

```bash
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh
```

Expected:

```text
PASS: parallel scale validation doc
PASS: security and cleanup doc
```

- [ ] **Step 7: Commit Module 05 and 06**

```bash
git add docs/05-parallel-scale-validation.md docs/06-security-limitations-cleanup.md \
  tests/docs/test-scale-validation.sh tests/docs/test-security-cleanup.sh
git commit -m "docs: collapse validation and cleanup variable recovery" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Verify Cross-Module Disclosure Consistency

**Files:**
- Verify: `docs/03-runner-image.md`
- Verify: `docs/04-event-job-keda.md`
- Verify: `docs/05-parallel-scale-validation.md`
- Verify: `docs/06-security-limitations-cleanup.md`
- Verify: `tests/docs/test-build-deploy.sh`
- Verify: `tests/docs/test-scale-validation.sh`
- Verify: `tests/docs/test-security-cleanup.sh`

**Interfaces:**
- Consumes: Task 1 and Task 2 committed documentation and contract tests.
- Produces: Fresh evidence that all four modules render the same optional Step 0 contract and the full workshop remains valid.

- [ ] **Step 1: Verify exact common markers across all four modules**

Run:

```bash
for doc in \
  docs/03-runner-image.md \
  docs/04-event-job-keda.md \
  docs/05-parallel-scale-validation.md \
  docs/06-security-limitations-cleanup.md; do
  test "$(grep -Fc '## 0. 세션 재연결 시 변수 복구 (선택)' "$doc")" -eq 1
  test "$(grep -Fc '<details>' "$doc")" -eq 1
  test "$(grep -Fc '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$doc")" -eq 1
  test "$(grep -Fc '</details>' "$doc")" -eq 1
done
```

Expected: exit code 0 with no output.

- [ ] **Step 2: Run the complete workshop validators**

Run:

```bash
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
bash -n runner/entrypoint.sh
git diff --check
```

Expected:

```text
PASS: complete workshop validation
PASS: integrated workshop validator
```

`bash -n` and `git diff --check` must exit 0 without output.

- [ ] **Step 3: Review the final heading sequence**

Run:

```bash
grep -n '^## ' \
  docs/03-runner-image.md \
  docs/04-event-job-keda.md \
  docs/05-parallel-scale-validation.md \
  docs/06-security-limitations-cleanup.md
```

Expected:

- Module 03: Step 0 followed by Steps 1 through 4.
- Module 04: Step 0 followed by Steps 1 through 3.
- Module 05: Step 0 followed by Steps 1 through 11.
- Module 06: Step 0 followed by Steps 1 through 6.
- `## 목표`, `## 태그 범례`, and `## 트러블슈팅` remain present.

- [ ] **Step 4: Confirm no verification-only commit is needed**

Run:

```bash
git status --short
```

Expected: no output. If output exists, inspect it and commit only changes
required by Tasks 1 or 2; do not create a commit containing test logs or
temporary files.
