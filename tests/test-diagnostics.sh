#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
temp="$(mktemp -d)"
SC_TEST_TEMP_DIRS+=("$temp")

printf '%s\n' \
  '<Controller><rebind input="js1_button1"/><rebind input="js1_x"/></Controller>' \
  >"$temp/valid.xml"
xml_result="$("$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/valid.xml")"
assert_eq true "$(jq -r '.wellFormed' <<<"$xml_result")" 'valid controller XML was rejected'
assert_eq js1 "$(jq -r '.joystickInstances[0]' <<<"$xml_result")" 'joystick instance was not listed'

printf '%s\n' '<Controller><rebind input="js1_ "/></Controller>' >"$temp/invalid-token.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/invalid-token.xml"

printf '%s\n' '<!DOCTYPE x [<!ENTITY local SYSTEM "/etc/passwd">]><x>&local;</x>' >"$temp/entity.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/entity.xml"

printf '%s\n' \
  'Unrelated account chat line' \
  'Connected joystick0: Fixture Stick {22210738-0000-0000-0000-504944564944}' \
  >"$temp/Game.log"
log_result="$("$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/Game.log" --privacy public)"
assert_eq 1 "$(jq '.connectedJoystickLines | length' <<<"$log_result")" 'Game.log extraction included unrelated lines'
assert_eq 1 "$(jq '.connectedJoystickCount' <<<"$log_result")" 'connected joystick count mismatch'
assert_eq 1 "$(jq '.nativePhysicalDeviceCount' <<<"$log_result")" 'native comparison count mismatch'
assert_eq true "$(jq -r '.deviceCountMatchesNative' <<<"$log_result")" 'native and Game.log counts should match'
if grep -Eq '22210738|account chat' <<<"$log_result"; then
  fail 'public Game.log analysis leaked a GUID or unrelated content'
fi

mkdir -p "$temp/prefix"
install -m 0700 /dev/null "$temp/wine-runner"
wine_preview="$("$TEST_ROOT/bin/sc-input" wine command --prefix "$temp/prefix" --runner "$temp/wine-runner")"
assert_contains "$wine_preview" 'Command preview only; it was not executed' 'Wine command preview lacks safety notice'

printf 'PASS: Wine, Game.log, and XML diagnostic helpers\n'
