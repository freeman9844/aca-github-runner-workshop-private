#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCKERFILE="$ROOT/runner/Dockerfile"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$DOCKERFILE" ]] || fail "runner/Dockerfile is missing"

dockerfile_text="$(<"$DOCKERFILE")"
[[ "$dockerfile_text" == *'APT::Sandbox::User "root";'* ]] ||
  fail 'Dockerfile must disable apt sandbox during image builds'
[[ "$dockerfile_text" == *'gpasswd --delete runner users'* ]] ||
  fail 'Dockerfile must remove runner from supplemental users group for rootless builds'
[[ "$dockerfile_text" == *'install -d -o runner -g runner -m 0700 /home/runner/.azure'* ]] ||
  fail 'Dockerfile must create a runner-owned Azure CLI config directory'
for obsolete_extension_marker in \
  'AZURE_EXTENSION_DIR' \
  'az extension add --name containerapp' \
  'az containerapp --help'; do
  if [[ "$dockerfile_text" == *"$obsolete_extension_marker"* ]]; then
    fail "Dockerfile must not install the unused Container Apps extension: $obsolete_extension_marker"
  fi
done

config_line="$(grep -nF 'APT::Sandbox::User "root";' "$DOCKERFILE" | cut -d: -f1 | head -n 1)"
apt_line="$(grep -nF 'apt-get update' "$DOCKERFILE" | cut -d: -f1 | head -n 1)"
[[ -n "$config_line" && -n "$apt_line" && "$config_line" -lt "$apt_line" ]] ||
  fail 'apt sandbox config must be written before apt-get update'

printf 'PASS: Dockerfile build prerequisites\n'
