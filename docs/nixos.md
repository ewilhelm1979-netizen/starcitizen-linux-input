# NixOS

Citizen Input Manager provides a **NixOS system module**. The module is the
component that validates manifests, generates the narrowly scoped HIDRAW Udev
rules, and installs them through `services.udev.packages`.

This distinction matters:

- use the **NixOS module** for hardware access and Udev rules;
- use **Home Manager** only for optional user-level CLI or GUI package
  installation;
- Home Manager alone cannot install system Udev rules under
  `/lib/udev/rules.d` or configure `services.udev.packages`.

All module options are under `hardware.starCitizenInput`:

- `enable` defaults to `false`;
- `knownManifests` defaults to an empty list;
- `manifestFiles` defaults to an empty list;
- `diagnosticTools` defaults to `true` when the module is enabled;
- `gui` defaults to `false`.

The module reads local JSON during Nix evaluation, validates a safe manifest
subset, rejects duplicate manifest selections and VID:PID pairs, sorts the
accepted pairs, and builds an early rule file under `/lib/udev/rules.d`
through `services.udev.packages`. It performs no network access during
evaluation and uses no import-from-derivation mechanism.

When enabled, the CLI package is installed. Optional diagnostic tools are
added when requested, and the GUI package is added only when `gui = true`. The
module changes no group membership, starts no daemon or user unit, assumes no
Star Citizen path, and touches no Wine setting.

The X-56 manifest remains a research candidate. Enabling its rule means only
that the exact HIDRAW policy was selected for a hardware test; it does not mark
Star Citizen input as fixed.

## Choose the integration path

### Recommended: NixOS Flake module

Add the project as a Flake input and import its NixOS module in the system
module list:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    star-citizen-input = {
      url = "github:ewilhelm1979-netizen/starcitizen-linux-input";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, star-citizen-input, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        star-citizen-input.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

The `hardware.starCitizenInput` block then belongs at the top level of the
NixOS system configuration, on the same level as `services`, `networking`,
`environment`, and other `hardware.*` options:

```nix
{ config, pkgs, ... }:

{
  hardware.starCitizenInput = {
    enable = true;
    knownManifests = [ ];
    manifestFiles = [
      ./manifests/saitek-x56-rhino-local.json
    ];
    diagnosticTools = true;
    gui = true;
  };
}
```

Do not place this block inside `environment.systemPackages`, `services`, or a
Home Manager user configuration.

### Simple `/etc/nixos` layout

A small Flake-based `/etc/nixos` setup can keep the familiar
`configuration.nix` layout:

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
└── manifests/
    └── saitek-x56-rhino-local.json
```

In that layout:

- `/etc/nixos/flake.nix` declares the `star-citizen-input` input and imports
  `star-citizen-input.nixosModules.default`;
- `/etc/nixos/configuration.nix` contains the top-level
  `hardware.starCitizenInput` block;
- `./manifests/saitek-x56-rhino-local.json` resolves relative to
  `/etc/nixos/configuration.nix`, so the JSON file is expected at
  `/etc/nixos/manifests/saitek-x56-rhino-local.json`.

Validate first, then switch:

```console
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Replace `nixos` with the actual configuration name from
`nixosConfigurations` when it differs.

A traditional non-Flake `configuration.nix` import path is not currently part
of the tested public interface. For a classic `/etc/nixos/configuration.nix`
installation, the recommended supported approach is to add the minimal
`/etc/nixos/flake.nix` wrapper shown above while keeping the existing
`configuration.nix` file.

### Home Manager

Home Manager can install the CLI and GUI for one user, but it cannot apply the
system-level HIDRAW Udev rules. The NixOS module must still be imported and
configured in the system configuration when hardware access is required.

When `inputs` is available in the Home Manager module arguments, packages may
be installed like this:

```nix
{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages = [
    inputs.star-citizen-input.packages.${system}.default
    inputs.star-citizen-input.packages.${system}.gui
  ];
}
```

For Home Manager integrated into NixOS, pass the Flake inputs when needed:

```nix
home-manager.extraSpecialArgs = { inherit inputs; };
```

Choose one package-installation path:

- set `hardware.starCitizenInput.gui = true` to install the GUI system-wide;
- or install the GUI in `home.packages` for a specific user.

Using both is normally unnecessary. In either case, the Udev rule and
`manifestFiles` remain part of the NixOS system module, not Home Manager.

## Add a local manifest created by the GUI

The GUI saves a local manifest by default under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

For a Flake-based NixOS configuration, copy the reviewed JSON file into the
configuration source so Nix can read it during evaluation. For the simple
`/etc/nixos` layout:

```console
sudo mkdir -p /etc/nixos/manifests
sudo cp \
  "${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/saitek-x56-rhino-local.json" \
  /etc/nixos/manifests/
```

Then reference the copied file from `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  hardware.starCitizenInput = {
    enable = true;
    knownManifests = [ ];
    manifestFiles = [
      ./manifests/saitek-x56-rhino-local.json
    ];

    # Optional packages for inspection and the GUI.
    diagnosticTools = true;
    gui = true;
  };
}
```

For another Flake layout, copy the file into a tracked directory near the Nix
module that references it and adjust the relative path accordingly.

Do not also select the bundled `saitek-x56-rhino` entry in `knownManifests`
when the local file describes the same stick and throttle. The module rejects
duplicate manifest selections and duplicate VID:PID pairs.

After a successful rebuild, reconnect the stick and throttle so the newly
installed scoped `uaccess` rules apply to freshly enumerated HIDRAW nodes:

```console
sudo nixos-rebuild switch --flake /etc/nixos#nixos
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
