# Troubleshooting

## A device is absent from discovery

Confirm that Linux created a HIDRAW, event, or joystick class entry and that its
USB ancestor exposes valid `idVendor` and `idProduct` attributes. Discovery does
not trust leaf-node Udev properties alone. A malformed or escaping class link
causes a fail-closed error.

## Multiple identical devices are reported

Runtime IDs can distinguish physical devices for the current run, but a pure
VID:PID rule applies to all identical units. Review the warning and do not store
a serial number as a hidden workaround. Single-device manifest creation fails
closed when an identical unit was omitted.

## Native access succeeds but the game does not

Check each layer independently: native detection, effective native access,
Wine visibility, Star Citizen visibility, binding confirmation, and gameplay
confirmation. A scoped Udev rule does not repair Wine presentation, Ghost
controllers, XML tokens, or game bindings.

## Event or joystick access is missing

The diagnosis reports the node and effective access. The standard renderer does
not widen input-subsystem access. Inspect the distribution's normal seat and
input-device policy instead.

## A report is intended for a public issue

Use the default `--privacy public`, inspect the result, and share only the
minimal relevant report. Never attach a complete Game.log, exported profile,
registry dump, or environment listing.
