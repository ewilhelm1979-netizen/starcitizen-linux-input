#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f docs/getting-started.md ]] || fail 'getting-started guide is missing'

rg -F '## Prerequisites and installation paths' README.md >/dev/null ||
  fail 'README prerequisites section is missing'
rg -F '](docs/getting-started.md)' README.md >/dev/null ||
  fail 'README getting-started link is missing'
rg -F 'When used through Nix, the package supplies its runtime dependencies' README.md >/dev/null ||
  fail 'README packaged dependency guidance is missing'
rg -F 'Home Manager may install the CLI or GUI, but it cannot install the system Udev rules by itself.' README.md >/dev/null ||
  fail 'README Home Manager boundary is missing'

for heading in \
  '## Prerequisites' \
  '## Choose an installation path' \
  '## Complete X-56 workflow' \
  '## Final checklist'; do
  rg -F "$heading" docs/getting-started.md >/dev/null ||
    fail "getting-started heading is missing: $heading"
done

for required in \
  'LUG Helper and nix-citizen are related community projects, not runtime' \
  'Wine and Star Citizen are not prerequisites for discovery' \
  'inputs.star-citizen-input.nixosModules.default' \
  'starCitizenInput = {' \
  '/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json' \
  'nixos-rebuild dry-build' \
  'sc-input verify'; do
  rg -F "$required" docs/getting-started.md >/dev/null ||
    fail "getting-started requirement is missing: $required"
done

rg -F '## Prerequisites' docs/nixos.md >/dev/null ||
  fail 'NixOS prerequisites are missing'
rg -F '### Existing `hardware = { ... };` block' docs/nixos.md >/dev/null ||
  fail 'nested hardware example is missing'
rg -F '### Modular host layout' docs/nixos.md >/dev/null ||
  fail 'modular host layout is missing'
rg -F '### Home Manager' docs/nixos.md >/dev/null ||
  fail 'Home Manager guidance is missing'
rg -F 'Importing the same module in both places is' docs/nixos.md >/dev/null ||
  fail 'single module import guidance is missing'
rg -F '## Post-rebuild verification' docs/nixos.md >/dev/null ||
  fail 'post-rebuild verification is missing'
rg -F '## Common NixOS errors' docs/nixos.md >/dev/null ||
  fail 'NixOS error table is missing'

for dependency in acl coreutils findutils gawk jq libxml2 Python systemd util-linux; do
  rg -Fi "$dependency" docs/generic-linux.md >/dev/null ||
    fail "generic Linux dependency is missing: $dependency"
done

rg -F 'Hold **Ctrl** while clicking non-adjacent rows.' docs/gui.md >/dev/null ||
  fail 'GUI multi-selection guidance is missing'
rg -F 'The saved file is not automatically installed into NixOS.' docs/gui.md >/dev/null ||
  fail 'GUI-to-NixOS boundary is missing'

rg -F '## Single-device and grouped manifests' docs/device-manifests.md >/dev/null ||
  fail 'grouped manifest documentation is missing'
rg -F 'Local paths must be absolute and canonical' docs/device-manifests.md >/dev/null ||
  fail 'absolute manifest path guidance is missing'

for symptom in \
  '`hardware.starCitizenInput` is unknown' \
  'The manifest path is wrong' \
  'Duplicate X-56 manifest or VID:PID error' \
  'Home Manager installed the GUI but access did not change'; do
  rg -F "$symptom" docs/troubleshooting.md >/dev/null ||
    fail "troubleshooting topic is missing: $symptom"
done

rg -F '## AI-assisted development' README.md >/dev/null ||
  fail 'AI-assisted development disclosure is missing'
rg -F 'The human maintainer remains responsible for architecture, implementation' README.md >/dev/null ||
  fail 'human responsibility statement is missing'

jq -e '.support == {"nativeLinux":"tested","hidrawUaccess":"tested","wine":"tested","starCitizen":"tested"}' \
  manifests/3dconnexion/spacemouse-wireless-usb.json >/dev/null ||
  fail 'SpaceMouse support state changed'
jq -e '.support == {"nativeLinux":"reported","hidrawUaccess":"candidate","wine":"reported","starCitizen":"unverified"}' \
  manifests/saitek/x56-rhino.json >/dev/null ||
  fail 'X-56 support state changed'

printf 'PASS: prerequisites, installation paths, NixOS, Home Manager, and troubleshooting documentation\n'
