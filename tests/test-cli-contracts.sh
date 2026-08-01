#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
temp="$(mktemp -d)"
SC_TEST_TEMP_DIRS+=("$temp")

assert_exit() {
  local expected="$1"
  shift
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  assert_eq "$expected" "$actual" "unexpected exit code for: $*"
}

assert_exit 64 "$TEST_ROOT/bin/sc-input"
assert_exit 64 "$TEST_ROOT/bin/sc-input" unknown-command
assert_exit 64 "$TEST_ROOT/bin/sc-input" --json discover
assert_exit 64 "$TEST_ROOT/bin/sc-input" discover --json --json
assert_exit 64 "$TEST_ROOT/bin/sc-input" inspect --device
assert_exit 64 "$TEST_ROOT/bin/sc-input" inspect --json
assert_exit 64 "$TEST_ROOT/bin/sc-input" manifest
assert_exit 64 "$TEST_ROOT/bin/sc-input" manifest show
assert_exit 64 "$TEST_ROOT/bin/sc-input" manifest validate a b
assert_exit 64 "$TEST_ROOT/bin/sc-input" manifest create --devices value
assert_exit 64 "$TEST_ROOT/bin/sc-input" udev render
assert_exit 64 "$TEST_ROOT/bin/sc-input" udev render \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --dry-run
assert_exit 64 "$TEST_ROOT/bin/sc-input" verify --known-manifest a --known-manifest b
assert_exit 64 "$TEST_ROOT/bin/sc-input" report \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --privacy unsafe
assert_exit 64 "$TEST_ROOT/bin/sc-input" wine command --prefix "$temp" --runner
assert_exit 64 "$TEST_ROOT/bin/sc-input" star-citizen game-log --privacy public
assert_exit 64 "$TEST_ROOT/bin/sc-input" --version extra
assert_exit 66 "$TEST_ROOT/bin/sc-input" manifest show missing-manifest

discovery="$("$TEST_ROOT/bin/sc-input" discover --json)"
jq -e '.schemaVersion == 1 and (.devices | length) == 1 and (.warnings | type == "array")' \
  <<<"$discovery" >/dev/null
runtime_id="$(jq -r '.devices[0].runtimeId' <<<"$discovery")"
inspection="$("$TEST_ROOT/bin/sc-input" inspect --device "$runtime_id" --json)"
jq -e '.runtimeId | test("^usb-[0-9a-f]{16}$")' <<<"$inspection" >/dev/null
manifests="$("$TEST_ROOT/bin/sc-input" manifest list --json)"
jq -e '.schemaVersion == 1 and (.manifests | type == "array")' <<<"$manifests" >/dev/null
verification="$("$TEST_ROOT/bin/sc-input" verify \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --json)"
jq -e '.manifestId == "3dconnexion-spacemouse-wireless-usb"
  and (.components | length) == 1 and (.statusPipeline | length) == 6' <<<"$verification" >/dev/null

private_output="$temp/private-report.json"
public_output="$temp/public-report.json"
"$TEST_ROOT/bin/sc-input" report --known-manifest 3dconnexion-spacemouse-wireless-usb \
  --privacy private --output "$private_output" >/dev/null
"$TEST_ROOT/bin/sc-input" report --known-manifest 3dconnexion-spacemouse-wireless-usb \
  --privacy public --output "$public_output" >/dev/null
assert_eq 600 "$(stat -c '%a' "$private_output")" 'private report mode mismatch'
assert_eq 600 "$(stat -c '%a' "$public_output")" 'public report mode mismatch'
assert_exit 73 "$TEST_ROOT/bin/sc-input" report \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --output "$public_output"

# shellcheck disable=SC2016
for value in ' ' '../escape' 'name;command' 'name$(id)' 'name*glob' $'name\nline' 'Ａdmin'; do
  assert_exit 65 "$TEST_ROOT/bin/sc-input" manifest create --devices "$runtime_id" \
    --id "$value" --display-name safe --roles controller --preview
done
assert_exit 64 "$TEST_ROOT/bin/sc-input" manifest create --devices "$runtime_id" \
  --id '' --display-name safe --roles controller --preview

unicode_preview="$("$TEST_ROOT/bin/sc-input" manifest create --devices "$runtime_id" \
  --id unicode-controller --display-name 'Controller Ω with spaces' --roles controller --preview)"
assert_eq 'Controller Ω with spaces' "$(jq -r '.displayName' <<<"$unicode_preview")" \
  'safe Unicode display text did not round-trip through JSON'

printf 'PASS: exhaustive CLI option, exit-code, JSON, and output-mode contracts\n'
