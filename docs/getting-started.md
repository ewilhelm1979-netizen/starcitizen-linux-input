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

For a simple `/etc/nixos` layout:

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
└── manifests/
    └── saitek-x56-rhino-local.json
```

Copy the reviewed file:

```console
sudo mkdir -p /etc/nixos/manifests
sudo cp "$manifest" /etc/nixos/manifests/
```

For a modular host layout:

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

Copy the file next to the host configuration that references it:

```console
sudo mkdir -p /etc/nixos/hosts/nixos/manifests
sudo cp "$manifest" /etc/nixos/hosts/nixos/manifests/
```

A relative Nix path is resolved relative to the Nix file containing it. In the
modular example, `./manifests/saitek-x56-rhino-local.json` therefore resolves to
`/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json`.

For a Git-backed Flake, the copied manifest must also be tracked by Git before
Nix can include it in the Flake source. A local path Flake only requires the
file to exist beneath the Flake root.

### 6. Add the Flake input

Add the project to `inputs`:

```nix
star-citizen-input = {
  url = "github:ewilhelm1979-netizen/starcitizen-linux-input";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 7. Import the NixOS module exactly once

The common approach is to import it in the `nixosSystem` module list:

```nix
modules = [
  inputs.star-citizen-input.nixosModules.default
  ./hosts/nixos/configuration.nix
];
```

A modular `configuration.nix` that already receives `inputs` through
`specialArgs` may instead import it there:

```nix
imports = [
  ./hardware-configuration.nix
  inputs.star-citizen-input.nixosModules.default
];
```

Choose one import location. Importing the same module twice is unnecessary.

### 8. Configure the system module

At the top level of `configuration.nix`:

```nix
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

When the file already contains an attribute set such as `hardware = { ... };`,
place the option inside that set without repeating the `hardware.` prefix:

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

  # Other hardware options continue here.
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

Use `/etc/nixos/manifests/...` instead for the simple layout.

A successful native result proves only discovery and current access. Continue
with Wine, Star Citizen visibility, bindings, and gameplay as separate tests.

## Final checklist

Before treating the NixOS integration as complete, confirm:

- both stick and throttle are present in one manifest;
- roles match their USB identities;
- the manifest validates successfully;
- the rendered rules contain only exact HIDRAW `uaccess` matches;
- the NixOS module is imported exactly once;
- `manifestFiles` points to the correct relative file;
- the bundled X-56 manifest is not enabled at the same time;
- `nixos-rebuild dry-build` and `switch` succeed;
- both components were reconnected;
- native access was verified again;
- Wine and gameplay have not been inferred from the native result.

See [Troubleshooting](troubleshooting.md) when a step fails.
