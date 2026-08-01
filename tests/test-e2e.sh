#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

temp="$(mktemp -d)"
SC_TEST_TEMP_DIRS+=("$temp")

new_fixture spacemouse >/dev/null
discovery="$("$TEST_ROOT/bin/sc-input" discover --json)"
jq -e '.schemaVersion == 1 and (.devices | length) == 1
  and (.devices[0].vendorId == "256f") and (.devices[0].productId == "c63a")
  and (.warnings | type == "array")' <<<"$discovery" >/dev/null
plain_list="$("$TEST_ROOT/bin/sc-input" list)"
assert_contains "$plain_list" '256f:c63a' 'SpaceMouse list omitted the fixture identity'
runtime_id="$(jq -r '.devices[0].runtimeId' <<<"$discovery")"
inspection="$("$TEST_ROOT/bin/sc-input" inspect --device "$runtime_id" --json)"
jq -e '.runtimeId == $id and (.access | length == 3)
  and (.access | all(has("mode") and has("readable") and has("writable")))' \
  --arg id "$runtime_id" <<<"$inspection" >/dev/null

manifest="$temp/journey-spacemouse.json"
created_path="$("$TEST_ROOT/bin/sc-input" manifest create --devices "$runtime_id" \
  --id journey-spacemouse --display-name 'Journey SpaceMouse' --roles controller \
  --output "$manifest")"
assert_eq "$manifest" "$created_path" 'manifest create returned the wrong output path'
assert_eq 600 "$(stat -c '%a' "$manifest")" 'created manifest is not private'
"$TEST_ROOT/bin/sc-input" manifest validate "$manifest" >/dev/null
jq -e '.id == "journey-spacemouse" and (.devices | length == 1)
  and (.support | to_entries | all(.value == "unverified"))' "$manifest" >/dev/null

rule="$("$TEST_ROOT/bin/sc-input" udev render --manifest "$manifest")"
assert_eq 'SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="256f", ATTRS{idProduct}=="c63a", TAG+="uaccess"' \
  "$rule" 'journey renderer changed the approved SpaceMouse rule'
install_root="$temp/install-root"
mkdir -p "$install_root/etc/udev/rules.d"
"$TEST_ROOT/bin/sc-input" udev install --manifest "$manifest" --root "$install_root" >/dev/null
target="$install_root/etc/udev/rules.d/60-star-citizen-input-journey-spacemouse.rules"
assert_eq "$rule" "$(<"$target")" 'journey installation content mismatch'

verification="$("$TEST_ROOT/bin/sc-input" verify --manifest "$manifest" --json)"
jq -e '.manifestId == "journey-spacemouse" and (.components | length == 1)
  and (.nodeAccess | length == 3) and (.statusPipeline | length == 6)
  and (.statusPipeline | map(.status) == ["NATIVE_DETECTED", "NATIVE_ACCESS_OK",
    "WINE_VISIBLE", "STAR_CITIZEN_VISIBLE", "STAR_CITIZEN_BINDING_VERIFIED",
    "STAR_CITIZEN_GAMEPLAY_VERIFIED"])' <<<"$verification" >/dev/null

public_report="$temp/journey-public.json"
private_report="$temp/journey-private.json"
"$TEST_ROOT/bin/sc-input" report --manifest "$manifest" --privacy public \
  --output "$public_report" >/dev/null
"$TEST_ROOT/bin/sc-input" report --manifest "$manifest" --privacy private \
  --output "$private_report" >/dev/null
jq -e '.privacy == "public" and (.manifest | keys
  == ["devices", "id", "support"]) and (has("details") | not)' "$public_report" >/dev/null
jq -e '.privacy == "private" and (.details.declaredDisplayName == "Journey SpaceMouse")' \
  "$private_report" >/dev/null
assert_eq 600 "$(stat -c '%a' "$public_report")" 'public journey report output mode mismatch'
assert_eq 600 "$(stat -c '%a' "$private_report")" 'private journey report output mode mismatch'

"$TEST_ROOT/bin/sc-input" udev uninstall --manifest "$manifest" --root "$install_root" >/dev/null
[[ ! -e "$target" ]] || fail 'journey uninstall left the active rule in place'
removed_backup="$(find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.removed.*' -print -quit)"
[[ -f "$removed_backup" ]] || fail 'journey uninstall did not preserve a removal backup'
assert_eq "$rule" "$(<"$removed_backup")" 'journey removal backup content mismatch'

new_fixture x56 >/dev/null
x56_discovery="$("$TEST_ROOT/bin/sc-input" discover --json)"
stick_id="$(jq -r '.devices[] | select(.productId == "2221") | .runtimeId' <<<"$x56_discovery")"
throttle_id="$(jq -r '.devices[] | select(.productId == "a221") | .runtimeId' <<<"$x56_discovery")"
x56_manifest="$temp/journey-x56.json"
"$TEST_ROOT/bin/sc-input" manifest create --devices "$stick_id,$throttle_id" \
  --id journey-x56 --display-name 'Journey X-56' --roles stick,throttle \
  --output "$x56_manifest" >/dev/null
jq -e '.devices == [
  {role:"stick",vendorId:"0738",productId:"2221",transport:"usb",
    expectedNodes:["hidraw","event","joystick"]},
  {role:"throttle",vendorId:"0738",productId:"a221",transport:"usb",
    expectedNodes:["hidraw","event","joystick"]}]
  and (.support | to_entries | all(.value == "unverified"))' "$x56_manifest" >/dev/null
x56_rules="$("$TEST_ROOT/bin/sc-input" udev render --manifest "$x56_manifest")"
assert_eq 2 "$(wc -l <<<"$x56_rules" | tr -d ' ')" 'X-56 journey did not render two rules'
assert_eq 2221 "$(sed -n '1s/.*idProduct}=="\([0-9a-f]*\)".*/\1/p' <<<"$x56_rules")" \
  'X-56 rule order was not deterministic'
assert_eq a221 "$(sed -n '2s/.*idProduct}=="\([0-9a-f]*\)".*/\1/p' <<<"$x56_rules")" \
  'X-56 rule order was not deterministic'

printf 'PASS: end-to-end SpaceMouse and grouped X-56 fixture journeys\n'
