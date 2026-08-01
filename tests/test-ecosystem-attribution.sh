#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

lug_helper_url=https://github.com/starcitizen-lug/lug-helper
nix_citizen_url=https://github.com/LovingMelody/nix-citizen

for upstream_url in "$lug_helper_url" "$nix_citizen_url"; do
  rg -F "$upstream_url" README.md >/dev/null || fail "README missing upstream attribution: $upstream_url"
  rg -F "$upstream_url" docs/architecture.md >/dev/null ||
    fail "architecture guide missing upstream context: $upstream_url"
  rg -F "$upstream_url" docs/nixos.md >/dev/null ||
    fail "NixOS guide missing upstream context: $upstream_url"
done
rg -F '`wine-astral`' README.md >/dev/null || fail 'README wine-astral attribution'
rg -F 'maintained independently' README.md >/dev/null || fail 'README independence statement'
rg -F 'no affiliation or endorsement' README.md >/dev/null ||
  fail 'README no-affiliation and no-endorsement statement'
rg -F '[LUG Helper](https://github.com/starcitizen-lug/lug-helper) is the official' \
  README.md >/dev/null || fail 'accurate LUG Helper official-installer role'
rg -F 'installer maintained by the Star Citizen Linux Users Group and community' \
  README.md >/dev/null || fail 'accurate LUG Helper maintainer attribution'

if rg -n -i \
  'official Citizen Input Manager integration|endorsed by (the )?LUG|endorsed by LovingMelody|supported by nix-citizen|developed together with (the )?(LUG|LovingMelody)|part of LUG Helper|included in nix-citizen' \
  README.md docs; then
  fail 'forbidden upstream relationship claim'
fi
if rg -n -i \
  'official[^[:cntrl:]]*(Citizen Input Manager|this (project|repository))|(Citizen Input Manager|this (project|repository))[^[:cntrl:]]*official' \
  README.md docs; then
  fail 'official wording describes Citizen Input Manager'
fi
while IFS= read -r official_line; do
  [[ ${official_line,,} == *'lug helper'* ]] || fail 'official wording does not describe LUG Helper'
done < <(rg -n -i '\bofficial\b' README.md docs || true)

if rg -n \
  'http://github\.com/(starcitizen-lug/lug-helper|LovingMelody/nix-citizen)|\]\(//github\.com/(starcitizen-lug/lug-helper|LovingMelody/nix-citizen)' \
  README.md docs; then
  fail 'non-HTTPS upstream project link'
fi
if rg -n -i 'starcitizen-lug|LovingMelody|wine-astral|lug-helper|nix-citizen' \
  flake.nix flake.lock modules bin lib; then
  fail 'upstream project added as a functional or Nix dependency'
fi
if rg -n -i \
  '!\[[^]]*\]\(https://github\.com/(starcitizen-lug|LovingMelody)' \
  README.md docs; then
  fail 'upstream project image or artwork reference'
fi

printf 'PASS: ecosystem attribution, HTTPS links, independence, and no-endorsement policy\n'
