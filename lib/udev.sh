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

sc_test_failpoint() {
  local point="$1"
  [[ "${SC_INPUT_TEST_MODE:-0}" == "1" && "${SC_INPUT_FAILPOINT:-}" == "$point" ]] || return 0
  case "${SC_INPUT_FAIL_SIGNAL:-}" in
    INT | TERM | HUP)
      kill -s "$SC_INPUT_FAIL_SIGNAL" "$BASHPID"
      return 1
      ;;
    '') ;;
    *)
      sc_error "unsupported injected signal"
      return 1
      ;;
  esac
  sc_error "injected test failure at $point"
  return 1
}

sc_udev_install_cleanup() {
  local rc="$1"
  local restore_temp=""
  trap - EXIT INT TERM HUP
  [[ -z "${temp:-}" ]] || rm -f -- "$temp"
  if [[ "${SC_INPUT_TEST_MODE:-0}" == "1" && "${SC_INPUT_CLEANUP_FAILPOINT:-}" == "during-cleanup" ]]; then
    sc_error "injected cleanup failure after temporary-file removal; any backup remains recoverable"
    exit 73
  fi
  if [[ "$rc" -ne 0 && "${published:-false}" == "true" ]]; then
    if [[ "${had_target:-false}" == "true" && -n "${backup:-}" && -f "$backup" ]]; then
      if [[ "${SC_INPUT_TEST_MODE:-0}" == "1" && "${SC_INPUT_CLEANUP_FAILPOINT:-}" == "during-rollback" ]]; then
        sc_error "injected rollback failure; original data remains in its unique backup"
        exit 73
      fi
      restore_temp="$(mktemp --tmpdir="$directory" ".$filename.restore.XXXXXXXX")" || exit 73
      cp -p -- "$backup" "$restore_temp" || {
        rm -f -- "$restore_temp"
        exit 73
      }
      mv -fT -- "$restore_temp" "$target" || {
        rm -f -- "$restore_temp"
        exit 73
      }
    else
      rm -f -- "$target"
    fi
  fi
  exit "$rc"
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
  local root_real id filename directory target rules backup="" temp=""
  local had_target=false published=false
  sc_test_failpoint before-validation || sc_die 73 "injected failure before validation"
  sc_manifest_validate "$manifest" || return
  sc_test_failpoint after-validation || sc_die 73 "injected failure after validation"
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

  if [[ -e "$target" ]]; then
    [[ -f "$target" ]] || sc_die 65 "existing rule target is not a regular file"
    [[ "$(stat -c '%h' -- "$target")" -eq 1 ]] || sc_die 65 "existing rule target must not be hard-linked"
    had_target=true
    backup="$(mktemp "$target.backup.XXXXXXXX")" || sc_die 73 "could not reserve rule backup"
    cp -p -- "$target" "$backup" || sc_die 73 "could not create rule backup"
  fi
  sc_test_failpoint after-backup || sc_die 73 "injected failure after backup"

  temp="$(mktemp --tmpdir="$directory" ".$filename.tmp.XXXXXX")" || sc_die 73 "could not create temporary rule file"
  trap 'sc_udev_install_cleanup "$?"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  sc_test_failpoint during-candidate-write || sc_die 73 "injected failure during candidate write"
  if ! printf '%s\n' "$rules" | install -m 0644 /dev/stdin "$temp"; then
    rm -f -- "$temp"
    sc_die 73 "could not populate temporary rule file"
  fi
  sync -f "$temp" 2>/dev/null || true
  sc_test_failpoint before-rename || sc_die 73 "injected failure before rename"
  if [[ "$had_target" == "true" ]]; then
    [[ -f "$target" && ! -L "$target" && "$(stat -c '%h' -- "$target")" -eq 1 ]] ||
      sc_die 73 "rule target changed before publication"
  else
    [[ ! -e "$target" && ! -L "$target" ]] || sc_die 73 "rule target appeared before publication"
  fi
  if ! mv -fT -- "$temp" "$target"; then
    rm -f -- "$temp"
    sc_die 73 "atomic rule installation failed; the previous file remains available in its backup"
  fi
  published=true
  temp=
  sc_test_failpoint after-rename || sc_die 73 "injected failure after rename"

  if [[ "$root_real" == "/" ]] && ! chown root:root -- "$target"; then
    if [[ -n "$backup" ]]; then
      cp -p -- "$backup" "$target" || true
    else
      rm -f -- "$target"
    fi
    sc_die 73 "owner update failed; the installation was rolled back"
  fi
  published=false
  trap - EXIT INT TERM HUP
  sync -f "$directory" 2>/dev/null || true
  printf 'Installed %s\n' "$target"
  [[ -z "$backup" ]] || printf 'Backup: %s\n' "$backup"
  printf 'Rules were not reloaded and devices were not triggered.\n'
}

sc_udev_uninstall() {
  local manifest="$1"
  local requested_root="$2"
  local dry_run="$3"
  local root_real id target backup
  sc_manifest_validate "$manifest" || return
  id="$(jq -r '.id' "$manifest")"
  root_real="$(sc_udev_check_root "$requested_root")"
  target="${root_real%/}/etc/udev/rules.d/60-star-citizen-input-$id.rules"
  [[ ! -L "$target" ]] || sc_die 65 "refusing a symlink rule target"
  [[ -f "$target" ]] || sc_die 66 "installed rule not found: $target"
  [[ "$(stat -c '%h' -- "$target")" -eq 1 ]] || sc_die 65 "installed rule target must not be hard-linked"
  if [[ "$dry_run" == "true" ]]; then
    printf 'Dry run only; would move %s to a unique same-directory removal backup\n' "$target"
    return
  fi
  backup="$(mktemp "$target.removed.XXXXXXXX")" || sc_die 73 "could not reserve removal backup"
  mv -fT -- "$target" "$backup" || sc_die 73 "could not remove rule safely"
  sync -f "$(dirname -- "$target")" 2>/dev/null || true
  printf 'Removed rule; recoverable backup: %s\n' "$backup"
  printf 'Rules were not reloaded and devices were not triggered.\n'
}
