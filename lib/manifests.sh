#!/usr/bin/env bash

sc_manifest_validate() {
  local manifest="$1"
  sc_require_canonical_regular_file "$manifest" "manifest" "$SC_INPUT_MAX_MANIFEST_BYTES"
  sc_validate_utf8_text_file "$manifest" "manifest" "$SC_INPUT_MAX_MANIFEST_BYTES"
  sc_validate_json_structure "$manifest" || {
    sc_error "manifest contains duplicate keys, invalid UTF-8, or excessive nesting: $manifest"
    return 65
  }
  jq empty "$manifest" >/dev/null 2>&1 || {
    sc_error "manifest is not valid JSON: $manifest"
    return 65
  }

  jq -e '
    def exact_keys($allowed): (keys | sort) == ($allowed | sort);
    def safe_text($limit):
      type == "string" and length <= $limit
      and (explode | all(. >= 32 and . != 127));
    def status: . == "tested" or . == "reported" or . == "candidate"
      or . == "unverified" or . == "unsupported";
    type == "object"
    and exact_keys(["$schema", "schemaVersion", "id", "displayName", "description",
      "devices", "accessPolicy", "support", "references"])
    and .schemaVersion == 1
    and (.id | type == "string" and test("^[a-z0-9]+([.-][a-z0-9]+)*$"))
    and (.displayName | safe_text(160) and length > 0)
    and (.description | safe_text(2048))
    and (.devices | type == "array" and length > 0 and length <= 32)
    and (.devices | all(
      type == "object"
      and exact_keys(["role", "vendorId", "productId", "transport", "expectedNodes"])
      and (.role | type == "string" and test("^[a-z0-9]+([.-][a-z0-9]+)*$"))
      and (.vendorId | type == "string" and test("^[0-9a-f]{4}$"))
      and (.productId | type == "string" and test("^[0-9a-f]{4}$"))
      and .transport == "usb"
      and (.expectedNodes | type == "array" and length > 0
        and (length == (unique | length))
        and all(. == "hidraw" or . == "event" or . == "joystick"))
    ))
    and ((.devices | map(.role) | length) == (.devices | map(.role) | unique | length))
    and ((.devices | map(.vendorId + ":" + .productId) | length)
      == (.devices | map(.vendorId + ":" + .productId) | unique | length))
    and (.accessPolicy | type == "object" and exact_keys(["hidraw", "input"])
      and .hidraw == "uaccess" and .input == "verify-only")
    and (.support | type == "object"
      and exact_keys(["nativeLinux", "hidrawUaccess", "wine", "starCitizen"])
      and (.nativeLinux | status) and (.hidrawUaccess | status)
      and (.wine | status) and (.starCitizen | status))
    and (.references | type == "array" and length <= 32 and all(
      type == "object" and exact_keys(["type", "url"])
      and (.type == "repository" or .type == "issue" or .type == "documentation")
      and (.url | safe_text(2048) and test("^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:/[^[:cntrl:]]*)?$"))))
    and ([paths(scalars) as $p | getpath($p)
      | select(type == "string" and test("^/"))] | length == 0)
    and ([.. | objects | keys[]
      | select(test("^(serial(number)?|command|script|executable|runCommand)$"; "i"))] | length == 0)
    and ([paths(scalars) as $p | getpath($p)
      | select(type == "string" and test("(^|/)\\.\\.(/|$)"))] | length == 0)
  ' "$manifest" >/dev/null || {
    sc_error "manifest failed schema-version-1 semantic validation: $manifest"
    return 65
  }
}

sc_manifest_files() {
  local root
  root="$(sc_manifest_root)"
  find "$root" -mindepth 2 -maxdepth 2 -type f -name '*.json' ! -path '*/examples/*' -print | sort
}

sc_known_manifest_path() {
  local wanted="$1"
  local file id found=""
  sc_require_safe_slug "$wanted"
  while IFS= read -r file; do
    id="$(jq -r '.id // empty' "$file" 2>/dev/null)"
    if [[ "$id" == "$wanted" ]]; then
      [[ -z "$found" ]] || sc_die 70 "duplicate known manifest id: $wanted"
      found="$file"
    fi
  done < <(sc_manifest_files)
  [[ -n "$found" ]] || return 1
  printf '%s\n' "$found"
}

sc_manifest_list_json() {
  local file
  while IFS= read -r file; do
    sc_manifest_validate "$file" || return
    jq '{id, displayName, description, support, devices}' "$file"
  done < <(sc_manifest_files) | jq -s '{schemaVersion: 1, manifests: sort_by(.id)}'
}

sc_manifest_list_plain() {
  sc_manifest_list_json | jq -r '.manifests[]
    | [.id, .displayName, (.support.hidrawUaccess + "/" + .support.starCitizen)] | @tsv'
}

