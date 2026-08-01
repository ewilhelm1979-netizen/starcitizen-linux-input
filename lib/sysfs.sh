#!/usr/bin/env bash

sc_path_is_under() {
  local candidate="$1"
  local root="$2"
  [[ "$candidate" == "$root" || "$candidate" == "$root/"* ]]
}

sc_resolve_under() {
  local candidate="$1"
  local root="$2"
  local resolved_root resolved
  resolved_root="$(realpath -e -- "$root")" || return 1
  resolved="$(realpath -e -- "$candidate")" || return 1
  sc_path_is_under "$resolved" "$resolved_root" || return 1
  printf '%s\n' "$resolved"
}

sc_normalize_hex_id() {
  local value
  value="$(tr -d '[:space:]' <"$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" =~ ^[0-9a-f]{4}$ ]] || return 1
  printf '%s\n' "$value"
}

sc_read_text_attribute() {
  local path="$1"
  [[ -r "$path" ]] || return 0
  LC_ALL=C tr '\000-\010\013\014\016-\037\177' '?' <"$path" | tr '\t\r\n' '   ' | sed 's/[[:space:]]*$//'
}

sc_find_usb_ancestor() {
  local start="$1"
  local root="$2"
  local current="$start"
  local depth vendor product

  for ((depth = 0; depth < 32; depth++)); do
    sc_path_is_under "$current" "$root" || return 1
    if [[ -r "$current/idVendor" && -r "$current/idProduct" ]]; then
      vendor="$(sc_normalize_hex_id "$current/idVendor")" || return 1
      product="$(sc_normalize_hex_id "$current/idProduct")" || return 1
      printf '%s\t%s\t%s\n' "$current" "$vendor" "$product"
      return 0
    fi
    [[ "$current" != "$root" ]] || break
    current="$(dirname -- "$current")"
  done
  return 1
}

sc_find_interface_number() {
  local start="$1"
  local stop="$2"
  local current="$start"
  local depth value
  for ((depth = 0; depth < 32; depth++)); do
    if [[ -r "$current/bInterfaceNumber" ]]; then
      value="$(tr -d '[:space:]' <"$current/bInterfaceNumber" | tr '[:upper:]' '[:lower:]')"
      [[ "$value" =~ ^[0-9a-f]{2}$ ]] && printf '%s\n' "$value"
      return 0
    fi
    [[ "$current" != "$stop" ]] || break
    current="$(dirname -- "$current")"
  done
  return 0
}

sc_find_driver() {
  local start="$1"
  local stop="$2"
  local current="$start"
  local depth driver_path
  for ((depth = 0; depth < 32; depth++)); do
    if [[ -L "$current/driver" ]]; then
      driver_path="$(realpath -e -- "$current/driver")" || return 0
      basename -- "$driver_path"
      return 0
    fi
    [[ "$current" != "$stop" ]] || break
    current="$(dirname -- "$current")"
  done
  return 0
}

sc_runtime_id() {
  local ancestor="$1"
  local digest
  digest="$(printf '%s' "$ancestor" | sha256sum | awk '{print substr($1, 1, 16)}')"
  printf 'usb-%s\n' "$digest"
}
