#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n runner/entrypoint.sh
bash tests/runner/test-dockerfile.sh
bash tests/runner/test-entrypoint.sh
bash tests/test-artifacts.sh
bash tests/docs/test-overview.sh
bash tests/docs/test-prerequisites-foundation.sh
bash tests/docs/test-build-deploy.sh
bash tests/docs/test-scale-validation.sh
bash tests/docs/test-azure-sample-deployment.sh
bash tests/docs/test-security-cleanup.sh
bash tests/docs/test-execution-comments.sh

core_workshop_paths=(
  README.md
  docs/01-prerequisites-github.md
  docs/02-azure-foundation.md
  docs/03-runner-image.md
  docs/04-event-job-keda.md
  docs/05-parallel-scale-validation.md
  docs/06-azure-sample-deployment.md
  docs/07-security-limitations-cleanup.md
  runner
  samples/azure-sample-deploy-workflow.yml
  samples
)

required_files=(
  README.md
  runner/Dockerfile
  runner/entrypoint.sh
  samples/parallel-runner-workflow.yml
  samples/azure-sample-deploy-workflow.yml
  docs/01-prerequisites-github.md
  docs/02-azure-foundation.md
  docs/03-runner-image.md
  docs/04-event-job-keda.md
  docs/05-parallel-scale-validation.md
  docs/06-azure-sample-deployment.md
  docs/07-security-limitations-cleanup.md
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

# Reject PAT operational patterns in core workshop paths.
# Prose that explains PAT is not used (e.g. "PAT를 사용하지 않습니다") is permitted.
pat_operational_pattern='GITHUB_PAT|personalAccessToken=|personal-access-token=|secretref:personal-access-token|Fine-grained personal access token'
if grep -RInE "$pat_operational_pattern" "${core_workshop_paths[@]}"; then
  echo 'FAIL: PAT operational pattern found in workshop paths' >&2
  exit 1
fi

for text in \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY' \
  '/app/installations/' \
  'applicationID=' \
  'installationID=' \
  'appKey=github-app-private-key' \
  'github-app-private-key=keyvaultref:' \
  'privatelink.vaultcore.azure.net'; do
  grep -RF -- "$text" "${core_workshop_paths[@]}" >/dev/null || {
    printf 'FAIL: missing GitHub App configuration: %s\n' "$text" >&2
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
  'docs/05-parallel-scale-validation.md:docs/06-azure-sample-deployment.md'
  'docs/06-azure-sample-deployment.md:docs/05-parallel-scale-validation.md'
  'docs/06-azure-sample-deployment.md:docs/07-security-limitations-cleanup.md'
  'docs/07-security-limitations-cleanup.md:docs/06-azure-sample-deployment.md'
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
