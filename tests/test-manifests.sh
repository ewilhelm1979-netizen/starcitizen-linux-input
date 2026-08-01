#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
while IFS= read -r manifest; do
  "$TEST_ROOT/bin/sc-input" manifest validate "$manifest" >/dev/null
done < <(find "$TEST_ROOT/manifests" -type f -name '*.json' -print | sort)

temp="$(mktemp -d)"
SC_TEST_TEMP_DIRS+=("$temp")
base="$TEST_ROOT/manifests/3dconnexion/spacemouse-wireless-usb.json"

jq '.description = "/home/fixture-user/private"' "$base" >"$temp/absolute-path.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/absolute-path.json"

jq '.devices[0].vendorId = "256F"' "$base" >"$temp/invalid-hex.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/invalid-hex.json"

jq '.id = "unsafe;command"' "$base" >"$temp/metachar.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/metachar.json"

jq '.devices += [.devices[0]]' "$base" >"$temp/duplicate-role.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/duplicate-role.json"

jq '.accessPolicy.input = "global-access"' "$base" >"$temp/policy.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/policy.json"

jq '.runCommand = "unsafe"' "$base" >"$temp/executable.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/executable.json"

runtime_id="$("$TEST_ROOT/bin/sc-input" discover --json | jq -r '.devices[0].runtimeId')"
preview="$("$TEST_ROOT/bin/sc-input" manifest create --devices "$runtime_id" --id local-controller \
  --display-name 'Local controller' --roles controller --preview)"
assert_eq 1 "$(jq -r '.schemaVersion' <<<"$preview")" 'created manifest schema version mismatch'
assert_eq unverified "$(jq -r '.support.starCitizen' <<<"$preview")" 'new support status must be unverified'
if grep -Eq '/dev/|/sys/|usb-[0-9a-f]{16}' <<<"$preview"; then
  fail 'runtime paths or ids leaked into a persistent manifest'
fi

printf 'PASS: manifest validation and safe creation\n'
