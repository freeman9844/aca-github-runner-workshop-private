#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DOC="$ROOT/docs/03-runner-image.md"
JOB_DOC="$ROOT/docs/04-event-job-keda.md"
[[ -f "$IMAGE_DOC" ]] || { echo "FAIL: module 03 missing" >&2; exit 1; }
[[ -f "$JOB_DOC" ]] || { echo "FAIL: module 04 missing" >&2; exit 1; }

for text in \
  'bash -n runner/entrypoint.sh' \
  'bash tests/runner/test-entrypoint.sh' \
  'az acr build' \
  '--image "$IMAGE"' \
  './runner' \
  'ghcr.io/actions/actions-runner:2.336.0' \
  'openssl' \
  'App credentials are removed from the environment before the workflow runner starts.'; do
  grep -F -- "$text" "$IMAGE_DOC" >/dev/null || { echo "FAIL: module 03 missing $text" >&2; exit 1; }
done

for text in \
  'JOB_CREATE_ARGS=(' \
  '# queue가 비어 있으면 execution을 0개로 유지합니다.' \
  'az containerapp job create "${JOB_CREATE_ARGS[@]}"' \
  '--trigger-type Event' \
  '--container-name github-actions-runner' \
  '--replica-timeout 900' \
  '--replica-retry-limit 0' \
  '--replica-completion-count 1' \
  '--parallelism 1' \
  '--min-executions 0' \
  '--max-executions 5' \
  '--polling-interval 30' \
  '--scale-rule-type github-runner' \
  'githubApiURL=https://api.github.com' \
  'runnerScope=repo' \
  'labels=aca-runner' \
  'targetWorkflowQueueLength=1' \
  'applicationID=$GITHUB_APP_ID' \
  'installationID=$GITHUB_APP_INSTALLATION_ID' \
  'appKey=github-app-private-key' \
  'github-app-private-key=$GITHUB_APP_PRIVATE_KEY' \
  'GITHUB_APP_ID=$GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY=secretref:github-app-private-key' \
  'RUNNER_LABELS=aca-runner' \
  'RUNNER_NAME_PREFIX=aca' \
  '--mi-user-assigned "$UAMI_RID"' \
  '--registry-identity "$UAMI_RID"' \
  'read -rp "GitHub App ID: " GITHUB_APP_ID' \
  'read -rp "GitHub App installation ID: " GITHUB_APP_INSTALLATION_ID' \
  'read -rp "GitHub App private key PEM path: " GITHUB_APP_PRIVATE_KEY_PATH' \
  '[[ -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]] || {' \
  'GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"' \
  'export GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY' \
  '--scale-rule-auth "appKey=github-app-private-key"' \
  '--secrets "github-app-private-key=$GITHUB_APP_PRIVATE_KEY"' \
  'unset JOB_CREATE_ARGS GITHUB_APP_PRIVATE_KEY' \
  'az containerapp job show --name "$JOB" --resource-group "$RG" --output none' \
  'az containerapp job delete \' \
  'Do not instruct participants to recreate the whole resource group for a Job configuration error.'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

if grep -F -- '## 4. 파라미터 의미 빠르게 읽기' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 keeps parameter explanations in a separate table" >&2
  exit 1
fi

if grep -F -- 'githubAPIURL=' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 uses invalid KEDA metadata key githubAPIURL" >&2
  exit 1
fi

for text in \
  'GITHUB_PAT' \
  'personalAccessToken' \
  'personal-access-token'; do
  if grep -F -- "$text" "$JOB_DOC" >/dev/null; then
    echo "FAIL: module 04 still references $text" >&2
    exit 1
  fi
done

for text in \
  '--cpu 2.0' \
  '--memory 4Gi'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

printf 'PASS: image build and Event Job docs\n'
