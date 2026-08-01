#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
temp="$(mktemp -d)"
SC_TEST_TEMP_DIRS+=("$temp")
base="$TEST_ROOT/manifests/3dconnexion/spacemouse-wireless-usb.json"

jq '.displayName = "account-987 secret=SENSITIVE-VALUE host=private-host" |
    .description = "token SENSITIVE-TOKEN" |
    .references = [{"type":"documentation","url":"https://example.invalid/?access_token=SENSITIVE-URL-TOKEN"}]' \
  "$base" >"$temp/privacy.json"
public_report="$("$TEST_ROOT/bin/sc-input" report --manifest "$temp/privacy.json" --privacy public)"
if grep -Eq 'account-987|SENSITIVE-VALUE|private-host|SENSITIVE-TOKEN|SENSITIVE-URL-TOKEN' <<<"$public_report"; then
  fail 'public report retained injected private manifest values'
fi

printf '%s\n' \
  'Connected joystick0: account-987 SENSITIVE-GAMELOG-TOKEN {22210738-0000-0000-0000-504944564944}' \
  >"$temp/Game.log"
public_log="$("$TEST_ROOT/bin/sc-input" star-citizen game-log --game-log "$temp/Game.log" --privacy public)"
if grep -Eq 'account-987|SENSITIVE-GAMELOG-TOKEN|22210738' <<<"$public_log"; then
  fail 'public Game.log result retained attacker-controlled text or a GUID'
fi

{
  printf '{\n'
  printf '  "schemaVersion": 999,\n'
  sed -n '2,$p' "$base"
} >"$temp/duplicate-key.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/duplicate-key.json"

jq '.devices += [(.devices[0] | .role = "second-controller")]' "$base" >"$temp/duplicate-pair.json"
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/duplicate-pair.json"

python3 - "$base" "$temp/oversized.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
data["description"] = "x" * 300000
pathlib.Path(sys.argv[2]).write_text(json.dumps(data))
PY
assert_fails "$TEST_ROOT/bin/sc-input" manifest validate "$temp/oversized.json"

new_fixture duplicates >/dev/null
ambiguous="$("$TEST_ROOT/bin/sc-input" verify \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --json)"
assert_eq false "$(jq -r '.statusPipeline[] | select(.status == "NATIVE_DETECTED") | .value' <<<"$ambiguous")" \
  'ambiguous devices must fail closed for native detection'
assert_eq false "$(jq -r '.statusPipeline[] | select(.status == "NATIVE_ACCESS_OK") | .value' <<<"$ambiguous")" \
  'ambiguous devices must fail closed for native access'

new_fixture spacemouse >/dev/null
mkdir -p "$temp/noncanonical"
printf '%s\n' '<Controller><rebind input="js1_x"/></Controller>' >"$temp/profile.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile \
  --profile "$temp/noncanonical/../profile.xml"
printf '%s\n' '<Controller><rebind input="js1_x"/><rebind input="js1_x"/></Controller>' \
  >"$temp/duplicate.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/duplicate.xml"
printf '%s\n' '<Controller><rebind input="js1_x"/><rebind input="js2_y"/></Controller>' \
  >"$temp/mixed.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/mixed.xml"
printf '%s\n' '<!DOCTYPE x [<!ENTITY local SYSTEM "file:///etc/passwd">]><x>&local;</x>' \
  >"$temp/entity.xml"
assert_fails "$TEST_ROOT/bin/sc-input" star-citizen validate-profile --profile "$temp/entity.xml"

fixture="${SC_INPUT_SYS_ROOT%/sys}"
install_root="$(dirname -- "$fixture")/failure-root"
mkdir -p "$install_root/etc/udev/rules.d"
target="$install_root/etc/udev/rules.d/60-star-citizen-input-3dconnexion-spacemouse-wireless-usb.rules"
printf '%s\n' 'original rule' >"$target"
for point in before-validation after-validation after-backup during-candidate-write before-rename after-rename; do
  assert_fails env SC_INPUT_FAILPOINT="$point" "$TEST_ROOT/bin/sc-input" udev install \
    --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$install_root"
  assert_eq 'original rule' "$(<"$target")" "failure at $point did not preserve or restore the target"
  if find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.tmp.*' -print -quit | grep -q .; then
    fail "failure at $point left a temporary rule file"
  fi
done

for signal in INT TERM HUP; do
  assert_fails env SC_INPUT_FAILPOINT=after-rename SC_INPUT_FAIL_SIGNAL="$signal" \
    "$TEST_ROOT/bin/sc-input" udev install \
    --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$install_root"
  assert_eq 'original rule' "$(<"$target")" "signal $signal did not restore the target"
  if find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.tmp.*' -print -quit | grep -q .; then
    fail "signal $signal left a temporary rule file"
  fi
done

assert_fails env SC_INPUT_FAILPOINT=before-rename SC_INPUT_CLEANUP_FAILPOINT=during-cleanup \
  "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$install_root"
assert_eq 'original rule' "$(<"$target")" 'cleanup failure changed the original target'
if find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.tmp.*' -print -quit | grep -q .; then
  fail 'cleanup failure left a temporary rule file'
fi

backups_before="$(find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.backup.*' | wc -l)"
assert_fails env SC_INPUT_FAILPOINT=after-rename SC_INPUT_CLEANUP_FAILPOINT=during-rollback \
  "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$install_root"
backups_after="$(find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.backup.*' | wc -l)"
((backups_after > backups_before)) || fail 'rollback failure did not preserve a unique recovery backup'
assert_eq 644 "$(stat -c '%a' "$target")" 'rollback failure left an unsafe target mode'
cp -- "$(find "$install_root/etc/udev/rules.d" -maxdepth 1 -name '*.backup.*' -printf '%T@ %p\n' | sort -n | tail -n 1 | cut -d' ' -f2-)" "$target"

hardlink_root="$(dirname -- "$fixture")/hardlink-root"
mkdir -p "$hardlink_root/etc/udev/rules.d"
hard_target="$hardlink_root/etc/udev/rules.d/60-star-citizen-input-3dconnexion-spacemouse-wireless-usb.rules"
printf '%s\n' 'old' >"$hardlink_root/outside"
ln "$hardlink_root/outside" "$hard_target"
assert_fails "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$hardlink_root"

special_root="$(dirname -- "$fixture")/special-root"
mkdir -p "$special_root/etc/udev/rules.d"
special_target="$special_root/etc/udev/rules.d/60-star-citizen-input-3dconnexion-spacemouse-wireless-usb.rules"
mkfifo "$special_target"
assert_fails "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$special_root"

symlink_root="$(dirname -- "$fixture")/directory-symlink-root"
mkdir -p "$symlink_root/etc/udev" "$symlink_root/real-rules"
ln -s "$symlink_root/real-rules" "$symlink_root/etc/udev/rules.d"
assert_fails "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$symlink_root"

assert_fails env -u SC_INPUT_TEST_MODE "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$install_root"
assert_fails "$TEST_ROOT/bin/sc-input" udev install \
  --known-manifest 3dconnexion-spacemouse-wireless-usb --root "$install_root/../install-root"

assert_fails env SC_INPUT_LIB_DIR="$temp" "$TEST_ROOT/bin/sc-input" --version

printf 'PASS: adversarial privacy, parser, ambiguity, path, and transaction tests\n'
