#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
data="$("$TEST_ROOT/bin/sc-input" discover --json)"
assert_eq 1 "$(jq '.devices | length' <<<"$data")" 'SpaceMouse must group into one physical device'
assert_eq 256f "$(jq -r '.devices[0].vendorId' <<<"$data")" 'USB ancestor vendor id was not detected'
assert_eq c63a "$(jq -r '.devices[0].productId' <<<"$data")" 'USB ancestor product id was not detected'
assert_eq 1 "$(jq '.devices[0].nodes.hidraw | length' <<<"$data")" 'HIDRAW node missing'
assert_eq 1 "$(jq '.devices[0].nodes.event | length' <<<"$data")" 'event node missing'
assert_eq 1 "$(jq '.devices[0].nodes.joystick | length' <<<"$data")" 'joystick node missing'
space_runtime_id="$(jq -r '.devices[0].runtimeId' <<<"$data")"
inspection="$("$TEST_ROOT/bin/sc-input" inspect --device "$space_runtime_id" --json)"
assert_eq 3 "$(jq '.access | length' <<<"$inspection")" 'inspect did not include effective access for every node'
confirmed="$("$TEST_ROOT/bin/sc-input" verify \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --json --confirm WINE_VISIBLE)"
assert_eq true "$(jq -r '.statusPipeline[] | select(.status == "WINE_VISIBLE") | .value' <<<"$confirmed")" \
  'explicit Wine visibility confirmation was not applied'
assert_eq explicit-user-confirmation \
  "$(jq -r '.statusPipeline[] | select(.status == "WINE_VISIBLE") | .source' <<<"$confirmed")" \
  'manual status source mismatch'
assert_fails "$TEST_ROOT/bin/sc-input" verify \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --confirm NATIVE_ACCESS_OK

new_fixture x56 >/dev/null
data="$("$TEST_ROOT/bin/sc-input" discover --json)"
assert_eq 2 "$(jq '.devices | length' <<<"$data")" 'X-56 must group into two physical USB devices'
assert_eq 1 "$(jq '[.devices[] | select(.vendorId == "0738" and .productId == "2221")] | length' <<<"$data")" 'X-56 stick missing'
assert_eq 1 "$(jq '[.devices[] | select(.vendorId == "0738" and .productId == "a221")] | length' <<<"$data")" 'X-56 throttle missing'

new_fixture wrong-product >/dev/null
data="$("$TEST_ROOT/bin/sc-input" verify --known-manifest saitek-x56-rhino --json)"
assert_eq 0 "$(jq '[.components[] | select(.physicalDeviceCount > 0)] | length' <<<"$data")" 'wrong product matched the X-56 manifest'

new_fixture duplicates >/dev/null
data="$("$TEST_ROOT/bin/sc-input" discover --json)"
assert_eq 1 "$(jq '.warnings | length' <<<"$data")" 'duplicate physical devices must produce a warning'
one_id="$(jq -r '.devices[0].runtimeId' <<<"$data")"
assert_fails "$TEST_ROOT/bin/sc-input" manifest create --devices "$one_id" --id ambiguous-device \
  --display-name 'Ambiguous device' --roles controller --preview

new_fixture symlink-attack >/dev/null
assert_fails "$TEST_ROOT/bin/sc-input" discover --json

printf 'PASS: discovery and USB ancestor grouping\n'
