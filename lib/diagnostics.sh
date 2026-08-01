#!/usr/bin/env bash

sc_verify_manifest_json() {
  local manifest="$1"
  local discovery manifest_json components access_file access_json node type
  local native_detected native_access warnings pipeline
  sc_manifest_validate "$manifest" || return
  discovery="$(sc_discover_json)" || return
  manifest_json="$(jq -c '.' "$manifest")"

  components="$(jq -cn --argjson manifest "$manifest_json" --argjson discovery "$discovery" '
    [$manifest.devices[] as $wanted
      | [$discovery.devices[]
          | select(.vendorId == $wanted.vendorId and .productId == $wanted.productId)] as $matches
      | {
          role: $wanted.role,
          vendorId: $wanted.vendorId,
          productId: $wanted.productId,
          expectedNodes: $wanted.expectedNodes,
          physicalDeviceCount: ($matches | length),
          matches: $matches,
          missingNodeTypes: ([ $wanted.expectedNodes[] as $kind
            | select(([$matches[] | .nodes[$kind][]?] | length) == 0) | $kind ])
        }
    ]')" || return 70

  access_file="$(mktemp)" || return 70
  while IFS=$'\t' read -r type node; do
    [[ -n "$node" ]] || continue
    sc_node_access_json "$node" | jq -c --arg type "$type" '. + {nodeType: $type}' >>"$access_file" || {
      rm -f -- "$access_file"
      return 65
    }
  done < <(jq -r '.[] | .matches[] | .nodes | to_entries[] | .key as $type | .value[] | [$type, .] | @tsv' <<<"$components")
  access_json="$(jq -s 'unique_by(.path) | sort_by(.nodeType, .path)' "$access_file")"
  rm -f -- "$access_file"

  native_detected="$(jq 'all(.physicalDeviceCount >= 1 and (.missingNodeTypes | length == 0))' <<<"$components")"
  native_access="$(jq -n --argjson detected "$native_detected" --argjson access "$access_json" '
    $detected and ($access | length > 0)
    and ($access | all(.readable and (if .nodeType == "hidraw" then .writable else true end)))')"

  warnings="$(jq -cn --argjson components "$components" --argjson discovery "$discovery" '
    ([ $components[]
      | if .physicalDeviceCount == 0 then
          "Missing component " + .role + " (" + .vendorId + ":" + .productId + ")"
        elif .physicalDeviceCount > 1 then
          "Ambiguous component " + .role + ": multiple identical physical devices"
        else empty end,
        if (.missingNodeTypes | length) > 0 then
          "Component " + .role + " is missing expected node types: " + (.missingNodeTypes | join(", "))
        else empty end
      ] + $discovery.warnings) | unique')"

  pipeline="$(jq -cn --argjson detected "$native_detected" --argjson access "$native_access" '[
    {status: "NATIVE_DETECTED", value: $detected, source: "automatic"},
    {status: "NATIVE_ACCESS_OK", value: $access, source: "automatic"},
    {status: "WINE_VISIBLE", value: null, source: "manual-confirmation-required"},
    {status: "STAR_CITIZEN_VISIBLE", value: null, source: "game-log-or-manual-confirmation-required"},
    {status: "STAR_CITIZEN_BINDING_VERIFIED", value: null, source: "manual-confirmation-required"},
    {status: "STAR_CITIZEN_GAMEPLAY_VERIFIED", value: null, source: "manual-confirmation-required"}
  ]')"

  jq -cn \
    --arg toolVersion "$SC_INPUT_VERSION" \
    --arg manifestId "$(jq -r '.id' "$manifest")" \
    --argjson components "$components" \
    --argjson nodeAccess "$access_json" \
    --argjson statusPipeline "$pipeline" \
    --argjson warnings "$warnings" \
    '{toolVersion: $toolVersion, manifestId: $manifestId,
      components: $components, nodeAccess: $nodeAccess,
      statusPipeline: $statusPipeline, warnings: $warnings}'
}

