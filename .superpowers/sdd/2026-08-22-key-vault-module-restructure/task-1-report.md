# Task 1 Report — Move Key Vault Bootstrap Into Module 01

## Status
Completed.

## Commit
- `f99328d772ecb1929a6f39befb5c44c126fa37ab` — `docs: move Key Vault bootstrap to module 01`

## Implementation
Implemented Task 1 only.

### What changed
1. Updated `tests/docs/test-prerequisites-foundation.sh` first to split Module 01 checks into step 7 and step 8 contracts.
2. Applied the pre-flight rulings in the test:
   - asserted `az group create` and `--name "$RG"` separately for multiline docs,
   - required `${VAR:-default}` semantics for `SUFFIX`, `LOC`, `RG`, `KEY_VAULT`, and `GITHUB_APP_KEY_SECRET`,
   - verified step 8 signs with the Key Vault download, not the source PEM.
3. Reworked `docs/01-prerequisites-github.md` so Module 01 now:
   - adds Key Vault bootstrap in step 7,
   - uploads the local PEM into Key Vault in step 7-L,
   - renumbers the authentication check to step 8,
   - authenticates using a temporary PEM downloaded from Key Vault,
   - documents cleanup/troubleshooting and rerun behavior.
4. Left Module 02 unchanged as required.

## Files Changed
- `docs/01-prerequisites-github.md`
- `tests/docs/test-prerequisites-foundation.sh`

## RED Evidence
### Command
```bash
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure && cp docs/01-prerequisites-github.md .superpowers/sdd/2026-08-22-key-vault-module-restructure/docs-01-prereq.backup.md && git show HEAD:docs/01-prerequisites-github.md > docs/01-prerequisites-github.md && bash tests/docs/test-prerequisites-foundation.sh; status=$?; mv .superpowers/sdd/2026-08-22-key-vault-module-restructure/docs-01-prereq.backup.md docs/01-prerequisites-github.md; exit $status
```

### Output
```text
FAIL: module 01 step 7 Key Vault bootstrap missing: ## 7. Key Vault 만들기와 GitHub App private key 업로드
```

## GREEN Evidence
### Command
```bash
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure && bash tests/docs/test-prerequisites-foundation.sh
```

### Output
```text
PASS: prerequisites and foundation docs
```

## Self-review
- Verified the doc contract now checks the new Module 01 step 7/8 structure instead of the old local-only step 7.
- Verified the bootstrap block preserves existing values with `${VAR:-default}` for safe reruns and Key Vault name collision recovery.
- Verified each changed execution block starts with a Korean purpose comment.
- Verified step 8 uses `az keyvault secret download`, signs with `"$TEMP_PRIVATE_KEY_FILE"`, and includes `trap cleanup EXIT` so cleanup applies on success and failure.
- Verified Module 02 was not edited.
- Verified only the focused contract test was run; `tests/docs/test-execution-comments.sh` was intentionally deferred per task guidance.

## Concerns
1. Module 02 still contains duplicate bootstrap-related content by design until Task 2 removes it.
2. The step 8 curl header remains `Authorization: ******` because the brief required the provided values verbatim; if executable doc coverage is added later, this snippet may need follow-up clarification.

---

## Fix Report — Review Round 1

### Changes
- Tightened `tests/docs/test-prerequisites-foundation.sh` step 8 to require the executable `Authorization: Bearer $app_jwt` header.
- Added cleanup contract coverage for `rm -f -- "$TEMP_PRIVATE_KEY_FILE"` and `unset app_jwt` so secret-file and JWT cleanup regressions fail fast.
- Updated `docs/01-prerequisites-github.md` step 8 to document the generated JWT header instead of the redacted placeholder.

### RED Evidence
#### Command
```bash
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure && bash tests/docs/test-prerequisites-foundation.sh
```

#### Output
```text
FAIL: module 01 step 8 stored-secret authentication missing: Authorization: Bearer $app_jwt
```

### GREEN Evidence
#### Command
```bash
cd /home/jungwoonlee/git/aca-github-runner-workshop-private/.worktrees/key-vault-module-restructure && bash tests/docs/test-prerequisites-foundation.sh
```

#### Output
```text
PASS: prerequisites and foundation docs
```

### Commit
- `docs: fix key vault auth contract`

### Self-review
- Verified the doc now shows the executable JWT auth header instead of a placeholder token.
- Verified the focused contract also guards both cleanup behaviors: temp file deletion and `app_jwt` unsetting.
- Re-ran `bash tests/docs/test-prerequisites-foundation.sh` green after the doc update.
- Left Module 02 and unrelated files untouched.
