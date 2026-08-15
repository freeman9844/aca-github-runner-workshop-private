# README Participant Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `README.md` a reliable first entry point that distinguishes the workshop and lab repositories, gives a minimal start path, explains session recovery, and defines workshop completion.

**Architecture:** Keep detailed commands and remediation in Modules 01 through 06. Strengthen the README as a participant-facing navigation layer, and encode every new promise in the existing Bash document contract before adding the matching prose.

**Tech Stack:** GitHub-flavored Markdown, Bash contract tests using `grep`, existing workshop validation scripts.

## Global Constraints

- Keep the workshop duration at exactly 90 minutes.
- Keep the architecture diagram topology unchanged.
- Use `aca-github-runner-workshop-private` only as the workshop source repository.
- Use `aca-runner-lab` as the participant-owned private lab repository and Fine-grained PAT scope.
- Clone the source into exactly `~/aca-github-runner-workshop`.
- Keep detailed commands, expected output, and remediation in Modules 01 through 06.
- Preserve the Private repository and Docker-in-Docker warnings.
- Do not change module commands or behavior.
- Do not add fixed Azure price estimates, facilitator-only notes, or another README.
- Keep `docs/superpowers/` ignored and untracked in the final implementation state.

## File Structure

- `README.md`: Participant-facing overview, quick start, repository roles, module journey, recovery guidance, completion criteria, validation scope, and troubleshooting index.
- `tests/docs/test-overview.sh`: Exact contract for the README headings, repository roles, required guidance, completion markers, and rejected obsolete guidance.
- `docs/superpowers/specs/2026-08-15-readme-participant-onboarding-design.md`: Local-only approved design input; remove it from Git tracking without deleting the local file.
- `docs/superpowers/plans/2026-08-15-readme-participant-onboarding.md`: Local-only execution plan; remove it from Git tracking without deleting the local file.

---

### Task 1: Restore Internal Documentation Hygiene

**Files:**
- Untrack: `docs/superpowers/specs/2026-08-15-readme-participant-onboarding-design.md`
- Untrack: `docs/superpowers/plans/2026-08-15-readme-participant-onboarding.md`
- Test: `tests/docs/test-security-cleanup.sh`

**Interfaces:**
- Consumes: Existing `.gitignore` rule `docs/superpowers/`.
- Produces: A clean Git index where `git ls-files docs/superpowers` returns no paths while both local planning files remain available.

- [ ] **Step 1: Run the hygiene contract and confirm the tracked planning files violate it**

Run:

```bash
bash tests/docs/test-security-cleanup.sh
```

Expected: FAIL with `internal docs/superpowers files are still tracked`.

- [ ] **Step 2: Remove only the approved design and plan from Git tracking**

Run:

```bash
git rm --cached -- \
  docs/superpowers/specs/2026-08-15-readme-participant-onboarding-design.md \
  docs/superpowers/plans/2026-08-15-readme-participant-onboarding.md
```

Expected: Both paths are staged as deleted, but still exist locally because `git rm --cached` does not delete working-tree files.

- [ ] **Step 3: Verify the local inputs remain present and the Git index is clean**

Run:

```bash
test -f docs/superpowers/specs/2026-08-15-readme-participant-onboarding-design.md
test -f docs/superpowers/plans/2026-08-15-readme-participant-onboarding.md
test -z "$(git ls-files docs/superpowers)"
bash tests/docs/test-security-cleanup.sh
```

Expected: Both `test -f` checks succeed, `git ls-files` is empty, and the contract prints `PASS: security and cleanup doc`.

- [ ] **Step 4: Commit the repository hygiene restoration**

```bash
git add -u docs/superpowers
git commit -m "chore: keep internal planning docs untracked"
```

---

### Task 2: Add Participant Start and Recovery Guidance

**Files:**
- Modify: `tests/docs/test-overview.sh:8-60`
- Modify: `README.md:1-94`
- Test: `tests/docs/test-overview.sh`

