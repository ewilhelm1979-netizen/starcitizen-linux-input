# Support matrix

| Device or layer | Native Linux | HIDRAW uaccess | Wine | Star Citizen | Notes |
| --- | --- | --- | --- | --- | --- |
| SpaceMouse Wireless USB `256f:c63a` | tested | tested | tested | tested | Six axes in the documented reference environment |
| X-56 stick `0738:2221` | reported | candidate | reported | unverified | Research case; no confirmed fix |
| X-56 throttle `0738:a221` | reported | candidate | reported | unverified | Research case; no confirmed fix |

The SpaceMouse reference environment was NixOS 26.05, Nix-Citizen, Astral Wine
11.12, and Star Citizen LIVE 4.9.188.23497. Flight and shared ground-vehicle
movement worked across six axes without drift or cross-axis input.

For X-56, Linux event input and `joy.cpl` calibration were reported, while Star
Citizen binding and input remained unreliable. Ghost or duplicate DInput and
Windows.Gaming.Input entries varied by runner path. The scoped HIDRAW policy is
a hypothesis to test, not evidence of resolution.

No other hardware identity is claimed by this version.
