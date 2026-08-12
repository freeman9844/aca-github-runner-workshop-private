#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/06-security-limitations-cleanup.md"
IGNORE="$ROOT/.gitignore"
[[ -f "$DOC" ]] || { echo "FAIL: module 06 missing" >&2; exit 1; }
[[ -f "$IGNORE" ]] || { echo "FAIL: .gitignore missing" >&2; exit 1; }

for text in \
  'GitHub App' \
  'Azure Key Vault' \
  'VNet' \
  'egress' \
  'organization' \
  'Docker-in-Docker' \
  'public repository' \
  'PAT 만료' \
  'az group delete' \
  '--yes --no-wait' \
  'az group show' \
  'ResourceGroupNotFound'; do
  grep -F -- "$text" "$DOC" >/dev/null || { echo "FAIL: module 06 missing $text" >&2; exit 1; }
done

grep -F '.superpowers/' "$IGNORE" >/dev/null
grep -F '.env' "$IGNORE" >/dev/null
grep -F '*.local' "$IGNORE" >/dev/null

printf 'PASS: security and cleanup doc\n'
