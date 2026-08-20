# All Module Execution Comments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add concise Korean purpose comments to every `🟢 실행` Bash block in Modules 01 and 03-07 without changing commands, variables, order, output, or behavior.

**Architecture:** Add one structural documentation test that discovers exact `🟢 실행` markers and verifies that each following Bash block starts with a Korean comment. Then update the workshop module documents in small module groups, preserving all existing comments and command text. Existing module contract tests protect command and security behavior; the new structural test protects cross-module comment consistency.

**Tech Stack:** Markdown, Bash, embedded Python 3 for Markdown structure validation, existing shell-based workshop validator.

**Spec:** `docs/superpowers/specs/2026-08-20-all-module-execution-comments-design.md`

## Global Constraints

- Modify only `🟢 실행` Bash blocks in Module 01 and Modules 03-07, plus the documentation test runner.
- Do not modify Module 02 commands or comments; use them as the style reference.
- Every target Bash block's first non-empty line must be a Korean `# ` purpose comment.
- Add 1-2 concise lines before each logical command group; explain why the group runs and where its result is used.
- Preserve every existing command, option, variable, execution order, expected output, security boundary, Markdown fence, and disclosure boundary.
- Preserve existing Module 04 argument-array comments and Module 05 ingestion-wait comments; fill gaps without duplicating them.
- Do not add comments to UI-only `🟢 실행` steps or `📋 예상 출력` blocks.
- Do not lock exact Korean prose or comment counts in tests; test the structural leading-comment contract and review group coverage manually.

---

### Task 1: Add the cross-module execution-comment contract

**Files:**
- Create: `tests/docs/test-execution-comments.sh`
- Modify: `tests/validate-workshop.sh:7-15`

**Interfaces:**
- Consumes: Markdown files `docs/01-prerequisites-github.md` through `docs/07-security-limitations-cleanup.md`.
- Produces: A validator that exits nonzero when an exact `🟢 **실행**` marker is followed by a Bash block whose first non-empty line is not a Korean comment.

- [ ] **Step 1: Write the failing structural test**

Create `tests/docs/test-execution-comments.sh` with this exact implementation:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
docs = sorted((root / "docs").glob("0[1-7]-*.md"))
korean = re.compile(r"[가-힣]")
failures = []
block_count = 0

for doc in docs:
    lines = doc.read_text(encoding="utf-8").splitlines()
    for marker_index, line in enumerate(lines):
        if line != "🟢 **실행**":
            continue

        fence_index = None
        for index in range(marker_index + 1, min(len(lines), marker_index + 40)):
            candidate = lines[index]
            if candidate.startswith("## ") or candidate in {
                "🟢 **실행**",
                "👁️ **설명**",
                "📋 **예상 출력**",
                "⚠️ **주의**",
            }:
                break
            if candidate == "```bash":
                fence_index = index
                break

        if fence_index is None:
            continue

        block_count += 1
        closing_index = next(
            index
            for index in range(fence_index + 1, len(lines))
            if lines[index] == "```"
        )
        first_line = next(
            (candidate.strip() for candidate in lines[fence_index + 1:closing_index] if candidate.strip()),
            "",
        )
        if not first_line.startswith("# ") or not korean.search(first_line):
            failures.append(
                f"{doc.relative_to(root)}:{fence_index + 2}: "
                "execution Bash block must start with a Korean purpose comment"
            )

if block_count != 36:
    failures.append(f"expected 36 execution Bash blocks, found {block_count}")