sc_verify_plain() {
  local json="$1"
  jq -r '
    "Manifest: " + .manifestId,
    (.components[] | "- " + .role + " " + .vendorId + ":" + .productId
      + ": physical=" + (.physicalDeviceCount | tostring)
      + ", missing=" + (if (.missingNodeTypes | length) == 0 then "none" else (.missingNodeTypes | join(",")) end)),
    (.nodeAccess[] | "  " + .nodeType + " " + .path + " mode=" + .mode
      + " owner=" + (.ownerUid | tostring) + ":" + (.ownerGid | tostring)
      + " read=" + (.readable | tostring) + " write=" + (.writable | tostring)),
    (.statusPipeline[] | .status + "=" + (if .value == null then "UNCONFIRMED" else (.value | tostring) end)),
    (.warnings[] | "WARNING: " + .)
  ' <<<"$json"
}

sc_apply_status_confirmations() {
  local json="$1"
  local confirmations="${2:-}"
  local status
  local -a requested_statuses
  [[ -n "$confirmations" ]] || {
    printf '%s\n' "$json"
    return
  }
  IFS=',' read -r -a requested_statuses <<<"$confirmations"
  for status in "${requested_statuses[@]}"; do
    case "$status" in
      WINE_VISIBLE | STAR_CITIZEN_VISIBLE | STAR_CITIZEN_BINDING_VERIFIED | STAR_CITIZEN_GAMEPLAY_VERIFIED) ;;
      *) sc_die 64 "unsupported manual status confirmation: $status" ;;
    esac
    json="$(jq --arg status "$status" '
      .statusPipeline |= map(
        if .status == $status then .value = true | .source = "explicit-user-confirmation" else . end)
    ' <<<"$json")"
  done
  printf '%s\n' "$json"
}

sc_report_json() {
  local manifest="$1"
  local privacy="$2"
  local confirmations="${3:-}"
  local verify manifest_json os kernel report
  verify="$(sc_verify_manifest_json "$manifest")" || return
  verify="$(sc_apply_status_confirmations "$verify" "$confirmations")" || return
  manifest_json="$(jq -c '.' "$manifest")"
  os="$(sc_read_os_release)"
  kernel="$(uname -r)"
  report="$(jq -cn \
    --arg toolVersion "$SC_INPUT_VERSION" \
    --arg kernel "$kernel" \
    --argjson distribution "$os" \
    --argjson manifest "$manifest_json" \
    --argjson verify "$verify" \
    --arg privacy "$privacy" '
    {
      reportVersion: 1,
      privacy: $privacy,
      toolVersion: $toolVersion,
      system: {kernel: $kernel, distribution: $distribution},
      manifest: {
        id: $manifest.id,
        displayName: $manifest.displayName,
        devices: [$manifest.devices[] | {role, vendorId, productId, expectedNodes}],
        support: $manifest.support,
        references: $manifest.references
      },
      detectedPhysicalDevices: ([$verify.components[].matches[].runtimeId] | unique | length),
      detectedNames: ([$verify.components[].matches[] | {manufacturer, product}] | unique),
      nodeSummary: {
        hidraw: ([$verify.nodeAccess[] | select(.nodeType == "hidraw")] | length),
        event: ([$verify.nodeAccess[] | select(.nodeType == "event")] | length),
        joystick: ([$verify.nodeAccess[] | select(.nodeType == "joystick")] | length)
      },
      access: {
        readable: (($verify.nodeAccess | length) > 0 and ($verify.nodeAccess | all(.readable))),
        hidrawWritable: (
          [$verify.nodeAccess[] | select(.nodeType == "hidraw")] as $hidraw
          | ($hidraw | length) > 0 and ($hidraw | all(.writable))
        )
      },
      statusPipeline: $verify.statusPipeline,
      warnings: $verify.warnings,
      details: (if $privacy == "private" then $verify else null end)
    }
    | if $privacy == "public" then del(.details) else . end')" || return 70
  printf '%s\n' "$report" | sc_privacy_filter_json "$privacy"
}

sc_report_markdown() {
  jq -r '
    "# Citizen Input Manager support report\n",
    "- Privacy: " + .privacy,
    "- Tool version: " + .toolVersion,
    "- Manifest: " + .manifest.id,
    "- Kernel: " + .system.kernel,
    "- Distribution: " + .system.distribution.id + " " + .system.distribution.version,
    "- Physical devices: " + (.detectedPhysicalDevices | tostring),
    "- Node types: HIDRAW=" + (.nodeSummary.hidraw | tostring)
      + ", event=" + (.nodeSummary.event | tostring)
      + ", joystick=" + (.nodeSummary.joystick | tostring),
    "\n## Status pipeline\n",
    (.statusPipeline[] | "- " + .status + ": "
      + (if .value == null then "unconfirmed" else (.value | tostring) end)),
    "\n## Warnings\n",
    (if (.warnings | length) == 0 then "- None" else (.warnings[] | "- " + .) end)
  '
}

