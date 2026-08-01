#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null
backend="$(SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" SC_INPUT_GUI_BACKEND=none \
  "$TEST_ROOT/bin/sc-input-gui" --backend-info)"
assert_eq none "$backend" 'GUI backend override failed'

if rg -n '/sys/class|/dev/hidraw|/dev/input' "$TEST_ROOT/bin/sc-input-gui" >/dev/null; then
  fail 'GUI contains independent device discovery paths'
fi
assert_contains "$(sed -n '1,260p' "$TEST_ROOT/bin/sc-input-gui")" 'discover --json' \
  'GUI does not use the machine-readable CLI discovery output'

printf 'PASS: GUI delegates discovery to the CLI backend\n'
