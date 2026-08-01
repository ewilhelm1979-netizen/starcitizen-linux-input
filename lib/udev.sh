#!/usr/bin/env bash

sc_udev_render() {
  local manifest="$1"
  sc_manifest_validate "$manifest" || return
  jq -r '
    [.devices[] | [.vendorId, .productId]]
    | unique | sort_by(.[0], .[1])[]
    | "SUBSYSTEM==\"hidraw\", KERNEL==\"hidraw*\", ATTRS{idVendor}==\"" + .[0]
      + "\", ATTRS{idProduct}==\"" + .[1] + "\", TAG+=\"uaccess\""
  ' "$manifest"
}

sc_udev_check_root() {
  local requested="$1"
  local root_real current component
  sc_require_absolute_path "$requested" "installation root"
  [[ -d "$requested" && ! -L "$requested" ]] || sc_die 65 "installation root must be a non-symlink directory"
  root_real="$(realpath -e -- "$requested")" || sc_die 65 "could not resolve installation root"
  [[ "$root_real" == "$requested" ]] || sc_die 65 "installation root must already be canonical"
  if [[ "$root_real" != "/" && "${SC_INPUT_TEST_MODE:-0}" != "1" ]]; then
    sc_die 64 "alternate installation roots are restricted to SC_INPUT_TEST_MODE=1"
  fi
  if [[ "$root_real" == "/" && "$(id -u)" -ne 0 ]]; then
    sc_die 77 "a real-system installation requires UID 0; no privilege escalation is performed"
  fi
  current="$root_real"
  for component in etc udev rules.d; do
    current="${current%/}/$component"
    [[ -d "$current" && ! -L "$current" ]] || sc_die 65 "rule directory component is missing or a symlink: $current"
  done
  printf '%s\n' "$root_real"
}

sc_udev_install() {
  local manifest="$1"
  local requested_root="$2"
  local dry_run="$3"
  local root_real id filename directory target rules backup="" timestamp temp
  sc_manifest_validate "$manifest" || return
  id="$(jq -r '.id' "$manifest")"
  sc_require_safe_slug "$id"
  rules="$(sc_udev_render "$manifest")" || return
  root_real="$(sc_udev_check_root "$requested_root")"
  filename="60-star-citizen-input-$id.rules"
  directory="${root_real%/}/etc/udev/rules.d"
  target="$directory/$filename"
  [[ ! -L "$target" ]] || sc_die 65 "refusing a symlink rule target: $target"

  if [[ "$dry_run" == "true" ]]; then
    printf 'Dry run only; no file will be changed.\nTarget: %s\n\n%s\n' "$target" "$rules"
    return
  fi

  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  if [[ -e "$target" ]]; then
    [[ -f "$target" ]] || sc_die 65 "existing rule target is not a regular file"
    backup="$target.backup-$timestamp"
    [[ ! -e "$backup" && ! -L "$backup" ]] || sc_die 73 "backup path already exists"
    cp -p -- "$target" "$backup" || sc_die 73 "could not create rule backup"
  fi

  temp="$(mktemp --tmpdir="$directory" ".$filename.tmp.XXXXXX")" || sc_die 73 "could not create temporary rule file"
  if ! printf '%s\n' "$rules" | install -m 0644 /dev/stdin "$temp"; then
    rm -f -- "$temp"
    sc_die 73 "could not populate temporary rule file"
  fi
  sync -f "$temp" 2>/dev/null || true
  if ! mv -fT -- "$temp" "$target"; then
    rm -f -- "$temp"
    sc_die 73 "atomic rule installation failed; the previous file remains available in its backup"
  fi

  if [[ "$root_real" == "/" ]] && ! chown root:root -- "$target"; then
    if [[ -n "$backup" ]]; then
      cp -p -- "$backup" "$target" || true
    else
      rm -f -- "$target"
    fi
    sc_die 73 "owner update failed; the installation was rolled back"
  fi
  sync -f "$directory" 2>/dev/null || true
  printf 'Installed %s\n' "$target"
  [[ -z "$backup" ]] || printf 'Backup: %s\n' "$backup"
  printf 'Rules were not reloaded and devices were not triggered.\n'
}

sc_udev_uninstall() {
  local manifest="$1"
  local requested_root="$2"
  local dry_run="$3"
  local root_real id target backup timestamp
  sc_manifest_validate "$manifest" || return
  id="$(jq -r '.id' "$manifest")"
  root_real="$(sc_udev_check_root "$requested_root")"
  target="${root_real%/}/etc/udev/rules.d/60-star-citizen-input-$id.rules"
  [[ ! -L "$target" ]] || sc_die 65 "refusing a symlink rule target"
  [[ -f "$target" ]] || sc_die 66 "installed rule not found: $target"
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup="$target.removed-$timestamp"
  [[ ! -e "$backup" && ! -L "$backup" ]] || sc_die 73 "backup path already exists"
  if [[ "$dry_run" == "true" ]]; then
    printf 'Dry run only; would move %s to %s\n' "$target" "$backup"
    return
  fi
  mv -- "$target" "$backup" || sc_die 73 "could not remove rule safely"
  sync -f "$(dirname -- "$target")" 2>/dev/null || true
  printf 'Removed rule; recoverable backup: %s\n' "$backup"
  printf 'Rules were not reloaded and devices were not triggered.\n'
}