sc_manifest_build_from_runtime_ids() {
  local ids_csv="$1"
  local manifest_id="$2"
  local display_name="$3"
  local roles_csv="$4"
  local discovery selected_file id role index=0 total selected_count pair_count
  local -a ids roles

  sc_require_safe_slug "$manifest_id"
  jq -en --arg value "$display_name" '
    $value | length > 0 and length <= 160 and (explode | all(. >= 32 and . != 127))
  ' >/dev/null || sc_die 64 "display name must be 1-160 control-free characters"
  IFS=',' read -r -a ids <<<"$ids_csv"
  IFS=',' read -r -a roles <<<"$roles_csv"
  [[ "${#ids[@]}" -gt 0 && "${#ids[@]}" -eq "${#roles[@]}" ]] ||
    sc_die 64 "provide one safe role for each selected runtime id"
  [[ "${#ids[@]}" -le 32 ]] || sc_die 64 "a manifest may contain at most 32 devices"
  [[ "$(printf '%s\n' "${roles[@]}" | sort -u | wc -l)" -eq "${#roles[@]}" ]] ||
    sc_die 65 "device roles must be unique"

  discovery="$(sc_discover_json)" || sc_die 70 "device discovery failed"
  selected_file="$(mktemp)" || sc_die 70 "could not create temporary manifest data"
  for id in "${ids[@]}"; do
    [[ "$id" =~ ^usb-[0-9a-f]{16}$ ]] || {
      rm -f -- "$selected_file"
      sc_die 64 "invalid runtime id: $id"
    }
    role="${roles[$index]}"
    sc_require_safe_slug "$role"
    selected_count="$(jq --arg id "$id" '[.devices[] | select(.runtimeId == $id)] | length' <<<"$discovery")"
    [[ "$selected_count" -eq 1 ]] || {
      rm -f -- "$selected_file"
      sc_die 65 "runtime id is missing or ambiguous: $id"
    }
    jq -c --arg id "$id" --arg role "$role" '
      .devices[] | select(.runtimeId == $id)
      | {role: $role, vendorId, productId, transport,
         expectedNodes: ([
           (if (.nodes.hidraw | length) > 0 then "hidraw" else empty end),
           (if (.nodes.event | length) > 0 then "event" else empty end),
           (if (.nodes.joystick | length) > 0 then "joystick" else empty end)
         ])}' <<<"$discovery" >>"$selected_file"
    index=$((index + 1))
  done

  while IFS= read -r pair_count; do
    total="${pair_count%%:*}"
    selected_count="${pair_count##*:}"
    if [[ "$total" -gt 1 && "$selected_count" -lt "$total" ]]; then
      rm -f -- "$selected_file"
      sc_die 65 "selection is ambiguous: identical physical devices were not all selected"
    fi
  done < <(jq -r --slurpfile chosen "$selected_file" '
    .devices
    | group_by(.vendorId + ":" + .productId)[]
    | (length | tostring) + ":" +
      (.[0] as $d | [$chosen[] | select(.vendorId == $d.vendorId and .productId == $d.productId)]
        | length | tostring)' <<<"$discovery")

  [[ "$(jq -s 'map(.vendorId + ":" + .productId) | length == (unique | length)' "$selected_file")" == true ]] || {
    rm -f -- "$selected_file"
    sc_die 65 "a manifest must not repeat a VID:PID pair"
  }

  jq -s \
    --arg id "$manifest_id" \
    --arg displayName "$display_name" \
    '{
      "$schema": "device-manifest.schema.json",
      schemaVersion: 1,
      id: $id,
      displayName: $displayName,
      description: "Locally created unverified controller manifest.",
      devices: .,
      accessPolicy: {hidraw: "uaccess", input: "verify-only"},
      support: {
        nativeLinux: "unverified", hidrawUaccess: "unverified",
        wine: "unverified", starCitizen: "unverified"
      },
      references: []
    }' "$selected_file"
  rm -f -- "$selected_file"
}

sc_manifest_write_secure() {
  local json="$1"
  local output="$2"
  local parent
  sc_require_absolute_path "$output" "manifest output"
  parent="$(dirname -- "$output")"
  if [[ -e "$parent" ]]; then
    [[ -d "$parent" && ! -L "$parent" ]] || sc_die 73 "manifest directory must be a non-symlink directory"
  else
    install -d -m 0700 -- "$parent" || sc_die 73 "could not create private manifest directory"
  fi
  [[ "$(realpath -e -- "$parent")" == "$parent" ]] || sc_die 65 "manifest directory must be canonical"
  printf '%s\n' "$json" | sc_write_new_file_from_stdin "$output" 0600 "manifest"
  sc_manifest_validate "$output" || {
    rm -f -- "$output"
    sc_die 70 "created manifest did not validate"
  }
  printf '%s\n' "$output"
}
