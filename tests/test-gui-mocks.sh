#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091,SC2016
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
temp="$(mktemp -d)"
SC_TEST_TEMP_DIRS+=("$temp")
mock_bin="$temp/bin"
mkdir -p "$mock_bin"

# The single-quoted lines below intentionally generate a separate mock script.
# shellcheck disable=SC2016
write_zenity_mock() {
  local mode="$1"
  printf '%s\n' \
    "#!$(command -v bash)" \
    'set -euo pipefail' \
    'printf "%q " "$@" >>"$ZENITY_LOG"' \
    'printf "\\n" >>"$ZENITY_LOG"' \
    'case "$ZENITY_MODE:$*" in' \
    '  error:*"--info"*) exit 2 ;;' \
    '  *:*"--info"*) exit 0 ;;' \
    '  cancel:*"--list"*) exit 1 ;;' \
    '  discover:*"--title=Citizen Input Manager"*)' \
    '    count=$(wc -l <"$ZENITY_STATE")' \
    '    if [[ $count -eq 0 ]]; then printf "Discover physical devices\\n"; else printf "Exit\\n"; fi' \
    '    printf "x\\n" >>"$ZENITY_STATE"' \
    '    ;;' \
    '  *:*"--title=Citizen Input Manager"*) printf "Exit\\n" ;;' \
    '  *) exit 0 ;;' \
    'esac' >"$mock_bin/zenity"
  chmod +x "$mock_bin/zenity"
  export ZENITY_MODE="$mode"
}

export ZENITY_LOG="$temp/zenity.log"
export ZENITY_STATE="$temp/zenity.state"
: >"$ZENITY_LOG"
: >"$ZENITY_STATE"
write_zenity_mock success
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
  "$TEST_ROOT/bin/sc-input-gui"

: >"$ZENITY_STATE"
write_zenity_mock cancel
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
  "$TEST_ROOT/bin/sc-input-gui"

: >"$ZENITY_STATE"
write_zenity_mock error
assert_fails env PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" \
  SC_INPUT_GUI_BACKEND=zenity "$TEST_ROOT/bin/sc-input-gui"

printf '%s\n' "#!$(command -v bash)" 'printf "quit\\n"' >"$mock_bin/dialog"
chmod +x "$mock_bin/dialog"
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=dialog \
  "$TEST_ROOT/bin/sc-input-gui"

printf '%s\n' "#!$(command -v bash)" 'printf "quit\\n" >&2' >"$mock_bin/whiptail"
chmod +x "$mock_bin/whiptail"
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=whiptail \
  "$TEST_ROOT/bin/sc-input-gui"

assert_fails env PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" \
  SC_INPUT_GUI_BACKEND=none "$TEST_ROOT/bin/sc-input-gui"

# This payload must remain literal to prove that the GUI never executes it.
# shellcheck disable=SC2016
printf '%s\n' 'Hostile $(touch SHOULD_NOT_EXIST); Ω' >"$SC_INPUT_SYS_ROOT/devices/pci0000:00/usb1/1-1/product"
hostile_discovery="$("$TEST_ROOT/bin/sc-input" discover --json)"
# shellcheck disable=SC2016
grep -Fq 'Hostile $(touch SHOULD_NOT_EXIST); Ω' <<<"$hostile_discovery" ||
  fail 'hostile fixture name did not reach the CLI JSON backend'
: >"$ZENITY_STATE"
write_zenity_mock discover
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
  "$TEST_ROOT/bin/sc-input-gui"
[[ ! -e SHOULD_NOT_EXIST ]] || fail 'hostile GUI device text was executed'
grep -Fq -- '--column=Product' "$ZENITY_LOG" || fail 'GUI did not map the backend row to Zenity columns'

