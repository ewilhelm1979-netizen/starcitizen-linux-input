# SpaceMouse case study

The reference SpaceMouse Wireless USB device is `256f:c63a`. Linux exposed the
native device and Wine's controller panel could see it, yet Star Citizen did not
initially receive a useful binding path. The successful change was an exact
HIDRAW rule for this VID:PID using the active-session `uaccess` mechanism.

The confirmed environment was NixOS 26.05 with Nix-Citizen, Astral Wine 11.12,
and Star Citizen LIVE 4.9.188.23497. Manual testing verified all six axes,
flight and shared ground-vehicle movement, no drift, and no cross-axis input.

The result does not justify a global rule, world-writable device access, a
daemon, virtual joystick, proprietary driver, registry change, or controller
profile distribution. It also does not prove that the same permission change
fixes unrelated devices or Wine presentation failures.

Source: [ewilhelm1979-netizen/spacemouse](https://github.com/ewilhelm1979-netizen/spacemouse).
No Star Citizen profile was copied from that repository.
