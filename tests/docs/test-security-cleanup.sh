#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/06-security-limitations-cleanup.md"
IGNORE="$ROOT/.gitignore"
[[ -f "$DOC" ]] || { echo "FAIL: module 06 missing" >&2; exit 1; }
[[ -f "$IGNORE" ]] || { echo "FAIL: .gitignore missing" >&2; exit 1; }

for text in \
  'SUFFIX="<your-saved-suffix>"' \
  'RG="rg-acarunner-$SUFFIX"' \
  "starts_with(name, 'rg-acarunner-')" \
  'az group list --query' \
  'suffix를 잃어버렸다면' \
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
  'ResourceGroupNotFound' \
  '| ACA secret의 GitHub App private key | Azure Key Vault 또는 외부 token broker | stronger key isolation and centralized rotation |' \
  '| registration token 방식 | GitHub JIT runner | reduced registration lifecycle exposure |' \
  'GitHub App installation 삭제' \
  'GitHub App private key PEM 삭제' \
  'aca-runner-lab' \
  '## 7. 전체 워크숍 완료 확인'; do
  grep -F -- "$text" "$DOC" >/dev/null || { echo "FAIL: module 06 missing $text" >&2; exit 1; }
done

! grep -F -- '| Fine-grained PAT | GitHub App | higher rate limit and centralized lifecycle |' "$DOC" >/dev/null || { echo "FAIL: module 06 still has old PAT production row" >&2; exit 1; }
! grep -F -- 'PAT 폐기' "$DOC" >/dev/null || { echo "FAIL: module 06 still has PAT cleanup step" >&2; exit 1; }
! grep -F -- '## 8. 전체 워크숍 완료 확인' "$DOC" >/dev/null || { echo "FAIL: module 06 still has old completion section number" >&2; exit 1; }

grep -F '.superpowers/' "$IGNORE" >/dev/null
grep -F 'docs/superpowers/' "$IGNORE" >/dev/null
grep -F '.env' "$IGNORE" >/dev/null
grep -F '*.local' "$IGNORE" >/dev/null

printf 'PASS: security and cleanup doc\n'
