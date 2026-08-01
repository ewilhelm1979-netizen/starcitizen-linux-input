#!/usr/bin/env bash

# shellcheck disable=SC2034
SC_INPUT_VERSION="0.1.0"

sc_error() {
  printf 'sc-input: %s\n' "$*" >&2
}

sc_die() {
  local code="$1"
  shift
  sc_error "$*"
  exit "$code"
}

sc_warn() {
  printf 'warning: %s\n' "$*" >&2
}

sc_require_command() {
  command -v "$1" >/dev/null 2>&1 || sc_die 69 "required command not found: $1"
}

sc_is_safe_slug() {
  [[ "$1" =~ ^[a-z0-9]+([.-][a-z0-9]+)*$ ]]
}

sc_require_safe_slug() {
  sc_is_safe_slug "$1" || sc_die 65 "invalid identifier '$1'; use lowercase letters, digits, dots, and hyphens"
}

sc_require_absolute_path() {
  local value="$1"
  local label="${2:-path}"
  [[ "$value" == /* ]] || sc_die 64 "$label must be an absolute path"
}

sc_project_root() {
  if [[ -n "${SC_INPUT_PROJECT_ROOT:-}" ]]; then
    printf '%s\n' "$SC_INPUT_PROJECT_ROOT"
    return
  fi
  local source_dir
  source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  realpath -e -- "$source_dir/.."
}

sc_share_root() {
  if [[ -n "${SC_INPUT_SHARE_DIR:-}" ]]; then
    printf '%s\n' "$SC_INPUT_SHARE_DIR"
  else
    sc_project_root
  fi
}

sc_manifest_root() {
  printf '%s/manifests\n' "$(sc_share_root)"
}

sc_schema_path() {
  printf '%s/schemas/device-manifest.schema.json\n' "$(sc_share_root)"
}

sc_private_data_root() {
  printf '%s/starcitizen-linux-input\n' "${XDG_DATA_HOME:-${HOME}/.local/share}"
}

sc_init_roots() {
  if [[ "${SC_INPUT_TEST_MODE:-0}" == "1" ]]; then
    [[ -n "${SC_INPUT_SYS_ROOT:-}" ]] || sc_die 64 "SC_INPUT_SYS_ROOT is required in test mode"
    [[ -n "${SC_INPUT_DEV_ROOT:-}" ]] || sc_die 64 "SC_INPUT_DEV_ROOT is required in test mode"
    SC_SYS_ROOT="$(realpath -e -- "$SC_INPUT_SYS_ROOT")" || sc_die 65 "invalid test sysfs root"
    SC_DEV_ROOT="$(realpath -e -- "$SC_INPUT_DEV_ROOT")" || sc_die 65 "invalid test device root"
  else
    if [[ -n "${SC_INPUT_SYS_ROOT:-}" || -n "${SC_INPUT_DEV_ROOT:-}" ]]; then
      sc_die 64 "alternate sysfs and device roots require SC_INPUT_TEST_MODE=1"
    fi
    SC_SYS_ROOT="/sys"
    SC_DEV_ROOT="/dev"
  fi
  export SC_SYS_ROOT SC_DEV_ROOT
}

sc_json_pretty() {
  jq --sort-keys '.'
}

sc_shell_quote() {
  printf '%q' "$1"
}

sc_read_os_release() {
  local os_id="unknown"
  local os_version="unknown"
  if [[ -r /etc/os-release ]]; then
    os_id="$(sed -n 's/^ID=//p' /etc/os-release | head -n 1 | tr -d '"')"
    os_version="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -n 1 | tr -d '"')"
  fi
  jq -cn --arg id "$os_id" --arg version "$os_version" '{id: $id, version: $version}'
}
