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

## Add a local manifest created by the GUI

The GUI saves a local manifest by default under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

For a Flake-based NixOS configuration, copy the reviewed JSON file into the
configuration source so Nix can read it during evaluation. For example:

```console
mkdir -p /path/to/your/nixos-config/manifests
cp "${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/saitek-x56-rhino-local.json" \
  /path/to/your/nixos-config/manifests/
```

Then reference the copied file with `manifestFiles`:

```nix
{
  hardware.starCitizenInput = {
    enable = true;
    manifestFiles = [
      ./manifests/saitek-x56-rhino-local.json
    ];

    # Optional packages for inspection and the GUI.
    diagnosticTools = true;
    gui = true;
  };
}
```

If the module has not already been imported, add it to the system module list:

```nix
{
  inputs.star-citizen-input.url =
    "github:ewilhelm1979-netizen/starcitizen-linux-input";

  outputs = { nixpkgs, star-citizen-input, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        star-citizen-input.nixosModules.default
        {
          hardware.starCitizenInput = {
            enable = true;
            manifestFiles = [
              ./manifests/saitek-x56-rhino-local.json
            ];
            diagnosticTools = true;
            gui = true;
          };
        }
      ];
    };
  };
}
```

Do not also select the bundled `saitek-x56-rhino` entry in `knownManifests`
when the local file describes the same stick and throttle. The module rejects
duplicate manifest selections and duplicate VID:PID pairs.

After a successful rebuild, reconnect the stick and throttle so the newly
installed scoped `uaccess` rules apply to freshly enumerated HIDRAW nodes:

```console
sudo nixos-rebuild switch --flake /path/to/your/nixos-config#example
```

Adding the manifest to NixOS installs only its narrowly scoped HIDRAW rules and
the requested packages. It does not confirm Wine visibility, Star Citizen
bindings, or gameplay support. A GUI-created manifest also remains
`unverified` until those stages are confirmed separately.

## Reference environment and interoperability

The documented SpaceMouse reference environment used
[nix-citizen](https://github.com/LovingMelody/nix-citizen), with the
`wine-astral` package supplied through that project. Citizen Input Manager's
own Flake and NixOS module do not require nix-citizen.

Citizen Input Manager can be used alongside
[LUG Helper](https://github.com/starcitizen-lug/lug-helper) and nix-citizen
without automatically modifying either project, Wine, or launcher
configuration. The projects remain independently maintained.
