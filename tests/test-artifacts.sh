#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$ROOT/runner/Dockerfile"
WORKFLOW="$ROOT/samples/parallel-runner-workflow.yml"
AZURE_DEPLOY_WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"
CI_WORKFLOW="$ROOT/.github/workflows/validate-workshop.yml"

[[ -f "$DOCKERFILE" ]] || { echo "FAIL: runner/Dockerfile missing" >&2; exit 1; }
[[ -f "$WORKFLOW" ]] || { echo "FAIL: workflow sample missing" >&2; exit 1; }
[[ -f "$AZURE_DEPLOY_WORKFLOW" ]] || { echo "FAIL: Azure deploy workflow sample missing" >&2; exit 1; }
[[ -f "$CI_WORKFLOW" ]] || { echo "FAIL: validation workflow missing" >&2; exit 1; }

grep -F 'FROM ghcr.io/actions/actions-runner:2.336.0' "$DOCKERFILE" >/dev/null
for package in ca-certificates curl jq; do
  grep -F -- "$package" "$DOCKERFILE" >/dev/null ||
    { echo "FAIL: runner image missing package $package" >&2; exit 1; }
done

for text in \
  'packages.microsoft.com/keys/microsoft.asc' \
  'packages.microsoft.com/repos/azure-cli/' \
  'apt-get install -y --no-install-recommends azure-cli' \
  'az extension add --name containerapp --upgrade --only-show-errors'; do
  grep -F -- "$text" "$DOCKERFILE" >/dev/null ||
    { echo "FAIL: runner image missing Azure deployment tool: $text" >&2; exit 1; }
done
grep -F 'USER runner' "$DOCKERFILE" >/dev/null
grep -F 'ENTRYPOINT ["/home/runner/entrypoint.sh"]' "$DOCKERFILE" >/dev/null

grep -F 'GITHUB_PAT' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'github_pat="$GITHUB_PAT"' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'unset GITHUB_PAT' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'Authorization' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'GH_URL must match https://github.com/OWNER/REPO' \
  "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F 'https://api.github.com/repos/' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F -- '--connect-timeout 10' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F -- '--max-time 30' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F -- '--no-default-labels' "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F "trap 'forward_signal INT 130' INT" "$ROOT/runner/entrypoint.sh" >/dev/null
grep -F "trap 'forward_signal TERM 143' TERM" "$ROOT/runner/entrypoint.sh" >/dev/null
if grep -E 'GITHUB_APP_|github_app_jwt|INSTALLATION_TOKEN_API_URL|openssl dgst' \
  "$ROOT/runner/entrypoint.sh" >/dev/null; then
  echo "FAIL: runner entrypoint still contains GitHub App authentication" >&2
  exit 1
fi

if grep -F 'openssl' "$DOCKERFILE" >/dev/null; then
  echo "FAIL: runner image still installs OpenSSL for removed App JWT signing" >&2
  exit 1
fi

grep -F 'workflow_dispatch:' "$WORKFLOW" >/dev/null
grep -F 'worker: [1, 2, 3, 4]' "$WORKFLOW" >/dev/null
grep -F 'runs-on: [aca-runner]' "$WORKFLOW" >/dev/null
grep -F 'fail-fast: false' "$WORKFLOW" >/dev/null
grep -F 'sleep 45' "$WORKFLOW" >/dev/null
grep -F 'bash tests/validate-workshop.sh' "$CI_WORKFLOW" >/dev/null

if grep -E '(^|[[:space:]])docker([[:space:]]|$)|services:' "$WORKFLOW" >/dev/null; then
  echo "FAIL: workflow must not depend on Docker" >&2
  exit 1
fi

if grep -F 'runs-on: [self-hosted, linux, x64, aca-runner]' "$WORKFLOW" >/dev/null; then
  echo "FAIL: workflow still depends on default self-hosted runner labels" >&2
  exit 1
fi

bash "$ROOT/tests/docs/test-azure-sample-deployment.sh"

printf 'PASS: runner image and workflow artifacts\n'