**Interfaces:**
- Consumes: Module 01 clone path and PAT setup; Modules 03 through 06 optional Step 0 recovery headings.
- Produces: README headings `## 빠른 시작`, `## 두 GitHub 저장소 구분`, and `## 세션이 끊겼을 때`, plus exact repository-role and recovery guidance used by Task 3.

- [ ] **Step 1: Extend the README contract with the new onboarding headings**

In `tests/docs/test-overview.sh`, add the new headings to the existing `for heading in` list:

```bash
  '## 빠른 시작' \
  '## 두 GitHub 저장소 구분' \
  '## 세션이 끊겼을 때' \
```

Place `## 빠른 시작` and `## 두 GitHub 저장소 구분` before `## 아키텍처`, and place `## 세션이 끊겼을 때` after `## 모듈 목차`.

- [ ] **Step 2: Add exact start, repository-role, module-output, and recovery assertions**

Add this block after the existing module-link loop:

```bash
for text in \
  'git clone https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop' \
  'cd ~/aca-github-runner-workshop' \
  '| `aca-github-runner-workshop-private` | 워크숍 문서, runner source, samples, tests | 워크숍 운영자 | source clone, 문서 확인, runner image 빌드 |' \
  '| `aca-runner-lab` | 참가자 소유 Private lab repository | 참가자(Module 01) | workflow queue, KEDA 감시, ephemeral runner 등록 |' \
  'Fine-grained PAT는 워크숍 소스 저장소가 아니라 `aca-runner-lab`에만 scope합니다.' \
  '| 워크숍 source HTTPS 인증 | Private workshop source repository를 HTTPS로 clone할 수 있어야 합니다. |' \
  '| Lab repository | 참가자 소유 Private `aca-runner-lab` repository를 만들거나 사용할 수 있어야 합니다. |' \
  'Enterprise Managed User 또는 organization 정책에 따라 Fine-grained PAT 승인이 필요할 수 있습니다.' \
  'private lab repository, 검증된 GitHub 변수와 Fine-grained PAT' \
  '저장한 `SUFFIX`, 실제 `ACR` 이름, Azure resource ID' \
  'ACR에 빌드된 runner image' \
  'repository-scoped ACA Event Job과 KEDA rule' \
  'matrix 4개 Job과 `0 → N → 0` 증거' \
  '보안 검토와 확인된 cleanup' \
  'Cloud Shell의 shell 변수는 새 세션에 유지되지 않습니다.' \
  '원래 `SUFFIX`와 실제 `ACR` 이름' \
  '`0. 세션 재연결 시 변수 복구 (선택)`' \
  '새 suffix를 만들지 마세요.'; do
  grep -F -- "$text" "$README" >/dev/null ||
    { echo "FAIL: README missing participant guidance: $text" >&2; exit 1; }
done
```

Add these negative assertions before the final PASS message:

```bash
if grep -E 'git clone .* ~/aca-github-runner-workshop-private([[:space:]]|$)' \
  "$README" >/dev/null; then
  echo 'FAIL: README clones into the repository-name directory instead of the workshop path' >&2
  exit 1
fi

if grep -F 'Fine-grained PAT는 `aca-github-runner-workshop-private`' \
  "$README" >/dev/null; then
  echo 'FAIL: README scopes the lab PAT to the workshop source repository' >&2
  exit 1
fi
```

Replace the existing Module 01 row assertion:

```bash
grep -F '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | Cloud Shell 변수, `Private repository`, Fine-grained PAT 준비 | 15분 |' "$README" >/dev/null
```

with:

```bash
grep -F '| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | private lab repository, 검증된 GitHub 변수와 Fine-grained PAT | 15분 |' "$README" >/dev/null
```

- [ ] **Step 3: Run the focused contract and confirm the onboarding requirements fail**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: FAIL first on `missing ## 빠른 시작`.

- [ ] **Step 4: Add the quick start and repository-role sections**

In `README.md`, after the opening description and horizontal rule, add:

````markdown
## 빠른 시작

