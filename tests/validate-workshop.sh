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

core_workshop_paths=(
  README.md
  docs/01-prerequisites-github.md
  docs/02-azure-foundation.md
  docs/03-runner-image.md
  docs/04-event-job-keda.md
  docs/05-parallel-scale-validation.md
  docs/06-security-limitations-cleanup.md
  runner
  samples
)

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

github_app_configuration_pattern='GITHUB_APP_ID|GITHUB_APP_INSTALLATION_ID|GITHUB_APP_PRIVATE_KEY|applicationID=|installationID=|appKey=|github-app-private-key|/app/installations/|github_app_jwt|openssl dgst'
if grep -RInE "$github_app_configuration_pattern" "${core_workshop_paths[@]}"; then
  echo 'FAIL: GitHub App workshop configuration found' >&2
  exit 1
fi

for text in \
  'GITHUB_PAT' \
  'github_pat="$GITHUB_PAT"' \
  'unset GITHUB_PAT'; do
  grep -F -- "$text" runner/entrypoint.sh >/dev/null || {
    printf 'FAIL: runner entrypoint missing %s\n' "$text" >&2
    exit 1
  }
done

for text in \
  'personalAccessToken=personal-access-token' \
  'personal-access-token=$GITHUB_PAT' \
  'GITHUB_PAT=secretref:personal-access-token'; do
  grep -F -- "$text" docs/04-event-job-keda.md >/dev/null || {
    printf 'FAIL: module 04 missing %s\n' "$text" >&2
    exit 1
  }
done

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
