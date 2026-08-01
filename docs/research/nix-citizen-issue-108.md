# nix-citizen issue 108 research

[LovingMelody/nix-citizen issue #108](https://github.com/LovingMelody/nix-citizen/issues/108)
tracks the Saitek/Logitech X-56 stick `0738:2221` and throttle `0738:a221`.
Reports indicate that Linux event input and Wine controller-panel calibration
worked, while Star Citizen could list devices without reliably accepting
bindings or gameplay input.

Observed symptoms included placeholder or Ghost entries, the stick
disappearing after some profile imports, and different DInput and
Windows.Gaming.Input device counts across Wine, Astral, LUG Wine, and UMU
paths. One UMU report described an inverted throttle reaching only 50 percent
in game. A later report described similar native-versus-game behavior with
WinWing hardware, but this project does not add any WinWing USB identity.

Open research questions include which Wine input presentation Star Citizen
selects, whether duplicate presentations receive bindings, whether the
controller XML references the intended joystick instances, and whether the
exact HIDRAW nodes have active-session access.

The tested SpaceMouse HIDRAW result makes a scoped X-56 `uaccess` rule a
reasonable controlled experiment. It is not a confirmed X-56 fix. This project
does not perform runner, UMU, registry, SDL, WGI, or binding experiments and
does not comment on or modify issue #108.