1. Azure Portal에서 **Cloud Shell Bash**를 엽니다.
2. Private workshop source repository를 HTTPS로 clone할 수 있는 Git 인증 상태인지 확인합니다.
3. 다음 명령으로 워크숍 source를 고정 경로에 clone합니다.

```bash
git clone https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop
cd ~/aca-github-runner-workshop
```

4. [Module 01: GitHub 사전 준비](docs/01-prerequisites-github.md)를 열고 Module 06까지 순서대로 진행합니다.

상세 변수 설정, 예상 출력, 오류 해결 명령은 각 모듈에서 안내합니다.

---

## 두 GitHub 저장소 구분

| Repository | 역할 | 생성 주체 | 사용 위치 |
|---|---|---|---|
| `aca-github-runner-workshop-private` | 워크숍 문서, runner source, samples, tests | 워크숍 운영자 | source clone, 문서 확인, runner image 빌드 |
| `aca-runner-lab` | 참가자 소유 Private lab repository | 참가자(Module 01) | workflow queue, KEDA 감시, ephemeral runner 등록 |

Fine-grained PAT는 워크숍 소스 저장소가 아니라 `aca-runner-lab`에만 scope합니다.

---
````

- [ ] **Step 5: Strengthen the prerequisite table without changing the existing warnings**

Add these rows to `## 사전 요구사항`:

```markdown
| 워크숍 source HTTPS 인증 | Private workshop source repository를 HTTPS로 clone할 수 있어야 합니다. |
| Lab repository | 참가자 소유 Private `aca-runner-lab` repository를 만들거나 사용할 수 있어야 합니다. |
```

After the table, before the existing warning block, add:

```markdown
> Enterprise Managed User 또는 organization 정책에 따라 Fine-grained PAT 승인이 필요할 수 있습니다. Azure 리소스 생성 권한과 `Microsoft.Authorization/roleAssignments/write` 권한은 별도 요구사항입니다.
```

Keep the existing `Private repository` and `Docker-in-Docker` warning text unchanged.

- [ ] **Step 6: Replace the module summaries with outputs passed to the next module**

Use these exact `한 줄 설명` cells while preserving every current time:

```markdown
| 01 | [GitHub 사전 준비](docs/01-prerequisites-github.md) | private lab repository, 검증된 GitHub 변수와 Fine-grained PAT | 15분 |
| 02 | [Azure 기반 리소스 준비](docs/02-azure-foundation.md) | 저장한 `SUFFIX`, 실제 `ACR` 이름, Azure resource ID | 15분 |
| 03 | [Runner image 빌드](docs/03-runner-image.md) | ACR에 빌드된 runner image | 10분 |
| 04 | [Event Job + KEDA 구성](docs/04-event-job-keda.md) | repository-scoped ACA Event Job과 KEDA rule | 15분 |
| 05 | [병렬 실행과 스케일 검증](docs/05-parallel-scale-validation.md) | matrix 4개 Job과 `0 → N → 0` 증거 | 20분 |
| 06 | [보안·제약·정리](docs/06-security-limitations-cleanup.md) | 보안 검토와 확인된 cleanup | 10분 |
```

- [ ] **Step 7: Add session recovery after the module table**

Before `## 시간표`, add:

```markdown
## 세션이 끊겼을 때

Cloud Shell의 shell 변수는 새 세션에 유지되지 않습니다. 기존 리소스로 계속 진행하려면 원래 `SUFFIX`와 실제 `ACR` 이름을 보관해야 합니다.

Modules 03~06에는 `0. 세션 재연결 시 변수 복구 (선택)` 영역이 있습니다. 복구가 필요할 때만 접힌 상세 내용을 펼쳐 명령을 실행하세요. 기존 실습을 이어갈 때는 새 suffix를 만들지 마세요. 새 이름은 이미 만든 리소스와 연결되지 않습니다.

---
```

- [ ] **Step 8: Run the focused contract and confirm the onboarding work passes**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: PASS with `PASS: README contract`.

- [ ] **Step 9: Commit the participant start and recovery guidance**

```bash
git add README.md tests/docs/test-overview.sh
git commit -m "docs: improve participant README onboarding"
```

