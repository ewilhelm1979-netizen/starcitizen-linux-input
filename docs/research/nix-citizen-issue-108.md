# nix-citizen issue 108 research

[LovingMelody/nix-citizen issue #108](https://github.com/LovingMelody/nix-citizen/issues/108)
tracks the Saitek/Logitech X-56 stick `0738:2221` and throttle `0738:a221`.
Earlier reports indicated that Linux event input and Wine controller-panel
calibration worked, while Star Citizen could list devices without reliably
accepting bindings or gameplay input.

Observed symptoms included placeholder or Ghost entries, the stick
disappearing after some profile imports, and different DInput and
Windows.Gaming.Input device counts across Wine, Astral, LUG Wine, and UMU
paths. One UMU report described an inverted throttle reaching only 50 percent
in game. A later report described similar native-versus-game behavior with
WinWing hardware, but this project does not add any WinWing USB identity.

Those reports remain useful historical context, but they no longer describe the
current tested state of the bundled X-56 manifest.

## 2026-08-03 maintainer validation

The human maintainer completed a live end-to-end test on NixOS 26.05 with
Citizen Input Manager, nix-citizen, an Astral Wine/Proton runtime, and the Star
Citizen LIVE client.

The result was:

- native Linux detected the X-56 stick and throttle separately;
- axis and button activity was visible for both components;
- Star Citizen listed both devices as enabled and connected controllers;
- the standard CIG X-56 profile loaded successfully;
- stick and throttle axes supplied usable in-game input.

The standard CIG profile was not optimally mapped and still needs
user-specific binding adjustments. That limitation concerns the default
profile layout, not controller detection or basic functionality.

Current bundled-manifest support is therefore `tested` for native Linux, Wine,
and Star Citizen. Scoped HIDRAW `uaccess` remains `candidate`: the rule was
present in the tested configuration, but successful gameplay alone does not
prove that HIDRAW access was the necessary causal mechanism.

See [X-56 functional validation](x56-functional-validation.md) for the exact
support-state decision, evidence, and limitations.

## Remaining research boundaries

Runtime joystick numbers differed between native Linux and the game. This is
expected and reinforces that `/dev/input/js*` numbers and in-game joystick
indices are ephemeral and must not be stored in manifests.

The project still does not claim universal behavior across every Wine runner,
Star Citizen build, firmware revision, USB topology, or imported profile. It
does not perform automatic runner, UMU, registry, SDL, WGI, or binding changes
and does not comment on or modify issue #108.
