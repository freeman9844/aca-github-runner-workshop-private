#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/07-security-limitations-cleanup.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message: $needle"
}

[[ -f "$DOC" ]] || fail "module 07 missing"

DOC_TEXT="$(<"$DOC")"

for text in \
  'GitHub App' \
  'Key Vault' \
  'Key Vault Secrets User' \
  'trusted workflow authors' \
  'fork pull request' \
  'token broker' \
  '새 GitHub App private key' \
  '새 Key Vault secret version' \
  '기존 GitHub App private key' \
  'az containerapp job delete' \
  'GitHub App installation' \
  'workshop 전용 GitHub App' \
  'public network access' \
  'ResourceGroupNotFound'; do
  assert_contains "$DOC_TEXT" "$text" 'module 07 missing cleanup marker'
done

for obsolete in \
  'PAT rotation' \
  'Fine-grained PAT' \
  'unset GITHUB_PAT' \
  'PAT를 revoke'; do
  if grep -F -- "$obsolete" "$DOC" >/dev/null; then
    fail "module 07 still uses obsolete PAT guidance: $obsolete"
  fi
done

python3 - "$DOC" <<'PY'
from pathlib import Path
import sys

doc = Path(sys.argv[1]).read_text(encoding="utf-8")

def must_appear_in_order(*phrases: str) -> None:
    start = 0
    for phrase in phrases:
        index = doc.find(phrase, start)
        if index == -1:
            raise SystemExit(f"FAIL: module 07 missing ordered phrase: {phrase}")
        start = index + len(phrase)

must_appear_in_order(
    "새 GitHub App private key",
    "Key Vault Secrets Officer",
    "public network access",
    "새 Key Vault secret version",
    "App JWT",
    "installation token",
    "exact new version URI",
    "successful KEDA/runner execution",
    "remove the IP rule",
    "기존 GitHub App private key",
    "unversioned URI",
    "local PEM file",
)

must_appear_in_order(
    "az containerapp job delete",
    "online/busy/stale runner",
    "GitHub App installation",
    "workshop 전용 GitHub App",
    "Azure resource group",
    "ResourceGroupNotFound",
    'az keyvault purge --name "$KEY_VAULT" --location "$LOC"',
    "local PEM",
)
PY

printf 'PASS: security cleanup doc\n'
