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
  'Azure Key Vault' \
  'VNet' \
  'egress' \
  'organization' \
  'Docker-in-Docker' \
  'public repository' \
  'az group delete' \
  '--yes --no-wait' \
  '리소스 그룹 삭제 요청됨: rg-acarunner-a1b2c3' \
  'az group show' \
  'properties.provisioningState' \
  'az resource list' \
  'ACA managed environment 삭제는 오래 걸릴 수 있습니다.' \
  'ResourceGroupNotFound' \
  "Resource group 'rg-acarunner-a1b2c3' could not be found." \
  'aca-runner-lab'; do
  grep -F -- "$text" "$DOC" >/dev/null || { echo "FAIL: module 06 missing $text" >&2; exit 1; }
done

if grep -Fx '## 7. 전체 워크숍 완료 확인' "$DOC" >/dev/null; then
  echo "FAIL: module 06 still has a redundant workshop completion summary" >&2
  exit 1
fi

for text in \
  'Fine-grained PAT' \
  'Actions: Read-only' \
  'Administration: Read and write' \
  'Metadata: Read-only' \
  'Only select repositories' \
  '30 days' \
  'PAT rotation' \
  'ACA secret을 새 PAT로 먼저 갱신' \
  '기존 PAT를 revoke' \
  'PAT 삭제' \
  'Azure Key Vault' \
  'external token broker'; do
  grep -F -- "$text" "$DOC" >/dev/null ||
    { echo "FAIL: module 06 missing $text" >&2; exit 1; }
done

if grep -E 'GitHub App|GITHUB_APP_|App ID/installation ID|private key PEM' \
  "$DOC" >/dev/null; then
  echo "FAIL: module 06 still contains GitHub App cleanup" >&2
  exit 1
fi

! grep -F -- '| Fine-grained PAT | GitHub App | higher rate limit and centralized lifecycle |' "$DOC" >/dev/null || { echo "FAIL: module 06 still has old PAT production row" >&2; exit 1; }
! grep -F -- 'PAT 폐기' "$DOC" >/dev/null || { echo "FAIL: module 06 still has PAT cleanup step" >&2; exit 1; }
! grep -F -- 'PAT 만료' "$DOC" >/dev/null || { echo "FAIL: module 06 still has PAT troubleshooting guidance" >&2; exit 1; }
! grep -F -- '## 8. 전체 워크숍 완료 확인' "$DOC" >/dev/null || { echo "FAIL: module 06 still has old completion section number" >&2; exit 1; }
! grep -nE 'rg-acarunner-[0-9a-f]{5}\b' "$DOC" >/dev/null || { echo "FAIL: module 06 regressed to a five-character suffix example" >&2; exit 1; }

grep -F '.superpowers/' "$IGNORE" >/dev/null
grep -F 'docs/superpowers/' "$IGNORE" >/dev/null
grep -F '.env' "$IGNORE" >/dev/null
grep -F '*.local' "$IGNORE" >/dev/null

printf 'PASS: security and cleanup doc\n'
