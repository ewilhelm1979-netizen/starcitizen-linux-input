# NixOS

Citizen Input Manager provides a **NixOS system module**. The module validates
manifests, generates narrowly scoped HIDRAW `uaccess` rules, and installs them
through `services.udev.packages`.

## Prerequisites

For the supported NixOS integration path you need:

- NixOS with Flakes enabled;
- a Flake-based system configuration;
- the `star-citizen-input` Flake input;
- one known manifest or one reviewed local schema-version-1 JSON manifest;
- root access for `nixos-rebuild`;
- the controller connected for discovery and reconnected after the rebuild.

Nix provides the CLI runtime dependencies and the optional GUI dependencies.
You do not need to install `jq`, Python, libxml2, Udev tools, Zenity, or
`dialog` manually when using the packaged Nix or NixOS paths.

Wine, Star Citizen, LUG Helper, nix-citizen, and Home Manager are not required
to create, validate, or apply a native Linux manifest. Wine and Star Citizen
are needed only for their later diagnostic stages.

This distinction matters:

- use the **NixOS module** for manifests, hardware access, and Udev rules;
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
accepted pairs, and builds an early rule file through
`services.udev.packages`. It performs no network access during evaluation and
uses no import-from-derivation mechanism.

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

The `hardware.starCitizenInput` block belongs at the top level of the NixOS
system configuration, on the same level as `services`, `networking`,
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

### Existing `hardware = { ... };` block

When `configuration.nix` already groups hardware options, add only
`starCitizenInput` inside that attribute set:

```nix
hardware = {
  enableRedistributableFirmware = true;

  starCitizenInput = {
    enable = true;
    knownManifests = [ ];
    manifestFiles = [
      ./manifests/saitek-x56-rhino-local.json
    ];
    diagnosticTools = true;
    gui = true;
  };

  # Existing Bluetooth, graphics, NVIDIA, controller, or scanner options.
};
```

Inside `hardware = { ... };`, do not write another
`hardware.starCitizenInput = { ... };` block.

### Simple `/etc/nixos` layout

A small Flake-based setup can keep the familiar `configuration.nix` layout:

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
└── manifests/
    └── saitek-x56-rhino-local.json
```

In that layout:

- `/etc/nixos/flake.nix` declares the input and imports
  `star-citizen-input.nixosModules.default`;
- `/etc/nixos/configuration.nix` contains the top-level module options;
- `./manifests/saitek-x56-rhino-local.json` resolves to
  `/etc/nixos/manifests/saitek-x56-rhino-local.json`.

### Modular host layout

A larger configuration may keep host-specific files below `hosts/`:

```text
/etc/nixos/
├── flake.nix
├── hosts/
│   └── nixos/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── manifests/
│           └── saitek-x56-rhino-local.json
└── modules/
```

The Flake may import the external module and host configuration together:

```nix
modules = [
  inputs.star-citizen-input.nixosModules.default
  ./hosts/nixos/configuration.nix
];
```

Alternatively, when `inputs` is passed through `specialArgs`, the host
configuration may import the module itself:

```nix
{
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    inputs.star-citizen-input.nixosModules.default
  ];
}
```

Choose one import location. Importing the same module in both places is
unnecessary.

In the modular layout, this path in
`/etc/nixos/hosts/nixos/configuration.nix`:

```nix
manifestFiles = [
  ./manifests/saitek-x56-rhino-local.json
];
```

resolves to:

```text
/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json
```

Relative Nix paths are resolved relative to the Nix file that contains them.
For a Git-backed Flake, the manifest must also be tracked by Git before it is
included in the Flake source. A local path Flake only requires the file to
exist beneath the Flake root.

### Traditional `configuration.nix` without an existing Flake

A direct non-Flake module import is not currently part of the tested public
interface. Keep the existing `/etc/nixos/configuration.nix` and add a minimal
`/etc/nixos/flake.nix` wrapper using the examples above.

### Home Manager

Home Manager can install the CLI and GUI for one user, but it cannot apply the
system-level HIDRAW Udev rules. The NixOS module must still be imported and
configured in the system configuration when hardware access is required.

When `inputs` is available in Home Manager module arguments:

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

Choose one GUI installation path:

- set `hardware.starCitizenInput.gui = true` to install it system-wide;
- or add the GUI package to `home.packages` for one user.

Using both is normally unnecessary. In either case, `manifestFiles` and Udev
rules remain part of the NixOS system module.

## Add a local manifest created by the GUI

The GUI saves a local manifest by default under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

Validate the file before copying it:

```console
manifest="${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/saitek-x56-rhino-local.json"
manifest="$(realpath "$manifest")"

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  manifest validate "$manifest"

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  udev render --manifest "$manifest"
```

For the simple `/etc/nixos` layout:

```console
sudo mkdir -p /etc/nixos/manifests
sudo cp "$manifest" /etc/nixos/manifests/
```

For the modular host layout:

```console
sudo mkdir -p /etc/nixos/hosts/nixos/manifests
sudo cp "$manifest" /etc/nixos/hosts/nixos/manifests/
```

Do not also select the bundled `saitek-x56-rhino` entry in `knownManifests`
when the local file describes the same stick and throttle. The module rejects
duplicate manifest selections and duplicate VID:PID pairs.

## Validate, switch, and reconnect

Replace `nixos` with the actual name under `nixosConfigurations` when needed:

```console
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

After a successful switch, reconnect the stick and throttle so the newly
installed scoped `uaccess` rules apply to freshly enumerated HIDRAW nodes.

## Post-rebuild verification

Use the installed CLI to verify discovery and current effective access:

```console
sc-input discover --json

sc-input verify \
  --manifest "$(realpath /etc/nixos/manifests/saitek-x56-rhino-local.json)" \
  --json
```

For the modular layout, use the manifest below
`/etc/nixos/hosts/nixos/manifests/` instead.

A successful result confirms only native detection and access. It does not
confirm Wine visibility, Star Citizen visibility, bindings, or gameplay.

## Common NixOS errors

| Error or symptom | Likely cause | Check |
| --- | --- | --- |
| `hardware.starCitizenInput` does not exist | The NixOS module was not imported | Import `nixosModules.default` exactly once |
| Manifest file not found during evaluation | The relative path points to the wrong directory | Resolve it relative to the containing `.nix` file |
| Manifest exists locally but not in a Git Flake source | The JSON is untracked | Add the manifest to Git before rebuilding |
| Duplicate VID:PID or duplicate manifest assertion | Local and bundled X-56 manifests are enabled together | Leave `knownManifests = [ ];` for the local X-56 file |
| GUI command is missing | The GUI package is not installed | Set `gui = true` or install it through Home Manager |
| Home Manager package works but access is unchanged | No NixOS system rule was installed | Configure the NixOS module and rebuild |
| Access is unchanged after a successful rebuild | Existing nodes predate the new rule | Reconnect both components or log out and back in |
| Native access succeeds but the game does not | A later diagnostic layer failed | Test Wine, game visibility, binding, and gameplay separately |

## Reference environment and interoperability

The documented SpaceMouse reference environment used
[nix-citizen](https://github.com/LovingMelody/nix-citizen), with the
`wine-astral` package supplied through that project. Citizen Input Manager's
own Flake and NixOS module do not require nix-citizen.

Citizen Input Manager can be used alongside
[LUG Helper](https://github.com/starcitizen-lug/lug-helper) and nix-citizen
without automatically modifying either project, Wine, or launcher
configuration. The projects remain independently maintained.

For the full start-to-finish X-56 example, read [Getting started](getting-started.md).
