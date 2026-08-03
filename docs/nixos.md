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

The bundled X-56 manifest is tested in the documented maintainer environment
for native Linux, Wine presentation, Star Citizen visibility, and usable
in-game stick and throttle input. The standard CIG X-56 profile still requires
user-specific binding adjustments. HIDRAW `uaccess` remains `candidate`
because the successful game test did not independently prove that mechanism
was causally required.

## Tested bundled X-56 manifest

The shortest supported X-56 configuration uses the bundled grouped manifest:

```nix
hardware.starCitizenInput = {
  enable = true;
  knownManifests = [ "saitek-x56-rhino" ];
  manifestFiles = [ ];
  diagnosticTools = true;
  gui = true;
};
```

The bundled manifest covers:

- stick `0738:2221`;
- throttle `0738:a221`.

Use the local-manifest path documented below only when you intentionally need a
reviewed custom copy. Do not enable the bundled and local manifests together
for the same VID:PID pairs.

Read the [X-56 functional validation](research/x56-functional-validation.md)
for the environment, evidence, support-state decision, and limitations.

## Three files, three different jobs

For the recommended modular NixOS layout, the integration is split across
three files:

| File | Purpose |
| --- | --- |
| `/etc/nixos/flake.nix` | Declares the GitHub input and imports the NixOS module |
| `/etc/nixos/hosts/nixos/configuration.nix` | Configures `hardware.starCitizenInput` |
| `/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json` | Stores the reviewed local manifest referenced by the host configuration |

Do not paste the Flake input, the `modules = [ ... ];` list, and the hardware
options into the same file.

## File 1: `/etc/nixos/flake.nix`

### Add the input inside `inputs = { ... };`

Open `/etc/nixos/flake.nix`. Find the existing top-level `inputs = { ... };`
attribute set and add `star-citizen-input` inside it:

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    # Keep all existing inputs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    star-citizen-input = {
      url = "github:ewilhelm1979-netizen/starcitizen-linux-input";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # The outputs block remains below in the same file.
}
```

The `star-citizen-input = { ... };` block belongs in `flake.nix`, not in
`configuration.nix`.

### Import the module in the same `flake.nix`

Still in `/etc/nixos/flake.nix`, find the existing
`nixosConfigurations.nixos = nixpkgs.lib.nixosSystem { ... };` block. Add the
module to that block's existing `modules = [ ... ];` list:

```nix
# /etc/nixos/flake.nix
{
  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      # Keep your existing specialArgs. They may contain hostname, username,
      # pkgsUnstable, or other project-specific values.
      specialArgs = { inherit inputs; };

      modules = [
        # Add this line exactly once.
        inputs.star-citizen-input.nixosModules.default

        # Keep the existing host configuration import.
        ./hosts/nixos/configuration.nix
      ];
    };
  };
}
```

Do not create another `modules = [ ... ];` list in
`/etc/nixos/hosts/nixos/configuration.nix`.

An advanced alternative is to import the module through the host
`configuration.nix` `imports` list when that file already receives `inputs`
through `specialArgs`. Choose one import location. Importing the same module in
both places is unnecessary. The examples in this guide use the clearer
`flake.nix` module list.

## File 2: `/etc/nixos/hosts/nixos/configuration.nix`

This file configures the module that `flake.nix` already imported. It does not
declare the GitHub input and does not define a `modules` list.

### Existing `hardware = { ... };` block

When `configuration.nix` already groups hardware options, add only
`starCitizenInput` inside that existing attribute set:

```nix
# /etc/nixos/hosts/nixos/configuration.nix
{
  # Existing imports and system configuration continue above.

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

    # Existing Bluetooth, graphics, NVIDIA, xpadneo, xone, controller,
    # scanner, and other hardware options continue here.
  };
}
```

Inside `hardware = { ... };`, do not write another
`hardware.starCitizenInput = { ... };` block.

### Configuration without a grouped `hardware` block

When the file does not already contain `hardware = { ... };`, use this
top-level equivalent:

```nix
# /etc/nixos/hosts/nixos/configuration.nix
hardware.starCitizenInput = {
  enable = true;
  knownManifests = [ ];
  manifestFiles = [
    ./manifests/saitek-x56-rhino-local.json
  ];
  diagnosticTools = true;
  gui = true;
};
```

Do not place this block inside `services`, `environment.systemPackages`, or a
Home Manager user configuration.

## File 3: the local manifest JSON

### Modular host layout

The examples above use this layout:

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

Because the relative path appears in
`/etc/nixos/hosts/nixos/configuration.nix`, this entry:

```nix
manifestFiles = [
  ./manifests/saitek-x56-rhino-local.json
];
```

resolves to exactly:

```text
/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json
```

Relative Nix paths are resolved relative to the Nix file that contains them.
For a Git-backed Flake, the manifest must also be tracked by Git before it is
included in the Flake source. A local path Flake only requires the file to
exist beneath the Flake root.

### Simple `/etc/nixos` layout

A smaller setup may instead use:

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
└── manifests/
    └── saitek-x56-rhino-local.json
```

