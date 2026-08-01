#!/usr/bin/env bash

# shellcheck disable=SC2034
SC_INPUT_VERSION="0.1.0"
SC_INPUT_MAX_MANIFEST_BYTES=262144
SC_INPUT_MAX_GAME_LOG_BYTES=8388608
SC_INPUT_MAX_XML_BYTES=2097152

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

sc_reject_duplicate_options() {
  local argument
  local -A seen=()
  for argument in "$@"; do
    [[ "$argument" == --* || "$argument" == -h ]] || continue
    [[ -z "${seen[$argument]:-}" ]] || sc_die 64 "duplicate option: $argument"
    seen[$argument]=1
  done
}

sc_require_absolute_path() {
  local value="$1"
  local label="${2:-path}"
  [[ "$value" == /* ]] || sc_die 64 "$label must be an absolute path"
}

sc_require_canonical_regular_file() {
  local value="$1"
  local label="${2:-file}"
  local max_bytes="${3:-0}"
  local resolved size
  sc_require_absolute_path "$value" "$label"
  [[ -f "$value" && ! -L "$value" && -r "$value" ]] ||
    sc_die 66 "$label must be a readable regular non-symlink file"
  resolved="$(realpath -e -- "$value")" || sc_die 66 "$label could not be resolved"
  [[ "$resolved" == "$value" ]] || sc_die 65 "$label must be canonical and contain no symlink traversal"
  if [[ "$max_bytes" -gt 0 ]]; then
    size="$(stat -c '%s' -- "$resolved")" || sc_die 66 "$label size could not be read"
    [[ "$size" -le "$max_bytes" ]] || sc_die 65 "$label exceeds the $max_bytes-byte limit"
  fi
}

sc_require_canonical_new_path() {
  local output="$1"
  local label="${2:-output path}"
  local parent resolved_parent lexical
  sc_require_absolute_path "$output" "$label"
  [[ ! -e "$output" && ! -L "$output" ]] || sc_die 73 "refusing to overwrite $label: $output"
  parent="$(dirname -- "$output")"
  [[ -d "$parent" && ! -L "$parent" ]] || sc_die 73 "$label directory must be an existing non-symlink directory"
  resolved_parent="$(realpath -e -- "$parent")" || sc_die 73 "$label directory could not be resolved"
  [[ "$resolved_parent" == "$parent" ]] || sc_die 65 "$label directory must be canonical"
  lexical="$(realpath -m -- "$output")" || sc_die 65 "$label could not be normalized"
  [[ "$lexical" == "$output" ]] || sc_die 65 "$label must be canonical and contain no traversal"
}

sc_write_new_file_from_stdin() {
  local output="$1"
  local mode="$2"
  local label="${3:-output}"
  local parent temp
  sc_require_canonical_new_path "$output" "$label"
  parent="$(dirname -- "$output")"
  temp="$(mktemp --tmpdir="$parent" ".sc-input.tmp.XXXXXXXX")" || sc_die 73 "could not create temporary $label"
  trap 'rm -f -- "${temp:-}"' EXIT INT TERM HUP
  if ! install -m "$mode" /dev/stdin "$temp"; then
    rm -f -- "$temp"
    temp=
    trap - EXIT INT TERM HUP
    sc_die 73 "could not populate $label"
  fi
  if ! ln -- "$temp" "$output"; then
    rm -f -- "$temp"
    temp=
    trap - EXIT INT TERM HUP
    sc_die 73 "could not publish $label without overwriting an existing file"
  fi
  rm -f -- "$temp"
  temp=
  trap - EXIT INT TERM HUP
}

sc_validate_utf8_text_file() {
  local path="$1"
  local label="$2"
  local max_bytes="$3"
  python3 -c '
import pathlib, sys
p = pathlib.Path(sys.argv[1])
limit = int(sys.argv[2])
data = p.read_bytes()
if len(data) > limit or b"\0" in data:
    raise SystemExit(1)
data.decode("utf-8", "strict")
' "$path" "$max_bytes" >/dev/null 2>&1 || sc_die 65 "$label must be bounded NUL-free UTF-8 text"
}

sc_validate_json_structure() {
  local path="$1"
  python3 -c '
import json, pathlib, sys

class DuplicateKey(ValueError):
    pass

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKey(key)
        result[key] = value
    return result

def check_depth(value, depth=0):
    if depth > 32:
        raise ValueError("JSON nesting exceeds 32 levels")
    if isinstance(value, dict):
        for item in value.values():
            check_depth(item, depth + 1)
    elif isinstance(value, list):
        for item in value:
            check_depth(item, depth + 1)

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="strict")
value = json.loads(text, object_pairs_hook=unique_object)
check_depth(value)
' "$path" >/dev/null 2>&1
}

sc_project_root() {
  if [[ -n "${SC_INPUT_PROJECT_ROOT:-}" ]]; then
    [[ "${SC_INPUT_TEST_MODE:-0}" == "1" ]] ||
      sc_die 64 "SC_INPUT_PROJECT_ROOT is restricted to explicit test mode"
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
  [[ "$os_id" =~ ^[A-Za-z0-9._+-]{1,64}$ ]] || os_id=unknown
  [[ "$os_version" =~ ^[A-Za-z0-9._+-]{1,64}$ ]] || os_version=unknown
  jq -cn --arg id "$os_id" --arg version "$os_version" '{id: $id, version: $version}'
}
