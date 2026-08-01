#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

scan=(rg --hidden --glob '!.git/**' --glob '!tests/security-scan.sh')
private_user="$(printf '%s%s' enrico w79)"

if "${scan[@]}" -n -e 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' .; then
  printf 'Potential secret found.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -F "$private_user" .; then
  printf 'Private local username found.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -e 'MODE=.{0,2}0{1}6{3}' .; then
  printf 'World-writable device rule found.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -e 'SUBSYSTEM=="(hidraw|input)".*(MODE=|GROUP=|OWNER=)' .; then
  printf 'Unsafe Udev access directive found.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -e '\be[v]al\b' --glob '*.sh' .; then
  printf 'Dynamic shell execution primitive found.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -e '\bset[f]acl\b' bin lib modules; then
  printf 'Persistent ACL mutation found in production code.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -e '\bch[m]od\b' bin lib modules; then
  printf 'Direct device mode mutation term found in production code.\n' >&2
  exit 1
fi

if find . -type f -name 'actionmaps.xml' -print -quit | grep -q .; then
  printf 'Forbidden game-wide action map file found.\n' >&2
  exit 1
fi

if "${scan[@]}" -n -e 'H[y]3' .; then
  printf 'Unexpected private marker found.\n' >&2
  exit 1
fi

if rg --hidden --glob '!.git/**' -n -e 'uses: ' .github/workflows |
  rg -v -e '@[0-9a-f]{40}$'; then
  printf 'GitHub Action is not pinned to a full commit SHA.\n' >&2
  exit 1
fi

printf 'PASS: security and privacy repository scan\n'