---

### Task 3: Add Completion, Validation Scope, and Troubleshooting Guidance

**Files:**
- Modify: `tests/docs/test-overview.sh:8-100`
- Modify: `README.md:90-180`
- Test: `tests/docs/test-overview.sh`
- Test: `tests/validate-workshop.sh`
- Test: `tests/test-validate-workshop.sh`
- Test: `runner/entrypoint.sh`

**Interfaces:**
- Consumes: Repository roles and recovery sections from Task 2; existing module troubleshooting anchors.
- Produces: README heading `## 완료 기준`, participant-facing validation scope, expanded troubleshooting index, and final green workshop validation.

- [ ] **Step 1: Require the completion heading and completion markers**

Add `## 완료 기준` to the heading loop after `## 세션이 끊겼을 때`.

Add this assertion block after the Task 2 participant-guidance block:

```bash
for text in \
  'ACR에 runner image tag가 존재합니다.' \
  '예상한 image와 repository-scoped KEDA rule' \
  'matrix 4개 Job이 모두 성공합니다.' \
  'active execution이 `0 → N → 0`으로 돌아옵니다.' \
  'runner lifecycle marker가 CLI 또는 Log Analytics에 나타납니다.' \
  'permanent online ephemeral runner가 남지 않습니다.' \
  '`ResourceGroupNotFound`' \
  'lab Fine-grained PAT와 GitHub lab artifact' \
  '검증된 범위와 남은 전제' \
  '체크인된 자동 검증은 README/문서 계약과 스크립트 인터페이스를 확인합니다.' \
  'Fine-grained PAT의 organization 승인과 최소 권한 동작은 참가자의 GitHub enterprise/organization 정책에 따라 달라집니다.'; do
  grep -F -- "$text" "$README" >/dev/null ||
    { echo "FAIL: README missing completion or validation guidance: $text" >&2; exit 1; }
done
```

- [ ] **Step 2: Require every new troubleshooting route**

Add:

```bash
for text in \
  '| workshop source clone 인증 실패 또는 잘못된 clone 경로 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |' \
  '| Fine-grained PAT가 비어 있거나 만료·미승인 상태이거나 GitHub API가 401/403을 반환함 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |' \
  '| ACR 이름이 이미 사용 중임 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |' \
  '| 동일 repository와 label을 감시하는 Event Job이 이미 있음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |' \
  '| Event Job secret 또는 PAT 오류 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |' \
  '| CLI 또는 Log Analytics에서 runner 로그를 찾을 수 없음 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |'; do
  grep -F -- "$text" "$README" >/dev/null ||
    { echo "FAIL: README missing troubleshooting route: $text" >&2; exit 1; }
done
```

Replace the existing two-file troubleshooting anchor loop with all linked modules:

```bash
for troubleshooting_doc in \
  "$ROOT/docs/01-prerequisites-github.md" \
  "$ROOT/docs/02-azure-foundation.md" \
  "$ROOT/docs/03-runner-image.md" \
  "$ROOT/docs/04-event-job-keda.md" \
  "$ROOT/docs/05-parallel-scale-validation.md" \
  "$ROOT/docs/06-security-limitations-cleanup.md"; do
  grep -Fx '## 트러블슈팅' "$troubleshooting_doc" >/dev/null ||
    { echo "FAIL: $(basename "$troubleshooting_doc") must expose #트러블슈팅" >&2; exit 1; }
done
```

- [ ] **Step 3: Replace obsolete validation assertions with rejection checks**

Remove these old positive assertions:

```bash
grep -F '기존 GitHub OAuth credential' "$README" >/dev/null
grep -F 'Fine-grained PAT의 최소권한·승인 경로는 아직 별도로 검증하지 않았습니다.' "$README" >/dev/null
```

Add:

```bash
for obsolete in \
  '기존 GitHub OAuth credential' \
  'GitHub App 생성 권한' \
  'GitHub App 설치' \
  'GitHub App private key'; do
  if grep -F -- "$obsolete" "$README" >/dev/null; then
    echo "FAIL: README contains obsolete authentication guidance: $obsolete" >&2
    exit 1
  fi
done
```

