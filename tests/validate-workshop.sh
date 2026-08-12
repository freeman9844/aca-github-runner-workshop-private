#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n runner/entrypoint.sh
bash tests/runner/test-entrypoint.sh
bash tests/test-artifacts.sh
bash tests/docs/test-overview.sh
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-security-cleanup.sh

required_files=(
  README.md
  runner/Dockerfile
  runner/entrypoint.sh
  samples/parallel-runner-workflow.yml
  docs/01-prerequisites-github.md
  docs/02-azure-foundation.md
  docs/03-runner-image.md
  docs/04-event-job-keda.md
  docs/05-parallel-scale-validation.md
  docs/06-security-limitations-cleanup.md
)

for file in "${required_files[@]}"; do
  [[ -s "$file" ]] || {
    printf 'FAIL: missing or empty %s\n' "$file" >&2
    exit 1
  }
done

placeholder_pattern='T''BD|T''ODO|F''IXME|implement la''ter|fill in deta''ils'
if grep -RInE "$placeholder_pattern" README.md docs runner samples tests; then
  echo 'FAIL: placeholder text found' >&2
  exit 1
fi

secret_pattern='github_''pat_[A-Za-z0-9_]+|g''hp_[A-Za-z0-9]{20,}'
if grep -RInE "$secret_pattern" README.md docs runner samples tests; then
  echo 'FAIL: secret-shaped string found' >&2
  exit 1
fi

navigation_checks=(
  'docs/01-prerequisites-github.md:docs/02-azure-foundation.md'
  'docs/02-azure-foundation.md:docs/01-prerequisites-github.md'
  'docs/02-azure-foundation.md:docs/03-runner-image.md'
  'docs/03-runner-image.md:docs/02-azure-foundation.md'
  'docs/03-runner-image.md:docs/04-event-job-keda.md'
  'docs/04-event-job-keda.md:docs/03-runner-image.md'
  'docs/04-event-job-keda.md:docs/05-parallel-scale-validation.md'
  'docs/05-parallel-scale-validation.md:docs/04-event-job-keda.md'
  'docs/05-parallel-scale-validation.md:docs/06-security-limitations-cleanup.md'
  'docs/06-security-limitations-cleanup.md:docs/05-parallel-scale-validation.md'
)

for check in "${navigation_checks[@]}"; do
  file="${check%%:*}"
  link="${check#*:}"
  grep -F "$(basename "$link")" "$file" >/dev/null || {
    printf 'FAIL: %s does not link to %s\n' "$file" "$link" >&2
    exit 1
  }
done

printf 'PASS: complete workshop validation\n'
