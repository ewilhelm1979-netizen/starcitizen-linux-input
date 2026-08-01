#!/usr/bin/env bash

TEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SC_TEST_TEMP_DIRS=()

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  [[ "$expected" == "$actual" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message"
}

assert_fails() {
  "$@" >/dev/null 2>&1 && fail "command unexpectedly succeeded: $*"
  return 0
}

new_fixture() {
  local scenario="$1"
  local temp fixture
  temp="$(mktemp -d)"
  SC_TEST_TEMP_DIRS+=("$temp")
  fixture="$temp/fixture"
  "$TEST_ROOT/tests/fixtures/make-sysfs.sh" "$fixture" "$scenario"
  export SC_INPUT_TEST_MODE=1
  export SC_INPUT_SYS_ROOT="$fixture/sys"
  export SC_INPUT_DEV_ROOT="$fixture/dev"
  printf '%s\n' "$fixture"
}

cleanup_tests() {
  local path
  for path in "${SC_TEST_TEMP_DIRS[@]}"; do
    rm -rf -- "$path"
  done
}

trap cleanup_tests EXIT
