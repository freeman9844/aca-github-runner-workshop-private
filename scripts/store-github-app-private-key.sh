#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  printf 'Usage: bash scripts/store-github-app-private-key.sh <resource-group>\n' >&2
  exit 1
fi

RG="$1"
GITHUB_APP_KEY_SECRET="${GITHUB_APP_KEY_SECRET:-github-app-private-key}"

for required_command in az openssl; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$required_command" >&2
    exit 1
  fi
done

vault_names_output="$(
  az keyvault list \
    --resource-group "$RG" \
    --query "[].name" \
    --output tsv
)"
VAULT_NAMES=()
while IFS= read -r vault_name; do
  [[ -n "$vault_name" ]] && VAULT_NAMES+=("$vault_name")
done <<<"$vault_names_output"

if [[ "${#VAULT_NAMES[@]}" -ne 1 ]]; then
  printf 'ERROR: Resource Group에서 Key Vault를 정확히 하나 찾지 못했습니다: %s\n' "$RG" >&2
  printf '       발견한 Key Vault 수: %s\n' "${#VAULT_NAMES[@]}" >&2
  exit 1
fi

KEY_VAULT="${VAULT_NAMES[0]}"
printf '실제 Key Vault 확인: %s\n' "$KEY_VAULT"

read -rp "Cloud Shell에 upload한 PEM filename (예: aca-runner-lab.pem): " \
  UPLOADED_PEM_NAME
if [[ -z "$UPLOADED_PEM_NAME" || "$UPLOADED_PEM_NAME" == */* ||
  "$UPLOADED_PEM_NAME" == "." || "$UPLOADED_PEM_NAME" == ".." ]]; then
  printf 'ERROR: filename만 입력하세요. 경로는 입력하지 않습니다.\n' >&2
  exit 1
fi

UPLOADED_PEM_FILE="$HOME/$UPLOADED_PEM_NAME"
if [[ ! -f "$UPLOADED_PEM_FILE" ]]; then
  printf 'ERROR: upload file을 찾을 수 없습니다: %s\n' "$UPLOADED_PEM_FILE" >&2
  exit 1
fi

cleanup_uploaded_pem() {
  rm -f -- "$UPLOADED_PEM_FILE"
}
trap cleanup_uploaded_pem EXIT

chmod 600 "$UPLOADED_PEM_FILE"
openssl pkey -in "$UPLOADED_PEM_FILE" -check -noout

if ! SECRET_ID="$(
  az keyvault secret set \
    --vault-name "$KEY_VAULT" \
    --name "$GITHUB_APP_KEY_SECRET" \
    --file "$UPLOADED_PEM_FILE" \
    --content-type "application/x-pem-file" \
    --query id \
    --output tsv
)"; then
  printf 'ERROR: Key Vault secret 저장에 실패했습니다. 위 Azure CLI 오류를 확인하세요.\n' >&2
  exit 1
fi

if [[ -z "$SECRET_ID" ]]; then
  printf 'ERROR: Key Vault secret 저장 결과에 Secret ID가 없습니다.\n' >&2
  exit 1
fi

printf 'PASS: Key Vault secret 저장 완료: %s\n' "$SECRET_ID"
