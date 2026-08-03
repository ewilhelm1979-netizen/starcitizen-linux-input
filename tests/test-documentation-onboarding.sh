#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local file="$1"
  local text="$2"
  local label="$3"
  rg -F "$text" "$file" >/dev/null || fail "$label"
}

[[ -f docs/getting-started.md ]] || fail 'getting-started guide is missing'

require_text README.md '## Prerequisites and installation paths' \
  'README prerequisites section is missing'
require_text README.md '](docs/getting-started.md)' \
  'README getting-started link is missing'
require_text README.md 'Home Manager package installation' \
  'README Home Manager path is missing'
require_text README.md '### File 1:' \
  'README flake file heading is missing'
require_text README.md '### File 2:' \
  'README host configuration file heading is missing'
require_text README.md '### File 3:' \
  'README manifest file heading is missing'
require_text README.md '/etc/nixos/flake.nix' \
  'README exact flake path is missing'
require_text README.md '/etc/nixos/hosts/nixos/configuration.nix' \
  'README exact host configuration path is missing'
require_text README.md '/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json' \
  'README exact manifest path is missing'
require_text README.md 'star-citizen-input = {' \
  'README Flake input example is missing'
require_text README.md 'inputs.star-citizen-input.nixosModules.default' \
  'README NixOS module import is missing'
require_text README.md './hosts/nixos/configuration.nix' \
  'README host module import is missing'
require_text README.md 'starCitizenInput = {' \
  'README hardware option example is missing'
require_text README.md './manifests/saitek-x56-rhino-local.json' \
  'README relative manifest path is missing'

for heading in \
  '## Prerequisites' \
  '## Choose an installation path' \
  '## Complete X-56 workflow' \
  '## Final checklist'; do
  require_text docs/getting-started.md "$heading" \
    "getting-started heading is missing: $heading"
done

for text in \
  '/etc/nixos/flake.nix' \
  '/etc/nixos/hosts/nixos/configuration.nix' \
  '/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json' \
  'star-citizen-input = {' \
  'inputs.star-citizen-input.nixosModules.default' \
  './hosts/nixos/configuration.nix' \
  'starCitizenInput = {' \
  './manifests/saitek-x56-rhino-local.json' \
  'nixos-rebuild dry-build' \
  'sc-input verify'; do
  require_text docs/getting-started.md "$text" \
    "getting-started requirement is missing: $text"
done

require_text docs/getting-started.md '### 6. Edit' \
  'getting-started input-file step is missing'
require_text docs/getting-started.md '### 7. Edit the same' \
  'getting-started module-import step is missing'
require_text docs/getting-started.md '### 8. Edit' \
  'getting-started host-configuration step is missing'

for heading in \
  '## Prerequisites' \
  '## Three files, three different jobs' \
  '## File 1:' \
  '## File 2:' \
  '## File 3:' \
  '## Home Manager' \
  '## Post-rebuild verification' \
  '## Common NixOS errors'; do
  require_text docs/nixos.md "$heading" \
    "NixOS heading is missing: $heading"
done

for text in \
  '/etc/nixos/flake.nix' \
  '/etc/nixos/hosts/nixos/configuration.nix' \
  '/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json' \
  'star-citizen-input = {' \
  'inputs.star-citizen-input.nixosModules.default' \
  './hosts/nixos/configuration.nix' \
  'starCitizenInput = {' \
  './manifests/saitek-x56-rhino-local.json'; do
  require_text docs/nixos.md "$text" \
    "NixOS placement requirement is missing: $text"
done

for dependency in acl coreutils findutils gawk jq libxml2 Python systemd util-linux; do
  rg -Fi "$dependency" docs/generic-linux.md >/dev/null ||
    fail "generic Linux dependency is missing: $dependency"
done

require_text docs/gui.md 'Hold **Ctrl**' \
  'GUI Ctrl selection guidance is missing'
require_text docs/gui.md 'The saved file is not automatically installed into NixOS.' \
  'GUI-to-NixOS boundary is missing'
require_text docs/device-manifests.md '## Single-device and grouped manifests' \
  'grouped manifest documentation is missing'
require_text docs/device-manifests.md 'Local paths must be absolute and canonical' \
  'absolute manifest path guidance is missing'

for symptom in \
  'hardware.starCitizenInput' \
  'The manifest path is wrong' \
  'Duplicate X-56 manifest or VID:PID error' \
  'Home Manager installed the GUI but access did not change'; do
  require_text docs/troubleshooting.md "$symptom" \
    "troubleshooting topic is missing: $symptom"
done

require_text README.md '## AI-assisted development' \
  'AI-assisted development disclosure is missing'
require_text README.md 'The human maintainer remains responsible for architecture, implementation' \
  'human responsibility statement is missing'

jq -e '.support == {"nativeLinux":"tested","hidrawUaccess":"tested","wine":"tested","starCitizen":"tested"}' \
  manifests/3dconnexion/spacemouse-wireless-usb.json >/dev/null ||
  fail 'SpaceMouse support state changed'
jq -e '.support == {"nativeLinux":"reported","hidrawUaccess":"candidate","wine":"reported","starCitizen":"unverified"}' \
  manifests/saitek/x56-rhino.json >/dev/null ||
  fail 'X-56 support state changed'

printf 'PASS: prerequisites, exact file placement, NixOS, Home Manager, and troubleshooting documentation\n'
