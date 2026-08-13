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
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved ACR name: " ACR' \
  'SUFFIX=a1b2c3 ACR=acracarunnera1b2c3 IMAGE=github-actions-runner:2.336.0' \
  'ca-certificates`, `curl`, `jq`' \
  'Fine-grained PAT' \
  'GITHUB_PAT' \
  'non-exported wrapper-shell variable' \
  'unset' \
  'workflow process cannot inherit the PAT'; do
  grep -F -- "$text" "$IMAGE_DOC" >/dev/null || { echo "FAIL: module 03 missing $text" >&2; exit 1; }
done

if grep -E 'GitHub App|GITHUB_APP_|installation token|openssl' \
  "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 still describes GitHub App bootstrap" >&2
  exit 1
fi

if grep -F -- 'ACR="acracarunner$SUFFIX"' "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 reconstructs ACR from SUFFIX instead of reading the saved actual ACR name" >&2
  exit 1
fi

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
  'JOB=job-ghrunner-a1b2c3 ENV=env-acarunner-a1b2c3 ACR_SERVER=acracarunnera1b2c3.azurecr.io' \
  'read -rp "Saved SUFFIX: " SUFFIX' \
  'read -rp "Saved ACR name: " ACR' \
  'RUNNER_LABELS=aca-runner' \
  'RUNNER_NAME_PREFIX=aca' \
  '--mi-user-assigned "$UAMI_RID"' \
  '--registry-identity "$UAMI_RID"' \
  'read -rsp "Fine-grained PAT: " GITHUB_PAT' \
  'personalAccessToken=personal-access-token' \
  'personal-access-token=$GITHUB_PAT' \
  'GITHUB_PAT=secretref:personal-access-token' \
  'unset JOB_CREATE_ARGS GITHUB_PAT' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only' \
  'az containerapp job show --name "$JOB" --resource-group "$RG" --output none' \
  'az containerapp job delete \' \
  'Do not instruct participants to recreate the whole resource group for a Job configuration error.'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

if grep -E 'GITHUB_APP_|applicationID=|installationID=|appKey=|github-app-private-key|PEM' \
  "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 still contains GitHub App configuration" >&2
  exit 1
fi

if grep -nE 'SUFFIX=[0-9a-f]{5}\b|acracarunner[0-9a-f]{5}\b' "$IMAGE_DOC" >/dev/null; then
  echo "FAIL: module 03 regressed to a five-character suffix example" >&2
  exit 1
fi

if grep -nE 'job-ghrunner-[0-9a-f]{5}\b|env-acarunner-[0-9a-f]{5}\b|acracarunner[0-9a-f]{5}\.azurecr\.io\b' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 regressed to a five-character suffix example" >&2
  exit 1
fi

if grep -F -- 'ACR="acracarunner$SUFFIX"' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 reconstructs ACR from SUFFIX instead of reading the saved actual ACR name" >&2
  exit 1
fi

if grep -F -- '## 4. 파라미터 의미 빠르게 읽기' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 keeps parameter explanations in a separate table" >&2
  exit 1
fi

if grep -F -- 'githubAPIURL=' "$JOB_DOC" >/dev/null; then
  echo "FAIL: module 04 uses invalid KEDA metadata key githubAPIURL" >&2
  exit 1
fi

for text in \
  '--cpu 2.0' \
  '--memory 4Gi'; do
  grep -F -- "$text" "$JOB_DOC" >/dev/null || { echo "FAIL: module 04 missing $text" >&2; exit 1; }
done

printf 'PASS: image build and Event Job docs\n'
