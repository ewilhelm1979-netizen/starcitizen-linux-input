# Getting started

This guide covers the complete path from first read-only discovery to a local
multi-device HOTAS manifest and NixOS system integration.

Citizen Input Manager deliberately separates these stages:

1. native Linux discovery;
2. effective native access;
3. Wine visibility;
4. Star Citizen visibility;
5. binding confirmation;
6. gameplay confirmation.

A successful earlier stage never proves a later one.

## Prerequisites

Choose the path that matches what you want to do:

| Goal | Required | Provided automatically | Optional or not required |
| --- | --- | --- | --- |
| Try read-only discovery with `nix run` | Linux, Nix, Flakes enabled, connected USB HID controller | CLI and its runtime tools | Root, Wine, Star Citizen, Home Manager, LUG Helper, and nix-citizen are not required |
| Start the packaged GUI | Same as above plus a graphical desktop session | CLI, Zenity, and `dialog` | `whiptail` is only an additional fallback |
| Apply manifest rules on NixOS | NixOS, a Flake-based system configuration, the NixOS module, a known or local manifest, and root access for `nixos-rebuild` | CLI, optional GUI, validation, and scoped Udev rule generation | Home Manager is optional and cannot replace the system module |
| Install CLI or GUI through Home Manager | Home Manager with the Flake input available | User-level packages | Home Manager alone cannot install the system Udev rules |
| Run directly from a Git checkout | Bash and the command set listed under [Generic Linux](generic-linux.md) | Nothing is wrapped automatically | This is the advanced path; the packaged Nix path is recommended |

When installed through Nix, the CLI wrapper supplies the required runtime tools,
including the `acl`, coreutils, findutils, `gawk`, grep, sed, `jq`, libxml2,
Python, systemd/Udev, and util-linux command sets. The GUI package also supplies
Zenity and `dialog`. You do not need to install those tools manually when using
`nix run`, the Nix package, or the NixOS module.

Wine and Star Citizen are not prerequisites for discovery, manifest creation,
manifest validation, Udev rendering, or native access verification. They are
needed only when you move on to the Wine and game-specific diagnostic stages.
LUG Helper and nix-citizen are related community projects, not runtime
dependencies of Citizen Input Manager.

## Choose an installation path

### Read-only trial with Nix

No repository clone is required:

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- discover
nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- list
```

For the graphical interface:

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input#gui
```

These commands do not install Udev rules, change permissions, start Wine, or
modify Star Citizen.

### NixOS system integration

Use the NixOS module when you need the manifest-derived HIDRAW `uaccess` rules.
The module is the supported component for system-level hardware access.

Read the complete [NixOS guide](nixos.md) before rebuilding.

### Home Manager

Home Manager can install the CLI and GUI for one user. It cannot configure
`services.udev.packages` and cannot apply the system HIDRAW rules by itself.
Use Home Manager only for package placement; keep `manifestFiles` and hardware
access in the NixOS system module.

### Generic Linux

The packaged Nix path is the easiest way to receive all dependencies. Direct
checkout execution and imperative rule installation are advanced workflows.
See the [Generic Linux guide](generic-linux.md).

## Complete X-56 workflow

The X-56 remains a research case. This workflow creates and applies a narrowly
scoped local manifest; it does not claim that Wine or Star Citizen gameplay is
fixed.

### 1. Connect both physical components

Connect the stick and throttle before starting discovery. The expected USB
identities are:

- throttle: `0738:a221`;
- stick: `0738:2221`.