Keep the existing assertions for `koreacentral`, `2.336.0`, matrix jobs, image pull, scaling, runner shutdown, Log Analytics, and resource-group deletion.

- [ ] **Step 4: Run the focused contract and confirm completion guidance fails**

Run:

```bash
bash tests/docs/test-overview.sh
```

Expected: FAIL first on `missing ## 완료 기준`.

- [ ] **Step 5: Add the participant completion checklist**

After `## 세션이 끊겼을 때` and before `## 시간표`, add:

```markdown
## 완료 기준

- [ ] ACR에 runner image tag가 존재합니다.
- [ ] ACA Event Job이 예상한 image와 repository-scoped KEDA rule을 사용합니다.
- [ ] matrix 4개 Job이 모두 성공합니다.
- [ ] active execution이 `0 → N → 0`으로 돌아옵니다.
- [ ] runner lifecycle marker가 CLI 또는 Log Analytics에 나타납니다.
- [ ] GitHub에 permanent online ephemeral runner가 남지 않습니다.
- [ ] Azure cleanup 후 조회 결과가 `ResourceGroupNotFound`에 도달합니다.
- [ ] 안내에 따라 lab Fine-grained PAT와 GitHub lab artifact를 정리합니다.

---
```

- [ ] **Step 6: Replace the old validation paragraph with participant-facing scope**

In `## 시간표`, replace the current `검증 범위 안내` block with:

```markdown
> ✅ **검증된 범위와 남은 전제** — 체크인된 자동 검증은 README/문서 계약과 스크립트 인터페이스를 확인합니다.
> 라이브 Azure/GitHub 실행에서 `koreacentral`, runner `2.336.0`, matrix 4개 Job,
> 이미지 pull, KEDA `0 → 4 → 0` 확장, ephemeral runner 종료, Log Analytics 수집,
> 리소스 그룹 삭제를 확인했습니다. Fine-grained PAT의 organization 승인과 최소 권한 동작은
> 참가자의 GitHub enterprise/organization 정책에 따라 달라집니다.
```

- [ ] **Step 7: Expand the troubleshooting index while retaining existing routes**

Add these rows to `## 트러블슈팅 색인`:

```markdown
| workshop source clone 인증 실패 또는 잘못된 clone 경로 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| Fine-grained PAT가 비어 있거나 만료·미승인 상태이거나 GitHub API가 401/403을 반환함 | [docs/01-prerequisites-github.md#트러블슈팅](docs/01-prerequisites-github.md#트러블슈팅) |
| ACR 이름이 이미 사용 중임 | [docs/02-azure-foundation.md#트러블슈팅](docs/02-azure-foundation.md#트러블슈팅) |
| 동일 repository와 label을 감시하는 Event Job이 이미 있음 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| Event Job secret 또는 PAT 오류 | [docs/04-event-job-keda.md#트러블슈팅](docs/04-event-job-keda.md#트러블슈팅) |
| CLI 또는 Log Analytics에서 runner 로그를 찾을 수 없음 | [docs/05-parallel-scale-validation.md#트러블슈팅](docs/05-parallel-scale-validation.md#트러블슈팅) |
```

Keep the current queued workflow, image pull, missing execution, timeout, Docker limitation, runner cleanup, and Azure deletion rows.

- [ ] **Step 8: Run the focused and complete validation commands**

Run:

```bash
bash tests/docs/test-overview.sh
bash tests/validate-workshop.sh
bash tests/test-validate-workshop.sh
bash -n runner/entrypoint.sh
git diff --check
test -z "$(git ls-files docs/superpowers)"
```

Expected:

```text
PASS: README contract
PASS: complete workshop validation
PASS: integrated workshop validator
```

The syntax, whitespace, and tracking checks produce no output and exit successfully.

- [ ] **Step 9: Commit the completed README contract**

```bash
git add README.md tests/docs/test-overview.sh
git commit -m "docs: define workshop completion and support paths"
```
