#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/testlib.sh"

new_fixture x56 >/dev/null
report="$("$TEST_ROOT/bin/sc-input" report --known-manifest saitek-x56-rhino --privacy public)"
jq -e '.privacy == "public" and .manifest.id == "saitek-x56-rhino"' <<<"$report" >/dev/null
assert_eq 2 "$(jq '.detectedNames | length' <<<"$report")" 'public report omitted safe product names'
if grep -Eq '/tmp/|/dev/|/sys/|usb-[0-9a-f]{16}|fixture-user|SERIAL-EXAMPLE|example-token-value' <<<"$report"; then
  fail 'public report contains private detail'
fi

# shellcheck disable=SC1091
source "$TEST_ROOT/lib/common.sh"
source "$TEST_ROOT/lib/privacy.sh"
sensitive='{"username":"fixture-user","home":"/home/fixture-user/private","serialNumber":"SERIAL-EXAMPLE","token":"example-token-value","guid":"{22210738-0000-0000-0000-504944564944}","safe":"keep"}'
filtered="$(sc_privacy_filter_json public <<<"$sensitive")"
assert_eq keep "$(jq -r '.safe' <<<"$filtered")" 'privacy filter removed safe content'
if grep -Eq 'fixture-user|SERIAL-EXAMPLE|example-token-value|22210738' <<<"$filtered"; then
  fail 'privacy filter retained protected data'
fi

printf 'PASS: public report privacy filtering\n'
