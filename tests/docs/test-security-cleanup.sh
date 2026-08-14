#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/06-security-limitations-cleanup.md"
IGNORE="$ROOT/.gitignore"
[[ -f "$DOC" ]] || { echo "FAIL: module 06 missing" >&2; exit 1; }
[[ -f "$IGNORE" ]] || { echo "FAIL: .gitignore missing" >&2; exit 1; }

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -Fx '## 0. 세션 재연결 시 변수 복구 (선택)' "$DOC" >/dev/null ||
  fail "module 06 missing optional Step 0 recovery heading"
details_open_line="$(grep -nF -m1 '<details>' "$DOC" | cut -d: -f1)"
summary_line="$(grep -nF -m1 '<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>' "$DOC" | cut -d: -f1)"
details_close_line="$(grep -nF -m1 '</details>' "$DOC" | cut -d: -f1)"
[[ "$(grep -Fc '<details>' "$DOC")" -eq 1 ]] ||
  fail "module 06 must contain exactly one details block"
[[ "$(grep -Fc '</details>' "$DOC")" -eq 1 ]] ||
  fail "module 06 must close exactly one details block"
[[ -n "$details_open_line" && -n "$summary_line" && -n "$details_close_line" ]] ||
  fail "module 06 missing recovery disclosure structure"
(( details_open_line < summary_line && summary_line < details_close_line )) ||
  fail "module 06 recovery summary must be inside the details block"
summary_next_line="$(sed -n "$((summary_line + 1))p" "$DOC")"
details_prev_line="$(sed -n "$((details_close_line - 1))p" "$DOC")"
[[ -z "${summary_next_line//[[:space:]]/}" ]] ||
  fail "module 06 summary must be followed by a blank line"
[[ -z "${details_prev_line//[[:space:]]/}" ]] ||
  fail "module 06 details close must be preceded by a blank line"

if grep -Fx '## 0. 정리 전에 변수 복구' "$DOC" >/dev/null; then
  fail "module 06 still uses the old recovery heading"
fi

legend_line="$(grep -nF -m1 '## 태그 범례' "$DOC" | cut -d: -f1)"
(( details_close_line < legend_line )) ||
  fail "module 06 recovery details must close before the tag legend"

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
for pattern in \
  '.env.*' \
  '!.env.example' \
  '*.pem' \
  '*.key' \
  '*.pfx' \
  '*.p12' \
  '*.out' \
  '*.bak' \
  '*.swp' \
  '*~'; do
  grep -Fx -- "$pattern" "$IGNORE" >/dev/null ||
    fail ".gitignore missing $pattern"
done

for path in \
  '.env.production' \
  'aca-runner.private-key.pem' \
  'runner-signing.key' \
  'runner-identity.pfx' \
  'runner-identity.p12' \
  'autoscale-load.out' \
  'notes.bak' \
  'module.swp' \
  'draft~'; do
  git -C "$ROOT" check-ignore -q "$path" ||
    fail ".gitignore does not ignore $path"
done

if git -C "$ROOT" check-ignore -q '.env.example'; then
  fail ".env.example must remain eligible for tracking"
fi

if [[ -n "$(git -C "$ROOT" ls-files docs/superpowers)" ]]; then
  fail "internal docs/superpowers files are still tracked"
fi

for path in \
  'README.md' \
  'docs/01-prerequisites-github.md' \
  'docs/02-azure-foundation.md' \
  'docs/03-runner-image.md' \
  'docs/04-event-job-keda.md' \
  'docs/05-parallel-scale-validation.md' \
  'docs/06-security-limitations-cleanup.md' \
  'docs/images/02-azure-portal-resource-group-resources.png' \
  'docs/images/05-github-actions-queued-matrix.png' \
  'docs/images/05-github-actions-successful-matrix.png' \
  'runner/Dockerfile' \
  'runner/entrypoint.sh' \
  'samples/parallel-runner-workflow.yml' \
  'tests/validate-workshop.sh' \
  '.github/workflows/validate-workshop.yml'; do
  git -C "$ROOT" ls-files --error-unmatch "$path" >/dev/null 2>&1 ||
    fail "required workshop file is no longer tracked: $path"
done

printf 'PASS: security and cleanup doc\n'
