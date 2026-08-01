#!/usr/bin/env bash
set -euo pipefail

root="${1:?fixture root required}"
scenario="${2:?fixture scenario required}"
[[ "$root" == /* ]] || {
  printf 'Fixture root must be absolute.\n' >&2
  exit 64
}

mkdir -p "$root/sys/class/hidraw" "$root/sys/class/input" "$root/sys/devices" \
  "$root/sys/bus/hid/drivers/hid-generic" "$root/dev/input"

add_device() {
  local slot="$1"
  local vendor="$2"
  local product="$3"
  local manufacturer="$4"
  local product_name="$5"
  local index="$6"
  local usb interface hid input
  usb="$root/sys/devices/pci0000:00/usb1/$slot"
  interface="$usb/$slot:1.0"
  hid="$interface/0003:${vendor^^}:${product^^}.000$index"
  input="$hid/input/input$index"
  mkdir -p "$hid/hidraw/hidraw$index" "$input/event$index" "$input/js$index"
  printf '%s\n' "$vendor" >"$usb/idVendor"
  printf '%s\n' "$product" >"$usb/idProduct"
  printf '%s\n' "$manufacturer" >"$usb/manufacturer"
  printf '%s\n' "$product_name" >"$usb/product"
  printf '1\n' >"$usb/busnum"
  printf '00\n' >"$interface/bInterfaceNumber"
  ln -s "$root/sys/bus/hid/drivers/hid-generic" "$hid/driver"
  ln -s "$hid/hidraw/hidraw$index" "$root/sys/class/hidraw/hidraw$index"
  ln -s "$input/event$index" "$root/sys/class/input/event$index"
  ln -s "$input/js$index" "$root/sys/class/input/js$index"
  : >"$root/dev/hidraw$index"
  : >"$root/dev/input/event$index"
  : >"$root/dev/input/js$index"
}

case "$scenario" in
  spacemouse | ancestor-only)
    add_device 1-1 256f c63a 3Dconnexion 'SpaceMouse Wireless' 0
    ;;
  x56)
    add_device 1-2 0738 2221 Saitek 'X-56 Rhino Stick' 0
    add_device 1-3 0738 a221 Saitek 'X-56 Rhino Throttle' 1
    ;;
  wrong-product)
    add_device 1-4 0738 ffff Saitek 'Unmatched test device' 0
    ;;
  duplicates)
    add_device 1-5 256f c63a 3Dconnexion 'SpaceMouse Wireless A' 0
    add_device 1-6 256f c63a 3Dconnexion 'SpaceMouse Wireless B' 1
    ;;
  symlink-attack)
    outside="${root}-outside"
    mkdir -p "$outside"
    ln -s "$outside" "$root/sys/class/hidraw/hidraw9"
    : >"$root/dev/hidraw9"
    ;;
  *)
    printf 'Unknown fixture scenario: %s\n' "$scenario" >&2
    exit 64
    ;;
esac
