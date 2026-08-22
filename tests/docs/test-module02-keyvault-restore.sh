#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FOUNDATION="$ROOT/docs/02-azure-foundation.md"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

step_one="$(
  awk '
    /^## 1\. / { in_section=1 }
    /^## 2\. / { exit }
    in_section { print }
  ' "$FOUNDATION"
)"

for text in \
  'az account set --subscription "$SUBSCRIPTION_ID"' \
  'az keyvault list' \
  '--resource-group "$RG"' \
  '--query "[].name"' \
  'VAULT_NAMES=()' \
  'if [[ "${#VAULT_NAMES[@]}" -ne 1 ]]' \
  'KEY_VAULT="${VAULT_NAMES[0]}"' \
  'KEY_VAULT_ID=$(az keyvault show' \
  '실제 Key Vault를 정확히 하나 찾지 못했습니다'; do
  [[ "$step_one" == *"$text"* ]] ||
    fail "Module 02 step 1 actual Key Vault restore missing: $text"
done

for obsolete in \
  'read -rp "Saved Key Vault name:' \
  'if [[ -z "${KEY_VAULT:-}" ]]'; do
  [[ "$step_one" != *"$obsolete"* ]] ||
    fail "Module 02 step 1 must not trust a stale Key Vault variable: $obsolete"
done

account_line="$(printf '%s\n' "$step_one" | grep -nF 'az account set --subscription "$SUBSCRIPTION_ID"' | cut -d: -f1)"
list_line="$(printf '%s\n' "$step_one" | grep -nF 'az keyvault list' | cut -d: -f1)"
show_line="$(printf '%s\n' "$step_one" | grep -nF 'KEY_VAULT_ID=$(az keyvault show' | cut -d: -f1)"
[[ "$account_line" -lt "$list_line" && "$list_line" -lt "$show_line" ]] ||
  fail 'Module 02 must select the subscription, resolve the vault, then query its ID'

printf 'PASS: Module 02 resolves the actual Key Vault\n'
