#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
fixture="${SC_INPUT_SYS_ROOT%/sys}"
space_rule="$("$TEST_ROOT/bin/sc-input" udev render --known-manifest 3dconnexion-spacemouse-wireless-usb)"
assert_eq 'SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="256f", ATTRS{idProduct}=="c63a", TAG+="uaccess"' \
  "$space_rule" 'SpaceMouse rule is not exact'

x56_rules="$("$TEST_ROOT/bin/sc-input" udev render --known-manifest saitek-x56-rhino)"
assert_eq 2 "$(wc -l <<<"$x56_rules" | tr -d ' ')" 'X-56 must render two rules'
assert_contains "$x56_rules" 'ATTRS{idProduct}=="2221"' 'X-56 stick rule missing'
assert_contains "$x56_rules" 'ATTRS{idProduct}=="a221"' 'X-56 throttle rule missing'
if grep -Eq 'MODE=|GROUP=|OWNER=|RUN=|PROGRAM=|IMPORT=|SUBSYSTEM=="input"' <<<"$x56_rules"; then
  fail 'unsafe or non-HIDRAW Udev directive rendered'
fi

install_root="$(dirname -- "$fixture")/install-root"
mkdir -p "$install_root/etc/udev/rules.d"
dry_run="$("$TEST_ROOT/bin/sc-input" udev install --known-manifest 3dconnexion-spacemouse-wireless-usb \
  --root "$install_root" --dry-run)"
assert_contains "$dry_run" 'Dry run only' 'installer dry-run was not explicit'

"$TEST_ROOT/bin/sc-input" udev install --known-manifest 3dconnexion-spacemouse-wireless-usb \
  --root "$install_root" >/dev/null
target="$install_root/etc/udev/rules.d/60-star-citizen-input-3dconnexion-spacemouse-wireless-usb.rules"
assert_eq 644 "$(stat -c '%a' "$target")" 'installed test rule mode mismatch'
assert_eq "$space_rule" "$(sed -n '1p' "$target")" 'installed test rule content mismatch'

attack_root="$(dirname -- "$fixture")/attack-root"
outside="$(dirname -- "$fixture")/outside-rule"
mkdir -p "$attack_root/etc/udev/rules.d"
: >"$outside"
ln -s "$outside" "$attack_root/etc/udev/rules.d/60-star-citizen-input-3dconnexion-spacemouse-wireless-usb.rules"
assert_fails "$TEST_ROOT/bin/sc-input" udev install --known-manifest 3dconnexion-spacemouse-wireless-usb \
  --root "$attack_root"

printf 'PASS: reproducible scoped Udev rules and testroot installer\n'