if failures:
    print("\n".join(f"FAIL: {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)

print("PASS: execution Bash blocks start with Korean comments")
PY
```

- [ ] **Step 2: Run the new test and verify RED**

Run:

```bash
bash tests/docs/test-execution-comments.sh
```

Expected: FAIL with 29 block locations from Modules 01 and 03-07. Module 02's six blocks and Module 05's ingestion-wait block already satisfy the leading-comment contract.

- [ ] **Step 3: Wire the new test into the integrated validator**

Add this line after `bash tests/docs/test-security-cleanup.sh` in `tests/validate-workshop.sh`:

```bash
bash tests/docs/test-execution-comments.sh
```

- [ ] **Step 4: Confirm the integrated validator now fails for the intended reason**

Run:

```bash
bash tests/test-validate-workshop.sh
```

Expected: FAIL because `tests/docs/test-execution-comments.sh` reports missing leading Korean comments, not because of syntax or an unrelated contract.

- [ ] **Step 5: Commit the failing contract**

```bash
git add tests/docs/test-execution-comments.sh tests/validate-workshop.sh
git commit -m "test: require Korean execution comments" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Comment Module 01 and Module 03 execution groups

**Files:**
- Modify: `docs/01-prerequisites-github.md:69-310`
- Modify: `docs/03-runner-image.md:33-380`
- Test: `tests/docs/test-prerequisites-foundation.sh`
- Test: `tests/docs/test-build-deploy.sh`
- Test: `tests/docs/test-execution-comments.sh`

**Interfaces:**
- Consumes: The structural contract from Task 1 and existing Module 01/03 command contracts.
- Produces: Module 01's five and Module 03's four execution Bash blocks with purpose-first Korean comments.

- [ ] **Step 1: Add Module 01 comments without changing commands**

Insert the following comments at the named command groups:

```text
# 사용 가능한 Azure subscription을 확인하고 workshop 리소스를 만들 대상을 선택합니다.
  before: az account list

# 이후 모든 Azure CLI 명령이 선택한 subscription을 사용하도록 active context를 바꿉니다.
  before: read -rp "Azure subscription ID: " SUBSCRIPTION_ID

# 잘못된 subscription에 배포하지 않도록 최종 active context를 확인합니다.
  before: az account show

# ACA 명령 형식을 workshop 기준에 맞추기 위해 containerapp extension 버전을 고정합니다.
  before: az extension add

# VNet, ACA, ACR, Log Analytics와 diagnostic setting 생성에 필요한 provider를 등록합니다.
  before: first az provider register

# public workshop source를 이후 모듈이 기대하는 Cloud Shell 고정 경로에 clone합니다.
  before: git clone

# 상대 경로 기반 문서·runner·sample 명령이 동작하도록 clone directory로 이동합니다.
  before: cd ~/aca-github-runner-workshop

# GitHub API 대상 owner와 private lab repository 이름을 shell-local 변수로 입력받습니다.
  before: read -rp "GitHub owner: " GITHUB_OWNER

# PAT를 다시 출력하지 않고 비어 있지 않은 값이 들어올 때까지 안전하게 입력받습니다.
  before: GITHUB_PAT=

# secret 값 대신 설정 여부만 표시해 GitHub 입력 세 가지가 준비됐는지 확인합니다.
  before: printf 'GITHUB_OWNER=...

# PAT를 command line 인수에 직접 노출하지 않도록 임시 Authorization header를 만듭니다.
  before: printf -v PAT_AUTH_HEADER

# 선택한 repository에 접근할 수 있는지 metadata API로 먼저 확인합니다.
  before: first curl to repository endpoint

# queued workflow를 읽는 데 필요한 Actions read 권한을 확인합니다.
  before: curl to /actions/runs

# ephemeral runner token을 발급할 administration 권한을 실제 POST 요청으로 확인합니다.
  before: curl to /actions/runners/registration-token

# 검증이 끝나면 PAT가 포함된 임시 header 변수를 즉시 제거합니다.
  before: unset PAT_AUTH_HEADER
```

- [ ] **Step 2: Run Module 01's targeted test**

Run:

```bash
bash tests/docs/test-prerequisites-foundation.sh
```

Expected: PASS. The PAT remains shell-local, the API calls remain unchanged, and no secret-printing contract regresses.

- [ ] **Step 3: Add Module 03 comments without changing commands**

Insert these comments:

```text
# 저장해 둔 suffix와 실제 ACR 이름을 입력해 기존 workshop 리소스 이름을 복원합니다.
  before: read -rp "Saved SUFFIX: " SUFFIX

# suffix에서 파생되는 공통 이름과 고정 runner image tag를 다시 구성합니다.
  before: LOC=koreacentral

# workspace, Environment, ACR, subscription과 Resource Group ID를 Azure에서 다시 조회합니다.
  before: LOG_ID=$(az monitor...

# UAMI의 resource, principal, client ID를 각각 Job 연결·RBAC·Azure login 용도로 복원합니다.
  before: UAMI_RID=$(az identity show...

# 다음 명령과 모듈이 같은 값을 사용하도록 복구한 변수를 현재 shell에 export합니다.
  before: export SUFFIX...

# 복구한 suffix, 실제 ACR 이름과 image tag를 출력해 session 상태를 확인합니다.
  before: printf 'SUFFIX=...

# source directory에서 entrypoint 문법, runner 동작과 문서 artifact 일치를 순서대로 검사합니다.
  before: cd ~/aca-github-runner-workshop

# ACR Tasks가 Docker daemon 없이 runner image를 cloud build하고 고정 tag로 저장합니다.
  before: az acr build

# build 결과 tag가 존재하는지 확인한 뒤 ACR의 관리자 계정 비활성화와 ARM 인증을 검증합니다.
  before: az acr repository show-tags
```

- [ ] **Step 4: Run Module 03 and structural tests**

Run:

```bash
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-execution-comments.sh
```

Expected: `test-build-deploy.sh` PASS. The structural test still FAILS only for Modules 04-07.

- [ ] **Step 5: Review that only comment lines changed**

Run:

```bash
git diff --word-diff=porcelain -- docs/01-prerequisites-github.md docs/03-runner-image.md
```

Expected: Every added line begins with `#`; no command token is removed or replaced.

- [ ] **Step 6: Commit Module 01 and 03 comments**

```bash
git add docs/01-prerequisites-github.md docs/03-runner-image.md
git commit -m "docs: explain prerequisite and image commands" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Comment Module 04 and Module 05 execution groups

**Files:**
- Modify: `docs/04-event-job-keda.md:48-315`
- Modify: `docs/05-parallel-scale-validation.md:24-470`
- Test: `tests/docs/test-build-deploy.sh`
- Test: `tests/docs/test-scale-validation.sh`
- Test: `tests/docs/test-execution-comments.sh`

**Interfaces:**
- Consumes: The structural contract and the existing Event Job, KEDA, scale, CLI log, and Log Analytics command contracts.
- Produces: Module 04's five and Module 05's eight Bash blocks with leading and group-level Korean comments.

- [ ] **Step 1: Add Module 04 comments while preserving its existing argument comments**

Insert these comments:

```text
# 저장한 Azure 식별자를 입력해 기존 Environment, ACR, UAMI와 Job 이름을 복원합니다.
  before: first read -rp "Saved SUFFIX: " SUFFIX

# suffix 기반 이름과 고정 image tag를 다시 구성합니다.
  before: LOC=koreacentral

# Job 생성에 필요한 workspace, Environment, ACR, subscription과 identity ID를 다시 조회합니다.
  before: LOG_ID=$(az monitor...

# 복구한 Azure 변수를 현재 shell에 export하고 핵심 값을 출력해 확인합니다.
  before: export SUFFIX...

# KEDA가 감시할 GitHub owner와 private repository를 입력받습니다.
  before: read -rp "GitHub owner: " GITHUB_OWNER

# PAT를 화면에 다시 표시하지 않고 비어 있지 않은 값이 들어올 때까지 읽습니다.
  before: GITHUB_PAT=

# 같은 repository와 label을 감시하는 기존 Event Job을 찾아 queue 경쟁을 예방합니다.
  before: az containerapp job list

# Event Job의 container, KEDA scaler, secret, identity와 resource 설정을 하나의 인자 배열로 구성합니다.
  before: JOB_CREATE_ARGS=(

# 검토한 인자 배열로 Event Job을 만들고 성공 후 PAT가 담긴 임시 shell 값을 제거합니다.
  before: az containerapp job create

# 생성된 Job의 trigger, timeout, scale rule과 image가 의도한 값인지 확인합니다.
  before: az containerapp job show

# workflow queue 전이므로 초기 execution이 없거나 0개인 정상 상태를 확인합니다.
  before: az containerapp job execution list
```

Do not remove or rewrite the 16 existing indented comments inside `JOB_CREATE_ARGS`.

- [ ] **Step 2: Run Module 04's targeted test**

```bash
bash tests/docs/test-build-deploy.sh
```

Expected: PASS with the exact Event Job command, PAT secret mapping, actual YAML example, and screenshots unchanged.

- [ ] **Step 3: Add Module 05 comments**

Insert these comments:

```text
# 저장한 suffix에서 scale validation에 필요한 Resource Group, workspace와 Job 이름을 복원합니다.
  before: SUFFIX="<your-saved-suffix>"

# Log Analytics customer ID를 다시 조회하고 복구한 값을 출력합니다.
  before: LOG_ID=$(az monitor...

# reviewed scale-test workflow를 Cloud Shell에서 확인한 뒤 GitHub 웹 UI에 복사합니다.
  before: cd ~/aca-github-runner-workshop

# workflow 실행 전 최근 이력과 Running execution이 0개인 baseline을 확인합니다.
  before: az containerapp job execution list in Step 3

# scale-out 구간의 상태 변화를 보기 위해 Running execution만 시간순으로 반복 조회합니다.
  before: az containerapp job execution list in Step 5

# 가장 최근 execution 이름을 조회해 뒤의 CLI·Log Analytics 필터 기준으로 저장합니다.
  before: EXECUTION=$(az containerapp job execution list...

# execution을 찾지 못하면 잘못된 이름으로 로그를 조회하지 않고 명확히 중단합니다.
  before: if [[ -z "$EXECUTION" ]]

# 선택한 execution의 runner container stdout·stderr를 최근 100줄까지 확인합니다.
  before: az containerapp job logs show

# 고정 sleep 대신 실제 로그가 들어왔는지 30초마다 확인하며 최대 10분까지 기다립니다.
  keep the existing comment before: LOG_WAIT_TIMEOUT_SECONDS=600

# 로그 유입이 확인되면 replica별 건수와 마지막 수집 시각을 출력합니다.
  keep the existing comment before: aggregate az monitor log-analytics query

# 최신 execution prefix로 같은 replica들의 상세 console log를 시간순으로 조회합니다.
  before: detailed az monitor log-analytics query

# workflow 종료 후 Running execution이 다시 0개로 scale-in 되었는지 확인합니다.
  before: az containerapp job execution list in Step 9
```

- [ ] **Step 4: Run Module 05 and structural tests**

```bash
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-execution-comments.sh
```

Expected: `test-scale-validation.sh` PASS. The structural test still FAILS only for Modules 06 and 07.

- [ ] **Step 5: Review that Event Job and log-wait commands did not change**

```bash
git diff --word-diff=porcelain -- docs/04-event-job-keda.md docs/05-parallel-scale-validation.md
```

Expected: Existing command tokens, KQL, array values, PAT cleanup, timeout values, and screenshots remain unchanged.

- [ ] **Step 6: Commit Module 04 and 05 comments**

```bash
git add docs/04-event-job-keda.md docs/05-parallel-scale-validation.md
git commit -m "docs: explain event job and scale commands" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Comment Module 06 and Module 07 execution groups

**Files:**
- Modify: `docs/06-azure-sample-deployment.md:24-500`
- Modify: `docs/07-security-limitations-cleanup.md:25-205`
- Test: `tests/docs/test-azure-sample-deployment.sh`
- Test: `tests/docs/test-security-cleanup.sh`
- Test: `tests/docs/test-execution-comments.sh`

**Interfaces:**
- Consumes: Existing Managed Identity, RBAC propagation, internal ingress, Private DNS, and cleanup contracts.
- Produces: Module 06's five and Module 07's three Bash blocks with purpose-first Korean comments; all 36 execution Bash blocks then satisfy the structural contract.

- [ ] **Step 1: Add Module 06 comments**

Insert these comments:

```text
# 저장한 suffix와 원래 subscription을 입력해 기존 sample deployment 대상을 복원합니다.
  before: read -rp "Saved SUFFIX: " SUFFIX

# sample app, Environment와 UAMI 이름을 suffix에서 다시 구성합니다.
  before: RG="rg-acarunner-$SUFFIX"

# identity 조회 전에 Azure CLI context를 원래 workshop subscription으로 되돌립니다.
  before: az account set --subscription "$SUBSCRIPTION_ID"

# workflow의 Azure login에 사용할 UAMI client ID를 조회하고 복구 값을 확인합니다.
  before: UAMI_CLIENT_ID=$(az identity show...

# 현재 session의 sample app 이름과 UAMI principal·Resource Group ID를 조회합니다.
  before: SAMPLE_APP="hello-aca-$SUFFIX"

# internal Environment가 존재하는지 확인하고 현재 Container Apps Contributor 할당을 조회합니다.
  before: ENV_STATE=$(az containerapp env show...

# deployment context와 현재 role 상태를 출력해 권한 부여 필요 여부를 결정합니다.
  before: printf 'RG=...

# 역할이 없을 때만 Resource Group 범위의 Container Apps Contributor를 생성합니다.
  before: if [[ "$CONTAINER_APPS_ROLE" != "Container Apps Contributor" ]]

# RBAC 조회 결과가 보일 때까지 조건 기반으로 반복 확인합니다.
  before: for role_attempt in $(seq 1 30)

# 제한 횟수 안에 역할이 보이지 않으면 다음 deployment를 시작하지 않고 중단합니다.
  before: second if [[ "$CONTAINER_APPS_ROLE" != "Container Apps Contributor" ]]

# 최종 role 값을 출력해 workflow 실행 전 권한 준비를 확인합니다.
  before: printf 'CONTAINER_APPS_ROLE=...

# reviewed deployment workflow를 확인한 뒤 GitHub 웹 UI에 같은 내용을 저장합니다.
  before: cd ~/aca-github-runner-workshop

# Environment, subnet, app ingress와 Private DNS 상태를 Azure에서 다시 조회합니다.
  before: ENV_INTERNAL=$(az containerapp env show...

# network·DNS 결과를 한 번에 출력해 internal ingress 계약을 비교합니다.
  before: printf 'environmentInternal=...

# standard Cloud Shell에서 internal FQDN 접근이 실패하는 예상 격리 동작을 확인합니다.
  before: if curl --fail...
```

- [ ] **Step 2: Run Module 06's targeted test**

```bash
bash tests/docs/test-azure-sample-deployment.sh
```

Expected: PASS with role assignment order, workflow source parity, screenshots, and internal-ingress checks unchanged.

- [ ] **Step 3: Add Module 07 comments**

Insert these comments:

```text
# 저장한 suffix에서 cleanup 대상 Resource Group 이름만 복원하고 삭제 대상을 확인합니다.
  before: SUFFIX="<your-saved-suffix>"

# workshop Resource Group의 비동기 삭제를 요청하고 요청이 접수된 이름을 기록합니다.
  before: az group delete

# ResourceGroupNotFound가 반환되는지 조회해 Resource Group 삭제 완료를 확인합니다.
  before: az group show

# 같은 이름과 연관된 Azure resource가 남지 않았는지 최종 목록으로 교차 확인합니다.
  before: az resource list
```

- [ ] **Step 4: Run Module 07 and structural tests**

```bash
bash tests/docs/test-security-cleanup.sh
bash tests/docs/test-execution-comments.sh
```

Expected: Both PASS. The structural test reports exactly 36 compliant execution Bash blocks.

- [ ] **Step 5: Review that RBAC, internal ingress, and cleanup commands did not change**

```bash
git diff --word-diff=porcelain -- docs/06-azure-sample-deployment.md docs/07-security-limitations-cleanup.md
```

Expected: Only `#` comment lines are added; role scopes, query casing, curl behavior, and delete commands are unchanged.

- [ ] **Step 6: Commit Module 06 and 07 comments**

```bash
git add docs/06-azure-sample-deployment.md docs/07-security-limitations-cleanup.md
git commit -m "docs: explain deployment and cleanup commands" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Run final workshop validation and review

**Files:**
- Review: `docs/01-prerequisites-github.md`
- Review: `docs/02-azure-foundation.md`
- Review: `docs/03-runner-image.md`
- Review: `docs/04-event-job-keda.md`
- Review: `docs/05-parallel-scale-validation.md`
- Review: `docs/06-azure-sample-deployment.md`
- Review: `docs/07-security-limitations-cleanup.md`
- Review: `tests/docs/test-execution-comments.sh`
- Review: `tests/validate-workshop.sh`

**Interfaces:**
- Consumes: All previous task commits.
- Produces: A review-ready branch whose documentation commands are unchanged and whose full validator passes.

- [ ] **Step 1: Run every targeted documentation test in one command**

```bash
bash tests/docs/test-overview.sh &&
bash tests/docs/test-prerequisites-foundation.sh &&
bash tests/docs/test-build-deploy.sh &&
bash tests/docs/test-scale-validation.sh &&
bash tests/docs/test-azure-sample-deployment.sh &&
bash tests/docs/test-security-cleanup.sh &&
bash tests/docs/test-execution-comments.sh
```

Expected: Seven PASS lines and no warnings or failures.

- [ ] **Step 2: Run the integrated validator**

```bash
bash tests/test-validate-workshop.sh
```

Expected: `PASS: integrated workshop validator`.

- [ ] **Step 3: Check whitespace and changed-file scope**

```bash
git diff --check origin/master...HEAD
git diff --stat origin/master...HEAD
git status --short --branch
```

Expected: No whitespace errors; only the six target module documents, the new structural test, the integrated validator, spec, and plan are changed.

- [ ] **Step 4: Confirm Module 02 was not modified**

```bash
git diff --exit-code origin/master...HEAD -- docs/02-azure-foundation.md
```

Expected: Exit code 0 and no output.

- [ ] **Step 5: Inspect all non-comment command-line changes**

Run:

```bash
unexpected_non_comment_changes="$(
  git diff --unified=0 origin/master...HEAD -- \
    docs/01-prerequisites-github.md \
    docs/03-runner-image.md \
    docs/04-event-job-keda.md \
    docs/05-parallel-scale-validation.md \
    docs/06-azure-sample-deployment.md \
    docs/07-security-limitations-cleanup.md |
    grep -E '^[+-][^+-]' |
    grep -Ev '^[+-][[:space:]]*#|^[+-][[:space:]]*$' || true
)"
[[ -z "$unexpected_non_comment_changes" ]] || {
  printf '%s\n' "$unexpected_non_comment_changes" >&2
  exit 1
}
```

Expected: No output. If any line appears, inspect it and restore the original non-comment content before proceeding.

- [ ] **Step 6: Request code review**

Run the repository review workflow against `origin/master...HEAD`, focusing on:

```text
- accidental command, variable, option, KQL, or expected-output changes
- missing logical-group comments
- duplicated or misleading security comments
- broken Markdown fences or details blocks
```

- [ ] **Step 7: Apply only confirmed review fixes and re-run Steps 1-5**

Expected: All tests and diff checks remain clean after any review-driven comment correction.

- [ ] **Step 8: Commit review corrections only if files changed**

```bash
git add docs tests
git commit -m "docs: refine execution comment guidance" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

If review produces no changes, do not create an empty commit.
