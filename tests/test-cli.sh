#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture spacemouse >/dev/null

check_help() {
  local output
  output="$("$TEST_ROOT/bin/sc-input" "$@")"
  assert_contains "$output" 'Usage:' "missing usage text for: $*"
  assert_contains "$output" 'Exit codes:' "missing exit codes for: $*"
}

check_help --help
check_help discover --help
check_help list --help
check_help inspect --help
check_help manifest list --help
check_help manifest show --help
check_help manifest validate --help
check_help manifest create --help
check_help udev render --help
check_help udev install --help
check_help udev uninstall --help
check_help verify --help
check_help report --help
check_help wine command --help
check_help star-citizen game-log --help
check_help star-citizen validate-profile --help
check_help gui --help

gui_help="$(SC_INPUT_CLI="$TEST_ROOT/bin/sc-input" "$TEST_ROOT/bin/sc-input-gui" --help)"
assert_contains "$gui_help" 'Usage:' 'GUI help is missing usage text'
assert_contains "$gui_help" 'Exit codes:' 'GUI help is missing exit codes'

assert_fails "$TEST_ROOT/bin/sc-input" unknown-command

printf 'PASS: CLI and GUI help contracts\n'
