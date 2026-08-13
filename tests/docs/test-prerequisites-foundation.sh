#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ="$ROOT/docs/01-prerequisites-github.md"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"

[[ -f "$PREREQ" ]] || { echo "FAIL: module 01 missing" >&2; exit 1; }
[[ -f "$FOUNDATION" ]] || { echo "FAIL: module 02 missing" >&2; exit 1; }

for text in \
  'Visibility | **Private**' \
  'GitHub Apps' \
  'Webhook | **Inactive**' \
  'Actions | Read-only' \
  'Administration | Read and write' \
  'Metadata | Read-only' \
  'Where can this GitHub App be installed? | **Only on this account**' \
  'Only select repositories' \
  'aca-runner-lab' \
  'GITHUB_APP_ID' \
  'GITHUB_APP_INSTALLATION_ID' \
  'GITHUB_APP_PRIVATE_KEY_PATH' \
  'GITHUB_APP_PRIVATE_KEY="$(<"$GITHUB_APP_PRIVATE_KEY_PATH")"' \
  'openssl dgst -sha256' \
  'printf -v APP_AUTH_HEADER '\''%s: %s %s'\'' '\''Authorization'\'' '\''Bearer'\'' "$APP_JWT"' \
  'printf -v INSTALLATION_AUTH_HEADER '\''%s: %s %s'\''' \
  '/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens' \
  '--header "$APP_AUTH_HEADER"' \
  '--header "$INSTALLATION_AUTH_HEADER"' \
  'X-GitHub-Api-Version: 2026-03-10' \
  'read -rp "Workshop repository URL: " WORKSHOP_REPO_URL' \
  'git clone "$WORKSHOP_REPO_URL" ~/aca-github-runner-workshop' \
  'az extension add --name containerapp --upgrade --only-show-errors' \
  'az provider register -n Microsoft.App --wait' \
  'az provider register -n Microsoft.OperationalInsights --wait' \
  'az provider register -n Microsoft.Insights --wait'; do
  grep -F -- "$text" "$PREREQ" >/dev/null || { echo "FAIL: module 01 missing $text" >&2; exit 1; }
done

if grep -E 'Fine-grained PAT|GITHUB_PAT|personal access token' "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 still documents PAT authentication' >&2
  exit 1
fi

if grep -nE '^[[:space:]]*(printf|echo|cat)\b.*\$GITHUB_APP_PRIVATE_KEY([^[:alnum:]_]|$)' "$PREREQ" | \
  grep -v '\${GITHUB_APP_PRIVATE_KEY:+SET}' >/dev/null; then
  echo 'FAIL: module 01 prints the raw GitHub App private key' >&2
  exit 1
fi

if grep -F '******' "$PREREQ" >/dev/null; then
  echo 'FAIL: module 01 contains six-star placeholder auth text' >&2
  exit 1
fi

for text in \
  'LOC=koreacentral' \
  'az containerapp env create' \
  '--logs-destination azure-monitor' \
  'az monitor diagnostic-settings create' \
  '"categoryGroup":"allLogs"' \
  'az acr create' \
  '--admin-enabled false' \
  'az acr config authentication-as-arm update' \
  'az identity create' \
  '--role AcrPull' \
  '--assignee-principal-type ServicePrincipal'; do
  grep -F -- "$text" "$FOUNDATION" >/dev/null || { echo "FAIL: module 02 missing $text" >&2; exit 1; }
done

printf 'PASS: prerequisites and foundation docs\n'
