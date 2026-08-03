# Support matrix

| Device or layer | Native Linux | HIDRAW uaccess | Wine | Star Citizen | Notes |
| --- | --- | --- | --- | --- | --- |
| SpaceMouse Wireless USB `256f:c63a` | tested | tested | tested | tested | Six axes in the documented reference environment |
| SpaceMouse Bluetooth or Universal Receiver | unverified | unverified | unverified | unverified | A different transport or USB identity must not inherit the USB reference claim |
| X-56 stick `0738:2221` | tested | candidate | tested | tested | Detected as a separate enabled controller; axes and in-game input worked |
| X-56 throttle `0738:a221` | tested | candidate | tested | tested | Detected as a separate enabled controller; axes and in-game input worked |

The SpaceMouse reference environment was NixOS 26.05, Nix-Citizen, Astral Wine
11.12, and Star Citizen LIVE 4.9.188.23497. Flight and shared ground-vehicle
movement worked across six axes without drift or cross-axis input.

The X-56 was validated live by the human maintainer on 2026-08-03 in a NixOS
26.05, nix-citizen, and Astral Wine/Proton environment. Native Linux exposed the
stick and throttle as separate controllers with working axes and buttons. Star
Citizen listed both devices as enabled and connected, and both supplied usable
in-game input after loading the standard CIG X-56 profile.

The standard CIG profile was adequate for the functional test but its default
mapping was not optimal; user-specific binding adjustments are still expected.
This is not a device-detection failure.

HIDRAW `uaccess` remains `candidate` for the X-56. The scoped policy was present
in the tested configuration, but successful Wine and game input do not by
themselves prove that HIDRAW access was the necessary causal mechanism. The
project keeps that stage separate rather than promoting it by inference.

Read the [X-56 functional validation](research/x56-functional-validation.md)
for the evidence, environment, and limitations. The earlier
[nix-citizen issue 108 research](research/nix-citizen-issue-108.md) remains
historical context. Point-in-time audit statements about an untested X-56 refer
to the older audited commit and are superseded for current support status by
this matrix and the bundled manifest.

No other hardware identity is claimed by this version.

The [architecture overview](architecture.md) illustrates the diagnostic
pipeline without promoting one stage from evidence collected at another.

Related ecosystem context is available from
[LUG Helper](https://github.com/starcitizen-lug/lug-helper) and
[nix-citizen](https://github.com/LovingMelody/nix-citizen). These links do not
change any support state above.
