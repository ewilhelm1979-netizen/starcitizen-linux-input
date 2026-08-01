# NixOS

Import `nixosModules.default` and enable the module explicitly. All options are
under `hardware.starCitizenInput`:

- `enable` defaults to `false`.
- `knownManifests` defaults to an empty list.
- `manifestFiles` defaults to an empty list.
- `diagnosticTools` defaults to `true` when the module is enabled.
- `gui` defaults to `false`.

The module reads local JSON during Nix evaluation, validates a safe manifest
subset, rejects duplicate manifest selections and VID:PID pairs, sorts the
accepted pairs, and builds an early rule file
under `/lib/udev/rules.d` through `services.udev.packages`. It performs no
network access during evaluation and uses no import-from-derivation mechanism.

When enabled, the CLI package is installed. Optional diagnostic tools are
added when requested, and the GUI package is added only when `gui = true`. The
module changes no group membership, starts no daemon or user unit, assumes no
Star Citizen path, and touches no Wine setting.

The X-56 manifest remains a research candidate. Enabling its rule means only
that the exact HIDRAW policy was selected for a hardware test; it does not mark
Star Citizen input as fixed.

## Reference environment and interoperability

The documented SpaceMouse reference environment used
[nix-citizen](https://github.com/LovingMelody/nix-citizen), with the
`wine-astral` package supplied through that project. Citizen Input Manager's
own Flake and NixOS module do not require nix-citizen.

Citizen Input Manager can be used alongside
[LUG Helper](https://github.com/starcitizen-lug/lug-helper) and nix-citizen
without automatically modifying either project, Wine, or launcher
configuration. The projects remain independently maintained.
