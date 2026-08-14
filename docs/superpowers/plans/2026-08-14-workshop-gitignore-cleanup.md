# Workshop Gitignore Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove internal planning documents from participant-facing Git history and precisely ignore local credentials, environment variants, outputs, and editor backups.

**Architecture:** Extend the existing categorized `.gitignore` rather than replacing it, then remove `docs/superpowers/` from the Git index while leaving local ignored copies intact. Strengthen the existing security/cleanup documentation contract so future changes cannot re-track internal planning documents or drop the precise ignore rules.

**Tech Stack:** Git, `.gitignore` pattern syntax, Bash documentation contract tests

## Global Constraints

- Keep `README.md`, Modules 01-06, `docs/images/`, `runner/`, `samples/`, `tests/`, and `.github/workflows/validate-workshop.yml` tracked.
- Remove every tracked file under `docs/superpowers/` from the Git index.
- Keep local `docs/superpowers/` files ignored; do not delete local planning files during index cleanup.
- Add exactly `.env.*`, `!.env.example`, `*.pem`, `*.key`, `*.pfx`, `*.p12`, `*.out`, `*.bak`, `*.swp`, and `*~`.
- Preserve every existing `.gitignore` rule.
- Do not add broad patterns such as `*.json`, `*.yaml`, `*.sh`, or language-wide build templates.
- Do not rewrite workshop module content.

## File Structure

- `.gitignore`: Existing categories plus precise environment, credential, output, and backup patterns.
- `tests/docs/test-security-cleanup.sh`: Contracts for exact ignore lines, representative `git check-ignore` behavior, untracked internal planning docs, and retained core workshop content.
- `docs/superpowers/**`: Removed from the Git index by the implementation commit while local ignored copies remain available in the implementation workspace.

---

### Task 1: Ignore Local Artifacts and Untrack Internal Planning Docs

**Files:**
- Modify: `.gitignore`
- Modify: `tests/docs/test-security-cleanup.sh`
- Remove from Git index: `docs/superpowers/`

**Interfaces:**
- Consumes: Existing categorized ignore rules and the security/cleanup contract test.
- Produces: Precise ignore behavior, no tracked `docs/superpowers/` paths, and unchanged tracking for participant-facing workshop files.

- [ ] **Step 1: Add failing exact-line and behavior contracts**

Append these required ignore-line checks after the current `.gitignore` checks
in `tests/docs/test-security-cleanup.sh`:

```bash
for pattern in \
  '.env.*' \
  '!.env.example' \
  '*.pem' \
  '*.key' \
  '*.pfx' \
  '*.p12' \
  '*.out' \
  '*.bak' \
  '*.swp' \
  '*~'; do
  grep -Fx -- "$pattern" "$IGNORE" >/dev/null ||
    fail ".gitignore missing $pattern"
done
```

Add representative ignore behavior checks:

```bash
for path in \
  '.env.production' \
  'aca-runner.private-key.pem' \
  'runner-signing.key' \
  'runner-identity.pfx' \
  'runner-identity.p12' \
  'autoscale-load.out' \
  'notes.bak' \
  'module.swp' \
  'draft~'; do
  git -C "$ROOT" check-ignore -q "$path" ||
    fail ".gitignore does not ignore $path"
done

if git -C "$ROOT" check-ignore -q '.env.example'; then
  fail ".env.example must remain eligible for tracking"
fi
```

Add tracking-boundary checks:

```bash
if [[ -n "$(git -C "$ROOT" ls-files docs/superpowers)" ]]; then
  fail "internal docs/superpowers files are still tracked"
fi

for path in \
  'README.md' \
  'docs/01-prerequisites-github.md' \
  'docs/06-security-limitations-cleanup.md' \
  'docs/images/02-azure-portal-resource-group-resources.png' \
  'runner/Dockerfile' \
  'runner/entrypoint.sh' \
  'samples/parallel-runner-workflow.yml' \
  'tests/validate-workshop.sh' \
  '.github/workflows/validate-workshop.yml'; do
  git -C "$ROOT" ls-files --error-unmatch "$path" >/dev/null 2>&1 ||
    fail "required workshop file is no longer tracked: $path"
done
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bash tests/docs/test-security-cleanup.sh
```