### 2. Start the GUI and select both devices

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input#gui
```

Choose **Create local HOTAS manifest**. In the Zenity device list, hold **Ctrl**
while selecting the throttle and stick rows. Create one grouped manifest for
the complete HOTAS set.

If the throttle row appears before the stick row, use:

```text
Safe slug id: saitek-x56-rhino-local
Display name: Saitek X-56 Rhino
Roles, comma-separated: throttle,stick
```

If the stick row appears first, use `stick,throttle`. The role order must match
the selected row order.

### 3. Review and save the manifest

Confirm in the preview that:

```text
0738:a221 -> throttle
0738:2221 -> stick
```

The GUI stores the file privately under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

New local support states remain `unverified`.

### 4. Validate the saved JSON and preview the rule

The CLI requires an absolute path for a local manifest:

```console
manifest="${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/saitek-x56-rhino-local.json"
manifest="$(realpath "$manifest")"

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  manifest validate "$manifest"

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  udev render --manifest "$manifest"
```

The preview should contain exactly one scoped HIDRAW rule for each X-56 USB
identity. Rendering changes nothing.

### 5. Copy the manifest into the NixOS configuration source

For the modular layout used in the following example:

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

Copy the reviewed file next to the host configuration that references it:

```console
sudo mkdir -p /etc/nixos/hosts/nixos/manifests
sudo cp "$manifest" /etc/nixos/hosts/nixos/manifests/
```

A relative Nix path is resolved relative to the Nix file containing it. In this
example, `./manifests/saitek-x56-rhino-local.json` written in
`/etc/nixos/hosts/nixos/configuration.nix` therefore resolves to:

```text
/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json
```

For a Git-backed Flake, the copied manifest must also be tracked by Git before
Nix can include it in the Flake source. A local path Flake only requires the
file to exist beneath the Flake root.

### 6. Edit `/etc/nixos/flake.nix`: add the input

The Flake input belongs in `/etc/nixos/flake.nix`, inside the existing top-level
`inputs = { ... };` block. It does not belong in `configuration.nix`.

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

  # outputs continues below in the same file.
}
```

Only add the `star-citizen-input = { ... };` attribute to your existing
`inputs` set. Do not replace the other inputs.

### 7. Edit the same `/etc/nixos/flake.nix`: import the module

Still in `/etc/nixos/flake.nix`, find the existing
`nixosConfigurations.nixos = nixpkgs.lib.nixosSystem { ... };` definition and
add the module line inside its existing `modules = [ ... ];` list:

```nix
# /etc/nixos/flake.nix
{
  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      # Keep your existing specialArgs.
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

Do not add a second `modules = [ ... ];` block to
`/etc/nixos/hosts/nixos/configuration.nix`. The module is imported once in
`flake.nix` for this recommended layout.

An advanced alternative is to import the module through the host
`configuration.nix` `imports` list when that file already receives `inputs`
through `specialArgs`. Use one method only. The example above uses the clearer
`flake.nix` module list.

### 8. Edit `/etc/nixos/hosts/nixos/configuration.nix`

This file configures the already imported module. It does not declare the Flake
input and does not create a `modules` list.

When the file already contains `hardware = { ... };`, add
`starCitizenInput = { ... };` inside that existing attribute set:

```nix
# /etc/nixos/hosts/nixos/configuration.nix
{
  # Existing system configuration continues above.

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

    # Existing Bluetooth, NVIDIA, graphics, xpadneo, xone, and scanner
    # configuration continues here.
  };
}
```

Inside `hardware = { ... };`, do not repeat the prefix as
`hardware.starCitizenInput`.

When no grouped `hardware = { ... };` block exists, this top-level form is
equivalent:

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

Do not place the block inside `services`, `environment.systemPackages`, or a
Home Manager user configuration.

Do not also enable the bundled `saitek-x56-rhino` in `knownManifests` when the
local manifest describes the same two USB identities. Duplicate selections and
duplicate VID:PID pairs are rejected.

### 9. Validate and rebuild

Replace `nixos` with the actual name under `nixosConfigurations` when needed:

```console
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

After a successful switch, disconnect and reconnect both X-56 components so
the new rules apply to freshly enumerated HIDRAW nodes.

### 10. Verify native detection and access

The NixOS module installs the CLI system-wide unless you chose a different
package path:

```console
sc-input discover --json

sc-input verify \
  --manifest "$(realpath /etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json)" \
  --json
```

A successful native result proves only discovery and current access. Continue
with Wine, Star Citizen visibility, bindings, and gameplay as separate tests.

## Final checklist

Before treating the NixOS integration as complete, confirm:

- both stick and throttle are present in one manifest;
- roles match their USB identities;
- the manifest validates successfully;
- the rendered rules contain only exact HIDRAW `uaccess` matches;
- `/etc/nixos/flake.nix` contains the input inside `inputs = { ... };`;
- `/etc/nixos/flake.nix` imports the module once in the `nixosSystem` modules list;
- `/etc/nixos/hosts/nixos/configuration.nix` contains the `starCitizenInput` options;
- `manifestFiles` points to the JSON beside that host configuration;
- the bundled X-56 manifest is not enabled at the same time;
- `nixos-rebuild dry-build` and `switch` succeed;
- both components were reconnected;
- native access was verified again;
- Wine and gameplay have not been inferred from the native result.

See [Troubleshooting](troubleshooting.md) when a step fails.
