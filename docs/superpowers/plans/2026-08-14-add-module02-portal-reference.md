# Module 02 Azure Portal Reference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional Azure Portal resource-group reference and the supplied screenshot immediately before Module 02 troubleshooting.

**Architecture:** Extend the existing Module 02 Markdown with one unnumbered reference section and store the screenshot beside the other workshop images. Update the existing documentation contract test first so it verifies content, image existence, and section placement.

**Tech Stack:** Markdown, PNG, Bash, grep, existing workshop validators

## Global Constraints

- The reference is optional; Cloud Shell remains the primary workshop interface.
- Use the heading `## 참고: Azure 관리 포털에서 생성된 리소스 확인`.
- Place the section immediately before `## 트러블슈팅`.
- Use the image path `docs/images/02-azure-portal-resource-group-resources.png`.
- Mention **Resource groups → `$RG` → Overview → Resources**.
- Mention Azure Container Registry, Container Apps Environment, Managed Identity, and Log Analytics workspace.
- Do not present the screenshot's sample suffix or names as required participant values.
- Preserve the removal of Module 02's standalone validation section.

---

### Task 1: Add the Optional Portal Resource Reference

**Files:**
- Create: `docs/images/02-azure-portal-resource-group-resources.png`
- Modify: `docs/02-azure-foundation.md`
- Test: `tests/docs/test-prerequisites-foundation.sh`

**Interfaces:**
- Consumes: the supplied screenshot at `/mnt/c/Users/JUNGWO~1/AppData/Local/Temp/wmux/screenshot-1786688574227.png`
- Produces: an optional Module 02 portal reference with a checked-in image and contract coverage

- [ ] **Step 1: Write the failing documentation contract**

In `tests/docs/test-prerequisites-foundation.sh`, define the screenshot after
the existing Module 02 path:

```bash
PORTAL_SCREENSHOT="$ROOT/docs/images/02-azure-portal-resource-group-resources.png"
```

Add the file assertion:

```bash
[[ -f "$PORTAL_SCREENSHOT" ]] ||
  fail "module 02 Azure portal screenshot missing"
```

Add these required Module 02 strings to the existing `$FOUNDATION` contract:

```bash
'## 참고: Azure 관리 포털에서 생성된 리소스 확인' \
'선택 참고' \
'Resource groups' \
'`$RG`' \
'Overview' \
'Resources' \
'Azure Container Registry' \
'Container Apps Environment' \
'Managed Identity' \
'Log Analytics workspace' \
'![Azure Portal 리소스 그룹 Overview에서 Module 02 생성 리소스를 확인하는 화면](images/02-azure-portal-resource-group-resources.png)'
```

Add a placement assertion:

```bash
portal_reference_line="$(
  grep -nF -m1 '## 참고: Azure 관리 포털에서 생성된 리소스 확인' \
    "$FOUNDATION" | cut -d: -f1
)"
troubleshooting_line="$(
  grep -nF -m1 '## 트러블슈팅' "$FOUNDATION" | cut -d: -f1
)"
(( portal_reference_line < troubleshooting_line )) ||
  fail "module 02 portal reference must appear before troubleshooting"
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: FAIL with `module 02 Azure portal screenshot missing`.

- [ ] **Step 3: Copy the supplied screenshot**

Run:

```bash
install -m 0644 \
  /mnt/c/Users/JUNGWO~1/AppData/Local/Temp/wmux/screenshot-1786688574227.png \
  docs/images/02-azure-portal-resource-group-resources.png
```

Confirm the file:

```bash
file docs/images/02-azure-portal-resource-group-resources.png
```

Expected: PNG image data.

- [ ] **Step 4: Add the optional reference section**

Immediately before `## 트러블슈팅` in `docs/02-azure-foundation.md`, add:

```markdown
## 참고: Azure 관리 포털에서 생성된 리소스 확인

👁️ **설명**

이 단계는 **선택 참고**입니다. 워크숍의 필수 명령은 Cloud Shell에서
완료되며, Azure 관리 포털에서는 생성 결과를 시각적으로 확인할 수 있습니다.

Azure Portal에서 **Resource groups → `$RG` → Overview → Resources**로
이동하면 Module 02에서 만든 다음 리소스를 한 화면에서 확인할 수 있습니다.

- Azure Container Registry
- Container Apps Environment
- Managed Identity
- Log Analytics workspace

화면의 suffix와 리소스 이름은 예시이며 참가자의 `$RG`와 실제 생성 이름은
다를 수 있습니다.

> **참고 화면:** Azure Portal의 리소스 그룹 Overview에서 Module 02가 만든
> 리소스를 확인하는 예시입니다.

![Azure Portal 리소스 그룹 Overview에서 Module 02 생성 리소스를 확인하는 화면](images/02-azure-portal-resource-group-resources.png)
```

- [ ] **Step 5: Run focused and integrated verification**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
```

Expected:

```text
PASS: prerequisites and foundation docs
PASS: complete workshop validation
PASS: integrated workshop validator
```

- [ ] **Step 6: Commit**

```bash
git add docs/02-azure-foundation.md \
  docs/images/02-azure-portal-resource-group-resources.png \
  tests/docs/test-prerequisites-foundation.sh
git commit -m "docs: add Module 02 portal resource reference" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 7: Request task review**

Use `superpowers:requesting-code-review` to verify the optional wording,
placement, screenshot path, alt text, and preservation of the removed
standalone validation section.