# The single-quoted lines intentionally generate a separate mock script.
# shellcheck disable=SC2016
write_flow_mock() {
  printf '%s\n' \
    "#!$(command -v bash)" \
    'set -euo pipefail' \
    'printf "%q " "$@" >>"$ZENITY_LOG"; printf "\\n" >>"$ZENITY_LOG"' \
    'joined=$*' \
    'if [[ $joined == *"--info"* || $joined == *"--warning"* || $joined == *"--error"* ]]; then exit 0; fi' \
    'if [[ $joined == *"--column=Runtime ID"* ]]; then' \
    '  case "$ZENITY_MODE" in' \
    '    inspect-device-cancel|create-device-cancel) exit 1 ;;' \
    '    multiple-choice) printf "%s,%s\\n" "$ZENITY_DEVICE_ID" "$ZENITY_SECOND_DEVICE_ID" ;;' \
    '    *) printf "%s\\n" "$ZENITY_DEVICE_ID" ;;' \
    '  esac' \
    '  exit 0' \
    'fi' \
    'if [[ $joined == *"--forms"* ]]; then' \
    '  [[ $ZENITY_MODE != create-form-cancel ]] || exit 1' \
    '  printf "gui-controller|GUI Controller Ω|controller\\n"; exit 0' \
    'fi' \
    'if [[ $joined == *"--title=Manifest preview"* ]]; then' \
    '  [[ $ZENITY_MODE != create-preview-cancel ]] || exit 1' \
    '  exit 0' \
    'fi' \
    'if [[ $joined == *"--question"* ]]; then' \
    '  [[ $ZENITY_MODE != create-question-cancel ]] || exit 1' \
    '  exit 0' \
    'fi' \
    'if [[ $joined == *"--column=Manifest ID"* ]]; then' \
    '  [[ $ZENITY_MODE != known-choice-cancel ]] || exit 1' \
    '  printf "3dconnexion-spacemouse-wireless-usb\\n"; exit 0' \
    'fi' \
    'if [[ $joined == *"--column=Action"* && $joined != *"--title=Citizen Input Manager"* ]]; then' \
    '  [[ $ZENITY_MODE != known-action-cancel ]] || exit 1' \
    '  if [[ $ZENITY_MODE == export-file-cancel ]]; then printf "Export public report\\n"; else printf "Show manifest\\n"; fi' \
    '  exit 0' \
    'fi' \
    'if [[ $joined == *"--file-selection"* ]]; then exit 1; fi' \
    'if [[ $joined == *"--column=Action"* && $joined == *"--title=Citizen Input Manager"* ]]; then' \
    '  if [[ ! -s $ZENITY_STATE ]]; then' \
    '    printf "x\\n" >>"$ZENITY_STATE"' \
    '    case "$ZENITY_MODE" in' \
    '      main-cancel) exit 1 ;;' \
    '      inspect-*|multiple-choice) printf "Inspect one device\\n" ;;' \
    '      create-*) printf "Create local HOTAS manifest\\n" ;;' \
    '      known-*-cancel|export-file-cancel|hostile-manifest) printf "Known manifests and diagnostics\\n" ;;' \
    '      empty-discovery) printf "Discover physical devices\\n" ;;' \
    '      *) printf "Exit\\n" ;;' \
    '    esac' \
    '  else printf "Exit\\n"; fi' \
    '  exit 0' \
    'fi' \
    'exit 0' >"$mock_bin/zenity"
  chmod +x "$mock_bin/zenity"
}

write_flow_mock
ZENITY_DEVICE_ID="$(jq -r '.devices[0].runtimeId' <<<"$hostile_discovery")"
export ZENITY_DEVICE_ID
for mode in main-cancel inspect-device-cancel create-device-cancel create-form-cancel \
  create-preview-cancel create-question-cancel known-choice-cancel known-action-cancel \
  export-file-cancel; do
  : >"$ZENITY_STATE"
  export ZENITY_MODE="$mode"
  PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
    "$TEST_ROOT/bin/sc-input-gui"
done

new_fixture x56 >/dev/null
x56_gui_data="$("$TEST_ROOT/bin/sc-input" discover --json)"
ZENITY_DEVICE_ID="$(jq -r '.devices[0].runtimeId' <<<"$x56_gui_data")"
ZENITY_SECOND_DEVICE_ID="$(jq -r '.devices[1].runtimeId' <<<"$x56_gui_data")"
export ZENITY_DEVICE_ID ZENITY_SECOND_DEVICE_ID
: >"$ZENITY_STATE"
export ZENITY_MODE=multiple-choice
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
  "$TEST_ROOT/bin/sc-input-gui"

new_fixture spacemouse >/dev/null
share="$temp/share"
mkdir -p "$share/manifests/test" "$share/schemas"
cp -- "$TEST_ROOT/schemas/device-manifest.schema.json" "$share/schemas/"
jq '.displayName = "Hostile manifest $(touch MANIFEST_EXECUTED); Ω"' \
  "$TEST_ROOT/manifests/3dconnexion/spacemouse-wireless-usb.json" \
  >"$share/manifests/test/hostile.json"
: >"$ZENITY_STATE"
export ZENITY_MODE=hostile-manifest
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
  SC_INPUT_SHARE_DIR="$share" "$TEST_ROOT/bin/sc-input-gui"
[[ ! -e MANIFEST_EXECUTED ]] || fail 'hostile GUI manifest text was executed'
grep -Fq 'MANIFEST_EXECUTED' "$ZENITY_LOG" || fail 'hostile manifest did not reach the GUI argument boundary'

new_fixture empty >/dev/null
: >"$ZENITY_STATE"
export ZENITY_MODE=empty-discovery
PATH="$mock_bin:$PATH" SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=zenity \
  "$TEST_ROOT/bin/sc-input-gui"

if rg -n '(^|[[:space:]])(sudo|pkexec)([[:space:]]|$)|--password' "$TEST_ROOT/bin/sc-input-gui"; then
  fail 'GUI contains a privilege or password prompt path'
fi

printf 'PASS: GUI/TUI backends, empty/one/multiple devices, nested cancellation, and hostile text\n'
