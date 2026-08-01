#!/usr/bin/env bash

sc_discovery_node_record() {
  local class_entry="$1"
  local node_type="$2"
  local dev_node="$3"
  local resolved sys_root_real ancestor_info ancestor vendor product
  local runtime_id manufacturer device_name interface_number driver bus

  sys_root_real="$(realpath -e -- "$SC_SYS_ROOT")" || return 1
  resolved="$(sc_resolve_under "$class_entry" "$SC_SYS_ROOT")" || {
    sc_error "rejected sysfs link outside the configured root: $class_entry"
    return 1
  }
  sc_path_is_under "$resolved" "$sys_root_real" || return 1

  ancestor_info="$(sc_find_usb_ancestor "$resolved" "$sys_root_real")" || return 2
  IFS=$'\t' read -r ancestor vendor product <<<"$ancestor_info"
  [[ -n "$ancestor" && -n "$vendor" && -n "$product" ]] || return 2

  if [[ -e "$dev_node" ]]; then
    sc_resolve_under "$dev_node" "$SC_DEV_ROOT" >/dev/null || {
      sc_error "rejected device link outside the configured root: $dev_node"
      return 1
    }
  else
    return 2
  fi

  runtime_id="$(sc_runtime_id "$ancestor")"
  manufacturer="$(sc_read_text_attribute "$ancestor/manufacturer")"
  device_name="$(sc_read_text_attribute "$ancestor/product")"
  interface_number="$(sc_find_interface_number "$resolved" "$ancestor")"
  driver="$(sc_find_driver "$resolved" "$ancestor")"
  bus="$(sc_read_text_attribute "$ancestor/busnum")"

  jq -cn \
    --arg runtimeId "$runtime_id" \
    --arg vendorId "$vendor" \
    --arg productId "$product" \
    --arg manufacturer "$manufacturer" \
    --arg product "$device_name" \
    --arg interface "$interface_number" \
    --arg driver "$driver" \
    --arg bus "$bus" \
    --arg nodeType "$node_type" \
    --arg node "$dev_node" \
    '{runtimeId: $runtimeId, vendorId: $vendorId, productId: $productId,
      manufacturer: $manufacturer, product: $product, transport: "usb",
      interface: $interface, driver: $driver, bus: $bus,
      nodeType: $nodeType, node: $node}'
}

sc_discovery_records() {
  local entry name rc failed=0
  local -a entries=()
  shopt -s nullglob

  entries=("$SC_SYS_ROOT"/class/hidraw/hidraw*)
  for entry in "${entries[@]}"; do
    name="$(basename -- "$entry")"
    sc_discovery_node_record "$entry" hidraw "$SC_DEV_ROOT/$name" || {
      rc=$?
      [[ "$rc" -eq 2 ]] || failed=1
    }
  done

  entries=("$SC_SYS_ROOT"/class/input/event*)
  for entry in "${entries[@]}"; do
    name="$(basename -- "$entry")"
    sc_discovery_node_record "$entry" event "$SC_DEV_ROOT/input/$name" || {
      rc=$?
      [[ "$rc" -eq 2 ]] || failed=1
    }
  done

  entries=("$SC_SYS_ROOT"/class/input/js*)
  for entry in "${entries[@]}"; do
    name="$(basename -- "$entry")"
    sc_discovery_node_record "$entry" joystick "$SC_DEV_ROOT/input/$name" || {
      rc=$?
      [[ "$rc" -eq 2 ]] || failed=1
    }
  done

  shopt -u nullglob
  return "$failed"
}

sc_discover_json() {
  local records_file result
  records_file="$(mktemp)" || return 1
  if ! sc_discovery_records >"$records_file"; then
    rm -f -- "$records_file"
    return 65
  fi

  result="$(jq -s '
    sort_by(.runtimeId, .nodeType, .node)
    | group_by(.runtimeId)
    | map({
        runtimeId: .[0].runtimeId,
        vendorId: .[0].vendorId,
        productId: .[0].productId,
        manufacturer: .[0].manufacturer,
        product: .[0].product,
        transport: "usb",
        interfaces: ([.[].interface | select(length > 0)] | unique | sort),
        drivers: ([.[].driver | select(length > 0)] | unique | sort),
        nodes: {
          hidraw: ([.[] | select(.nodeType == "hidraw") | .node] | unique | sort),
          event: ([.[] | select(.nodeType == "event") | .node] | unique | sort),
          joystick: ([.[] | select(.nodeType == "joystick") | .node] | unique | sort)
        }
      })
    | . as $devices
    | {
        schemaVersion: 1,
        devices: $devices,
        warnings: (
          [$devices
            | group_by(.vendorId + ":" + .productId)[]
            | select(length > 1)
            | "Multiple physical devices share " + .[0].vendorId + ":" + .[0].productId
              + "; a VID:PID rule applies to all of them."]
        )
      }
  ' "$records_file")" || {
    rm -f -- "$records_file"
    return 70
  }
  rm -f -- "$records_file"
  printf '%s\n' "$result"
}

sc_discover_plain() {
  local json="$1"
  if [[ "$(jq '.devices | length' <<<"$json")" -eq 0 ]]; then
    printf 'No supported USB HID input nodes were discovered.\n'
    return
  fi
  printf 'RUNTIME ID\tVID:PID\tPRODUCT\tNODES\n'
  jq -r '.devices[]
    | [.runtimeId, (.vendorId + ":" + .productId),
       (if .product == "" then "Unknown USB HID device" else .product end),
       ("hidraw=" + (.nodes.hidraw | length | tostring)
        + ",event=" + (.nodes.event | length | tostring)
        + ",js=" + (.nodes.joystick | length | tostring))]
    | @tsv' <<<"$json"
  jq -r '.warnings[]? | "WARNING: " + .' <<<"$json" >&2
}