Expected: FAIL with `.gitignore missing .env.*`.

- [ ] **Step 3: Extend `.gitignore` without removing existing rules**

Change the local configuration and secrets section to:

```gitignore
# Local configuration and secrets
.env
.env.*
!.env.example
*.local
*.pem
*.key
*.pfx
*.p12
```

Change the temporary output section to:

```gitignore
# Temporary output
*.log
*.tmp
*.out
*.bak
*.swp
*~
tests/runner/.fixture-entrypoint/
tests/runner/aca-runner-entrypoint-test.log
```

Keep these existing agent, worktree, editor, and operating-system rules
unchanged:

```gitignore
.worktrees/
.superpowers/
docs/superpowers/
.idea/
.vscode/
.DS_Store
Thumbs.db
```

- [ ] **Step 4: Remove `docs/superpowers/` from the Git index**

Run:

```bash
git rm -r --cached docs/superpowers
```

Verify the index is empty for that path and the approved design file still
exists locally:

```bash
test -z "$(git ls-files docs/superpowers)"
test -f docs/superpowers/specs/2026-08-14-workshop-gitignore-cleanup-design.md
```

Expected: both commands exit 0 with no output.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
bash tests/docs/test-security-cleanup.sh
```

Expected:

```text
PASS: security and cleanup doc
```

- [ ] **Step 6: Verify staged scope before committing**

Run:

```bash
git status --short
git diff --cached --stat
```

Expected:

- `.gitignore` and `tests/docs/test-security-cleanup.sh` are modified.
- Every previously tracked `docs/superpowers/` file is staged as deleted.
- No file under `README.md`, `docs/01-*.md` through `docs/06-*.md`,
  `docs/images/`, `runner/`, `samples/`, `tests/`, or `.github/workflows/`
  is staged as deleted.

- [ ] **Step 7: Commit the cleanup**

```bash
git add .gitignore tests/docs/test-security-cleanup.sh
git commit -m "chore: ignore non-workshop artifacts" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Verify Workshop Tracking and Ignore Boundaries

**Files:**
- Verify: `.gitignore`
- Verify: `tests/docs/test-security-cleanup.sh`
- Verify tracking state for participant-facing files and `docs/superpowers/`

**Interfaces:**
- Consumes: Task 1 cleanup commit.
- Produces: Fresh evidence that internal files are absent from Git history while required workshop content and validation remain intact.

- [ ] **Step 1: Verify representative ignore behavior**

Run:

```bash
for path in \
  '.env.production' \
  'aca-runner.private-key.pem' \
  'runner-signing.key' \
  'runner-identity.pfx' \
  'runner-identity.p12' \
  'autoscale-load.out' \
  'notes.bak' \
  'module.swp' \
  'draft~'; do
  git check-ignore -q "$path"
done

if git check-ignore -q '.env.example'; then
  exit 1
fi
```

Expected: exit code 0 with no output.

- [ ] **Step 2: Verify tracking boundaries**

Run:

```bash
test -z "$(git ls-files docs/superpowers)"

for path in \
  'README.md' \
  'docs/01-prerequisites-github.md' \
  'docs/02-azure-foundation.md' \
  'docs/03-runner-image.md' \
  'docs/04-event-job-keda.md' \
  'docs/05-parallel-scale-validation.md' \
  'docs/06-security-limitations-cleanup.md' \
  'runner/Dockerfile' \
  'samples/parallel-runner-workflow.yml' \
  'tests/validate-workshop.sh' \
  '.github/workflows/validate-workshop.yml'; do
  git ls-files --error-unmatch "$path" >/dev/null
done
```

Expected: exit code 0 with no output.

- [ ] **Step 3: Run complete workshop validation**

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

- [ ] **Step 4: Confirm a clean tracked workspace**

Run:

```bash
git status --short
```

Expected: no output. Local ignored files under `docs/superpowers/` do not
appear in status and require no additional commit.