sc_game_log_analyze() {
  local game_log="$1"
  local privacy="$2"
  local lines native
  sc_require_absolute_path "$game_log" "game log path"
  [[ -f "$game_log" && ! -L "$game_log" && -r "$game_log" ]] || sc_die 66 "game log must be a readable regular file"
  lines="$(grep -F 'Connected joystick' -- "$game_log" 2>/dev/null || true)"
  native="$(sc_discover_json)" || return
  jq -cn --arg privacy "$privacy" --arg lines "$lines" --argjson native "$native" '
    ($lines | split("\n") | map(select(length > 0))) as $connected
    | ($connected | map(
        sub("^.*Connected joystick[0-9]+:[[:space:]]*"; "")
        | sub("[[:space:]]*\\{[0-9A-Fa-f-]{16,}\\}.*$"; ""))) as $gameNames
    | ($native.devices | map(.product | select(length > 0)) | unique | sort) as $nativeNames
    | {
        status: "STAR_CITIZEN_VISIBLE",
        value: (($connected | length) > 0),
        source: "explicit-game-log",
        privacy: $privacy,
        connectedJoystickCount: ($connected | length),
        nativePhysicalDeviceCount: ($native.devices | length),
        deviceCountMatchesNative: (($connected | length) == ($native.devices | length)),
        connectedJoystickNames: ($gameNames | unique | sort),
        nativeProductNames: $nativeNames,
        connectedJoystickLines: ($connected | map(
          if $privacy == "public" then gsub("\\{[0-9A-Fa-f-]{16,}\\}"; "[REDACTED_GUID]") else . end))
      }'
}

sc_profile_validate_xml() {
  local profile="$1"
  local tokens_file well_formed=true invalid duplicate empty instances
  sc_require_absolute_path "$profile" "controller profile path"
  [[ -f "$profile" && ! -L "$profile" && -r "$profile" ]] || sc_die 66 "profile must be a readable regular file"
  if grep -Eiq '<!DOCTYPE|<!ENTITY' "$profile"; then
    sc_die 65 "external entities and document type declarations are not allowed"
  fi
  if ! xmllint --nonet --noout "$profile" 2>/dev/null; then
    well_formed=false
  fi
  tokens_file="$(mktemp)" || sc_die 70 "could not create temporary XML token list"
  grep -Eo 'input="[^"]*"' "$profile" | sed -e 's/^input="//' -e 's/"$//' >"$tokens_file" || true
  invalid="$(awk '/^js[0-9]+_[[:space:]]*$/ {print}' "$tokens_file" | jq -R -s 'split("\n") | map(select(length > 0))')"
  empty="$(awk '/^[[:space:]]*$/ {print "empty"}' "$tokens_file" | jq -R -s 'split("\n") | map(select(length > 0)) | length')"
  duplicate="$(sort "$tokens_file" | uniq -d | sed '/^[[:space:]]*$/d' | jq -R -s 'split("\n") | map(select(length > 0))')"
  instances="$(grep -Eo '^js[0-9]+_' "$tokens_file" | sed 's/_$//' | sort -u | jq -R -s 'split("\n") | map(select(length > 0))')"
  rm -f -- "$tokens_file"
  jq -cn --argjson wellFormed "$well_formed" --argjson invalidTokens "$invalid" \
    --argjson emptyTokens "$empty" --argjson duplicateRebinds "$duplicate" \
    --argjson joystickInstances "$instances" \
    '{wellFormed: $wellFormed, invalidTokens: $invalidTokens, emptyTokenCount: $emptyTokens,
      duplicateRebinds: $duplicateRebinds, joystickInstances: $joystickInstances,
      repaired: false}'
  [[ "$well_formed" == "true" && "$(jq 'length' <<<"$invalid")" -eq 0 && "$empty" -eq 0 ]]
}
