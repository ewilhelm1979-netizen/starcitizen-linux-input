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

jq '.unknown = true' "$base" >"$temp/unknown.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/unknown.json"

jq '.devices[0].role = " role "' "$base" >"$temp/whitespace-role.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/whitespace-role.json"

jq '.id = "cоntroller"' "$base" >"$temp/confusable.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/confusable.json"

jq '.displayName = "line\nbreak"' "$base" >"$temp/control.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/control.json"

jq '.references[0].url = "http://example.invalid/unsafe"' "$base" >"$temp/http-url.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/http-url.json"

jq '.references[0].url = "file:///etc/passwd"' "$base" >"$temp/file-url.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/file-url.json"

jq '.serialNumber = "private"' "$base" >"$temp/serial.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/serial.json"

jq '.devices = []' "$base" >"$temp/empty-devices.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/empty-devices.json"

jq '.devices[0].expectedNodes = []' "$base" >"$temp/empty-nodes.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/empty-nodes.json"

jq '.schemaVersion = 2' "$base" >"$temp/version.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/version.json"

jq '.id = 1' "$base" >"$temp/number.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/number.json"

jq '.displayName = null' "$base" >"$temp/null.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/null.json"

printf '{invalid json\n' >"$temp/malformed.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/malformed.json"

printf '\xff' >"$temp/invalid-utf8.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/invalid-utf8.json"

printf '{"x":"a\0b"}' >"$temp/nul.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/nul.json"

python3 - "$base" "$temp/too-many.json" "$temp/deep.json" <<'PY'
import json, pathlib, sys
base = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
many = dict(base)
many["devices"] = []
for index in range(33):
    many["devices"].append({
        "role": f"controller-{index}", "vendorId": f"{index:04x}",
        "productId": f"{index + 1:04x}", "transport": "usb",
        "expectedNodes": ["hidraw"],
    })
pathlib.Path(sys.argv[2]).write_text(json.dumps(many), encoding="utf-8")
deep = {"leaf": True}
for _ in range(34):
    deep = {"nested": deep}
pathlib.Path(sys.argv[3]).write_text(json.dumps(deep), encoding="utf-8")
PY
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/too-many.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/deep.json"

ln -s "$base" "$temp/symlink.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/symlink.json"
mkfifo "$temp/manifest.fifo"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/manifest.fifo"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/../$(basename -- "$temp")/malformed.json"

runtime_id="$("$TEST_ROOT/bin/sc-input" discover --json | jq -r '.devices[0].runtimeId')"
preview="$("$TEST_ROOT/bin/sc-input" manifest create --devices "$runtime_id" --id local-controller \
  --display-name 'Local controller' --roles controller --preview)"
assert_eq 1 "$(jq -r '.schemaVersion' <<<"$preview")" 'created manifest schema version mismatch'
assert_eq unverified "$(jq -r '.support.starCitizen' <<<"$preview")" 'new support status must be unverified'
if grep -Eq '/dev/|/sys/|usb-[0-9a-f]{16}' <<<"$preview"; then
  fail 'runtime paths or ids leaked into a persistent manifest'
fi

printf 'PASS: manifest validation and safe creation\n'
