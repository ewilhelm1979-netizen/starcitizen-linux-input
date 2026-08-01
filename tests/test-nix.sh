#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

if command -v nix-instantiate >/dev/null 2>&1; then
  nix-instantiate --parse "$TEST_ROOT/flake.nix" >/dev/null
  nix-instantiate --parse "$TEST_ROOT/modules/nixos/default.nix" >/dev/null
fi

rg -F 'services.udev.packages' "$TEST_ROOT/modules/nixos/default.nix" >/dev/null
rg -F 'hardware.starCitizenInput.enable' "$TEST_ROOT/README.md" >/dev/null

printf 'PASS: Nix syntax and module wiring\n'
