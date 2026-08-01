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

  native_detected="$(jq 'all(.physicalDeviceCount == 1 and (.missingNodeTypes | length == 0))' <<<"$components")"
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
  [[ "$kernel" =~ ^[A-Za-z0-9._+-]{1,128}$ ]] || kernel=unknown
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
        devices: [$manifest.devices[] | {role, vendorId, productId, expectedNodes}],
        support: $manifest.support
      },
      detectedPhysicalDevices: ([$verify.components[].matches[].runtimeId] | unique | length),
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
      details: (if $privacy == "private" then
        ($verify + {
          declaredDisplayName: $manifest.displayName,
          declaredReferences: $manifest.references,
          detectedNames: ([$verify.components[].matches[] | {manufacturer, product}] | unique)
        })
      else null end)
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
  sc_require_canonical_regular_file "$game_log" "game log" "$SC_INPUT_MAX_GAME_LOG_BYTES"
  sc_validate_utf8_text_file "$game_log" "game log" "$SC_INPUT_MAX_GAME_LOG_BYTES"
  lines="$(LC_ALL=C grep -F -m 128 'Connected joystick' -- "$game_log" 2>/dev/null || true)"
  if awk 'length($0) > 4096 {exit 1}' <<<"$lines"; then :; else
    sc_die 65 "connected joystick evidence contains an oversized line"
  fi
  native="$(sc_discover_json)" || return
  jq -cn --arg privacy "$privacy" --arg lines "$lines" --argjson native "$native" '
    ($lines | split("\n") | map(select(length > 0))) as $connected
    | ($connected | map(
        sub("^.*Connected joystick[0-9]+:[[:space:]]*"; "")
        | sub("[[:space:]]*\\{[0-9A-Fa-f-]{16,}\\}.*$"; ""))) as $gameNames
    | ($native.devices | map(.product | select(length > 0)) | unique | sort) as $nativeNames
    | ({
        status: "STAR_CITIZEN_VISIBLE",
        value: (($connected | length) > 0),
        source: "explicit-game-log",
        privacy: $privacy,
        connectedJoystickCount: ($connected | length),
        nativePhysicalDeviceCount: ($native.devices | length),
        deviceCountMatchesNative: (($connected | length) == ($native.devices | length)),
      } + if $privacy == "private" then {
        connectedJoystickNames: ($gameNames | unique | sort),
        nativeProductNames: $nativeNames,
        connectedJoystickLines: $connected
      } else {} end)'
}

sc_profile_validate_xml() {
  local profile="$1"
  sc_require_canonical_regular_file "$profile" "controller profile" "$SC_INPUT_MAX_XML_BYTES"
  sc_validate_utf8_text_file "$profile" "controller profile" "$SC_INPUT_MAX_XML_BYTES"
  python3 - "$profile" <<'PY'
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

path = pathlib.Path(sys.argv[1])
raw = path.read_text(encoding="utf-8", errors="strict")
if re.search(r"<!\s*(DOCTYPE|ENTITY)\b", raw, re.IGNORECASE):
    raise SystemExit(65)
try:
    root = ET.fromstring(raw)
except ET.ParseError:
    print(json.dumps({"wellFormed": False, "invalidTokens": [], "emptyTokenCount": 0,
                      "duplicateRebinds": [], "joystickInstances": [],
                      "mixedJoystickInstances": False, "repaired": False}, sort_keys=True))
    raise SystemExit(65)

tokens = []
element_count = 0
stack = [(root, 1)]
while stack:
    element, depth = stack.pop()
    element_count += 1
    if element_count > 100000 or depth > 64:
        raise SystemExit(65)
    if "input" in element.attrib:
        tokens.append(element.attrib["input"])
    stack.extend((child, depth + 1) for child in list(element))

invalid = sorted({token for token in tokens if re.fullmatch(r"js[0-9]+_\s*", token)})
empty = sum(1 for token in tokens if not token.strip())
duplicates = sorted({token for token in tokens if token.strip() and tokens.count(token) > 1})
instances = sorted({match.group(1) for token in tokens
                    if (match := re.match(r"^(js[0-9]+)_", token))})
mixed = len(instances) > 1
result = {"wellFormed": True, "invalidTokens": invalid, "emptyTokenCount": empty,
          "duplicateRebinds": duplicates, "joystickInstances": instances,
          "mixedJoystickInstances": mixed, "elementCount": element_count,
          "repaired": False}
print(json.dumps(result, sort_keys=True))
if invalid or empty or duplicates or mixed:
    raise SystemExit(65)
PY
}
