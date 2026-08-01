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
assert_eq false "$(jq 'has("connectedJoystickLines") or has("connectedJoystickNames")' <<<"$log_result")" \
  'public Game.log analysis retained attacker-controlled log text'
assert_eq 1 "$(jq '.connectedJoystickCount' <<<"$log_result")" 'connected joystick count mismatch'
assert_eq 1 "$(jq '.nativePhysicalDeviceCount' <<<"$log_result")" 'native comparison count mismatch'
assert_eq true "$(jq -r '.deviceCountMatchesNative' <<<"$log_result")" 'native and Game.log counts should match'
if grep -Eq '22210738|account chat' <<<"$log_result"; then
  fail 'public Game.log analysis leaked a GUID or unrelated content'
fi
private_log_result="$("$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/Game.log" --privacy private)"
assert_eq 1 "$(jq '.connectedJoystickLines | length' <<<"$private_log_result")" \
  'private Game.log analysis omitted explicit local evidence'

printf '%s\n' \
  'Connected joystick0: Ghost A {22210738-0000-0000-0000-504944564944}' \
  'Connected joystick1: Ghost A {22210738-0000-0000-0000-504944564944}' \
  >"$temp/duplicate-Game.log"
duplicate_result="$("$TEST_ROOT/bin/sc-input" star-citizen game-log \
  --game-log "$temp/duplicate-Game.log" --privacy public)"
assert_eq 2 "$(jq '.connectedJoystickCount' <<<"$duplicate_result")" \
  'duplicate or ghost-like Game.log entries were silently deduplicated'

printf '%s\n' 'ordinary malformed or unrelated log content' >"$temp/malformed-Game.log"
malformed_result="$("$TEST_ROOT/bin/sc-input" star-citizen game-log \
  --game-log "$temp/malformed-Game.log" --privacy public)"
assert_eq false "$(jq -r '.value' <<<"$malformed_result")" 'unrelated log content asserted visibility'

python3 - "$temp/huge-line.log" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text("Connected joystick0: " + "x" * 5000 + "\n", encoding="utf-8")
PY
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/huge-line.log"
truncate -s 8388609 "$temp/oversized.log"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/oversized.log"
printf '\xff\0' >"$temp/binary.log"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/binary.log"
ln -s "$temp/Game.log" "$temp/symlink-Game.log"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/symlink-Game.log"
mkfifo "$temp/Game.fifo"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/Game.fifo"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen game-log \
  --game-log "$temp/../$(basename -- "$temp")/Game.log"

printf '%s\n' '<Controller><rebind input="js1_x"><broken></Controller>' >"$temp/malformed.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/malformed.xml"
printf '%s\n' '<!DOCTYPE x [<!ENTITY a "aaaa"><!ENTITY b "&a;&a;&a;&a;">]><x>&b;</x>' \
  >"$temp/entity-expansion.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/entity-expansion.xml"
printf '<Controller>\001</Controller>' >"$temp/control.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/control.xml"
python3 - "$temp/deep.xml" "$temp/huge-elements.xml" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text("<x>" * 66 + "</x>" * 66, encoding="utf-8")
pathlib.Path(sys.argv[2]).write_text("<x>" + "<n/>" * 100001 + "</x>", encoding="utf-8")
PY
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/deep.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/huge-elements.xml"
truncate -s 2097153 "$temp/oversized.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/oversized.xml"
printf '\xff\0' >"$temp/binary.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/binary.xml"
ln -s "$temp/valid.xml" "$temp/symlink.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/symlink.xml"
mkfifo "$temp/profile.fifo"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/profile.fifo"

mkdir -p "$temp/prefix"
install -m 0700 /dev/null "$temp/wine-runner"
wine_preview="$("$TEST_ROOT/bin/sc-input" wine command --prefix "$temp/prefix" --runner "$temp/wine-runner")"
assert_contains "$wine_preview" 'Command preview only; it was not executed' 'Wine command preview lacks safety notice'

hostile_prefix="$temp/prefix with spaces \$(touch WINE_PREFIX_EXECUTED)"
hostile_runner="$temp/runner 'quoted' \$(touch WINE_RUNNER_EXECUTED)"
mkdir -p "$hostile_prefix"
install -m 0700 /dev/null "$hostile_runner"
hostile_preview="$("$TEST_ROOT/bin/sc-input" wine command \
  --prefix "$hostile_prefix" --runner "$hostile_runner")"
assert_contains "$hostile_preview" 'WINEPREFIX=' 'hostile Wine prefix was not represented in the preview'
[[ ! -e WINE_PREFIX_EXECUTED && ! -e WINE_RUNNER_EXECUTED ]] ||
  fail 'Wine preview executed path content'
if rg -n 'reg(\.exe)?[[:space:]]+add|Disable[[:space:]]+hidraw|Enable[[:space:]]+SDL|Map[[:space:]]+Controllers' \
  "$TEST_ROOT/bin" "$TEST_ROOT/lib"; then
  fail 'Wine diagnostic code contains a forbidden registry mutation'
fi

printf 'PASS: Wine, Game.log, and XML diagnostic helpers\n'
