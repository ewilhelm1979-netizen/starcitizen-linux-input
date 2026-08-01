#!/usr/bin/env bash

sc_node_access_json() {
  local node="$1"
  local resolved mode uid gid readable=false writable=false acl="" tags=""
  resolved="$(sc_resolve_under "$node" "$SC_DEV_ROOT")" || {
    sc_error "rejected device node outside the configured root: $node"
    return 65
  }
  mode="$(stat -c '%a' -- "$resolved")" || return 1
  uid="$(stat -c '%u' -- "$resolved")" || return 1
  gid="$(stat -c '%g' -- "$resolved")" || return 1
  [[ -r "$resolved" ]] && readable=true
  [[ -w "$resolved" ]] && writable=true

  if command -v getfacl >/dev/null 2>&1; then
    acl="$(getfacl -cp -- "$resolved" 2>/dev/null |
      sed -n -e '/^user::/p' -e '/^group::/p' -e '/^mask::/p' -e '/^other::/p')"
  fi
  if [[ "${SC_INPUT_TEST_MODE:-0}" != "1" ]] && command -v udevadm >/dev/null 2>&1; then
    tags="$(udevadm info --query=property --name "$resolved" 2>/dev/null |
      sed -n 's/^TAGS=//p' | head -n 1)"
  fi

  jq -cn \
    --arg path "$node" \
    --arg mode "$mode" \
    --arg uid "$uid" \
    --arg gid "$gid" \
    --arg acl "$acl" \
    --arg tags "$tags" \
    --argjson readable "$readable" \
    --argjson writable "$writable" \
    '{path: $path, mode: $mode, ownerUid: ($uid | tonumber), ownerGid: ($gid | tonumber),
      readable: $readable, writable: $writable,
      aclExcerpt: ($acl | split("\n") | map(select(length > 0))),
      udevTags: ($tags | split(":" ) | map(select(length > 0)))}'
}