In that layout, `./manifests/saitek-x56-rhino-local.json` written in
`/etc/nixos/configuration.nix` resolves to:

```text
/etc/nixos/manifests/saitek-x56-rhino-local.json
```

## Traditional `configuration.nix` without an existing Flake

A direct non-Flake module import is not currently part of the tested public
interface. Keep the existing `/etc/nixos/configuration.nix` and add a minimal
`/etc/nixos/flake.nix` wrapper using the examples above.

## Home Manager

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

For the modular host layout:

```console
sudo mkdir -p /etc/nixos/hosts/nixos/manifests
sudo cp "$manifest" /etc/nixos/hosts/nixos/manifests/
```

For the simple `/etc/nixos` layout:

```console
sudo mkdir -p /etc/nixos/manifests
sudo cp "$manifest" /etc/nixos/manifests/
```

Do not also select the bundled `saitek-x56-rhino` entry in `knownManifests`
when the local file describes the same stick and throttle. The module rejects
duplicate manifest selections and duplicate VID:PID pairs.

New GUI-created local manifests start with `unverified` support fields. That
safe default is independent of the reviewed support states in the bundled
manifest.

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
  --manifest "$(realpath /etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json)" \
  --json
```

For the simple layout, use the manifest below `/etc/nixos/manifests/` instead.
For the bundled path, replace `--manifest ...` with
`--known-manifest saitek-x56-rhino`.

A successful result confirms only native detection and access. It does not by
itself confirm Wine visibility, Star Citizen visibility, bindings, or gameplay.
Those later stages were separately confirmed in the maintainer X-56 reference
test.

In Star Citizen, verify that both devices are listed as enabled and connected,
then test axis movement and gameplay input. The standard CIG X-56 profile is a
working starting point but its mapping should be reviewed and adjusted.
Native `/dev/input/js*` numbers and in-game joystick numbers can differ and
must not be persisted in a manifest.

## Common NixOS errors

| Error or symptom | Likely cause | Check |
| --- | --- | --- |
| `hardware.starCitizenInput` does not exist | The NixOS module was not imported | Add `inputs.star-citizen-input.nixosModules.default` to the `nixosSystem` `modules` list in `/etc/nixos/flake.nix` |
| The Flake input is unknown | The input was added to the wrong file or outside `inputs` | Add `star-citizen-input = { ... };` inside the top-level `inputs = { ... };` block in `/etc/nixos/flake.nix` |
| Manifest file not found during evaluation | The relative path points to the wrong directory | Resolve it relative to the containing `configuration.nix` file |
| Manifest exists locally but not in a Git Flake source | The JSON is untracked | Add the manifest to Git before rebuilding |
| Duplicate VID:PID or duplicate manifest assertion | Local and bundled X-56 manifests are enabled together | Leave `knownManifests = [ ];` for the local X-56 file |
| GUI command is missing | The GUI package is not installed | Set `gui = true` or install it through Home Manager |
| Home Manager package works but access is unchanged | No NixOS system rule was installed | Configure the NixOS module and rebuild |
| Access is unchanged after a successful rebuild | Existing nodes predate the new rule | Reconnect both components or log out and back in |
| Native access succeeds but the game does not | A later diagnostic layer failed | Test Wine, game visibility, binding, and gameplay separately |
| X-56 works but the layout is wrong | The standard CIG profile is not tailored to the user | Review axes, inversion, curves, dead zones, and button bindings |

## Reference environment and interoperability

The documented SpaceMouse reference environment used
[nix-citizen](https://github.com/LovingMelody/nix-citizen), with the
`wine-astral` package supplied through that project. Citizen Input Manager's
own Flake and NixOS module do not require nix-citizen.

The X-56 validation used NixOS 26.05, Citizen Input Manager's NixOS module,
nix-citizen, an Astral Wine/Proton runtime, and the Star Citizen LIVE client.
Both physical components reached the game and produced usable input. See
[X-56 functional validation](research/x56-functional-validation.md).

Citizen Input Manager can be used alongside
[LUG Helper](https://github.com/starcitizen-lug/lug-helper) and nix-citizen
without automatically modifying either project, Wine, or launcher
configuration. The projects remain independently maintained.

For the full start-to-finish X-56 example, read [Getting started](getting-started.md).
