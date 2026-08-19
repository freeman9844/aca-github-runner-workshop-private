#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/samples/azure-sample-deploy-workflow.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$WORKFLOW" ]] || fail "Azure sample deployment workflow missing"

for text in \
  'name: ACA Runner Azure Sample Deploy' \
  'workflow_dispatch:' \
  'runs-on: [aca-runner]' \
  'timeout-minutes: 15' \
  'set -euo pipefail' \
  'az login --identity --client-id "$AZURE_CLIENT_ID"' \
  'az account set --subscription "$AZURE_SUBSCRIPTION_ID"' \
  'az containerapp create' \
  'az containerapp delete' \
  '--image mcr.microsoft.com/k8se/quickstart:latest' \
  '--environment "$AZURE_CONTAINERAPPS_ENVIRONMENT"' \
  '--resource-group "$AZURE_RESOURCE_GROUP"' \
  '--name "$AZURE_SAMPLE_APP"' \
  '--ingress external' \
  '--target-port 80' \
  '--min-replicas 0' \
  '--max-replicas 1' \
  'APP_URL="https://$FQDN"' \
  '>> "$GITHUB_ENV"' \
  'curl --fail --silent --show-error "$APP_URL"' \
  'HTTP verification failed after'; do
  grep -F -- "$text" "$WORKFLOW" >/dev/null ||
    fail "workflow missing $text"
done

[[ "$(grep -Fc 'runs-on:' "$WORKFLOW")" -eq 1 ]] ||
  fail "deployment workflow must contain exactly one job"

if grep -E 'azure/login|AZURE_CREDENTIALS|client-secret|(^|[[:space:]])docker([[:space:]]|$)|services:' \
  "$WORKFLOW" >/dev/null; then
  fail "workflow contains a forbidden credential or Docker dependency"
fi

printf 'PASS: Azure sample deployment workflow\n'
