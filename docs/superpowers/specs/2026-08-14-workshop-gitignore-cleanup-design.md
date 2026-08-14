# Workshop Gitignore Cleanup Design

## Goal

Keep participant-facing workshop clones focused on executable workshop
content while preventing local credentials and temporary outputs from being
accidentally committed.

## Tracked Content Policy

The following content remains tracked because participants or maintainers use
it directly:

- `README.md`
- `docs/01-prerequisites-github.md` through
  `docs/06-security-limitations-cleanup.md`
- `docs/images/`
- `runner/`
- `samples/`
- `tests/`
- `.github/workflows/validate-workshop.yml`

Internal agent planning and design documents under `docs/superpowers/` are not
part of workshop delivery. All currently tracked files under that directory
will be removed from the Git index. The existing `docs/superpowers/` ignore
rule remains, so local planning files can still exist without appearing in
Git status or future clones.

## Ignore Rules

Keep all existing ignore rules and add these precise patterns:

### Local environment and credentials

```gitignore
.env.*
!.env.example
*.pem
*.key
*.pfx
*.p12
```

`.env.example` remains eligible for tracking if a documented, non-secret
template is added later. Private keys and certificate bundles must never be
tracked.

### Temporary output and editor backups

```gitignore
*.out
*.bak
*.swp
*~
```

Do not add broad patterns such as `*.json`, `*.yaml`, `*.sh`, or entire
language build templates because they could hide valid workshop source files.

## Implementation

1. Extend `.gitignore` in the existing category structure.
2. Remove every currently tracked `docs/superpowers/` file from the Git index
   while leaving the local files ignored.
3. Extend `tests/docs/test-security-cleanup.sh` to assert every new pattern,
   the `.env.example` exception, and an empty
   `git ls-files docs/superpowers` result.
4. Keep all participant-facing documents, tests, runner files, samples, and CI
   workflow tracked.

## Verification

The focused contract test must prove:

- Every new exact ignore line exists.
- `git check-ignore` ignores representative secret and output filenames.
- `git check-ignore` does not ignore `.env.example`.
- `git ls-files docs/superpowers` returns no tracked files.
- Core workshop files remain tracked.

Run the complete workshop validators and shell syntax check after the focused
test passes.

## Non-Goals

- Do not remove tests or the validation workflow from the repository.
- Do not delete local ignored planning files as part of index cleanup.
- Do not add generated files or credentials to demonstrate ignore behavior.
- Do not rewrite workshop module content.
