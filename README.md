# Star Citizen Linux Input

Citizen Input Manager is a security-focused Linux tool for discovering,
grouping, diagnosing, and describing joysticks, HOTAS components, throttles,
rudder pedals, SpaceMouse devices, button boxes, and related USB HID input
hardware. Its command-line interface is `sc-input`; its graphical entry point
is `sc-input-gui`.

![Citizen Input Manager architecture from Linux controller discovery to Wine and Star Citizen diagnostic stages](docs/images/citizen-input-manager-overview.svg)

Native hardware discovery is separate from Wine and game behavior. Citizen
Input Manager reports every diagnostic stage independently and never infers a
later status from native detection. Scoped Udev rendering addresses one access
boundary; it does not guarantee Wine visibility, binding, or gameplay.

## Prerequisites and installation paths

| Goal | Required | Not required at this stage |
| --- | --- | --- |
| Read-only CLI with `nix run` | Linux, Nix, Flakes enabled, connected USB HID controller | Root, Wine, Star Citizen, Home Manager, LUG Helper, nix-citizen |
| Packaged GUI | Same as above plus a graphical desktop session | Manual installation of Zenity, `jq`, Python, or Udev tools |
| NixOS hardware integration | NixOS Flake configuration, NixOS system module, known or local manifest, root for `nixos-rebuild` | Home Manager is optional and cannot replace the system module |
| Home Manager package installation | Home Manager and the Flake input | System Udev rules; those still require the NixOS module |
| Direct Git checkout | Bash and the command set documented for generic Linux | This is the advanced path; Nix packaging is recommended |

When used through Nix, the package supplies its runtime dependencies,
including the `acl`, coreutils, findutils, `gawk`, grep, sed, `jq`, libxml2,
Python, systemd/Udev, and util-linux command sets. The GUI package also supplies
Zenity and `dialog`.

Wine and Star Citizen are required only for their later diagnostic stages.
LUG Helper and nix-citizen are related community projects, not runtime
dependencies of Citizen Input Manager.

Start with the complete [Getting started guide](docs/getting-started.md). It
covers prerequisites, GUI manifest creation, simple and modular NixOS layouts,
Home Manager boundaries, rebuilds, and post-installation verification.

## Architecture

- `sc-input` is the only device-discovery backend and provides JSON output.
- `sc-input-gui` consumes backend JSON through Zenity, then `dialog` or
  `whiptail`; it contains no independent hardware-discovery code.
- Versioned JSON manifests describe stable USB identities and multi-device
  groups without runtime paths or serial numbers.
- The Udev renderer emits only device-scoped HIDRAW `uaccess` rules.
- The NixOS module reads the same manifest model and uses
  `services.udev.packages`.

See [Architecture](docs/architecture.md) for trust boundaries and the status
pipeline.

## Security model

Discovery is bounded to `/sys/class/hidraw`, `/sys/class/input`, matching device
nodes, and `/proc/bus/input/devices`. USB identity is confirmed by walking at
most 32 parents to readable `idVendor` and `idProduct` attributes.

The project never grants global HIDRAW or input access, changes group
membership, writes persistent ACLs, launches Wine or Star Citizen, edits Wine
registry values, or changes controller bindings. Rendering a rule is not an
installation.

Read [Security model](docs/security-model.md) before using imperative installer
code outside an isolated fixture.

## Read-only quick start

No repository clone is required:

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- discover

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  manifest show 3dconnexion-spacemouse-wireless-usb

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  udev render --known-manifest 3dconnexion-spacemouse-wireless-usb
```

The third command only prints a rule. It does not write under `/etc`, reload
Udev, trigger hardware, or change a device permission.

## Citizen Input Manager GUI

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input#gui
```

The packaged GUI supplies the CLI, Zenity, and `dialog`. It can list and
inspect devices, group multiple devices into a local manifest, preview the
manifest and Udev rule, display a safe dry-run command, run native diagnosis,
and export a public report. It never asks for a password or performs a
privileged change.

For a multi-component HOTAS, hold **Ctrl** while selecting non-adjacent device
rows such as the throttle and stick. Create one grouped manifest for the
complete set. See [GUI and TUI](docs/gui.md).

## Create a manifest

A manifest may describe one physical device or a grouped set of HOTAS
components. Every selected device requires one unique role, and role order must
match the selected device order.

### Single device

```console
runtime_id=$(sc-input discover --json | jq -er '.devices[0].runtimeId')

sc-input manifest create \
  --devices "$runtime_id" \
  --id my-controller \
  --display-name 'My Controller' \
  --roles controller \
  --preview
```

### X-56 stick and throttle

Select both devices in the same GUI dialog:

- throttle: `0738:a221`;
- stick: `0738:2221`.

If the throttle row appears first:

```text
Safe slug id: saitek-x56-rhino-local
Display name: Saitek X-56 Rhino
Roles, comma-separated: throttle,stick
```

If the stick row appears first, use `stick,throttle`. Confirm the mapping in the
preview before saving. The local support states remain `unverified`.

The GUI saves private local manifests under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

Read [Device manifests](docs/device-manifests.md) for validation and storage
rules.

## Use a local manifest on NixOS

Hardware access is provided by the **NixOS system module**. Home Manager may
install the CLI or GUI, but it cannot install the system Udev rules by itself.

### Simple `/etc/nixos` layout

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
└── manifests/
    └── saitek-x56-rhino-local.json
```

### Modular host layout

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

A path such as `./manifests/saitek-x56-rhino-local.json` is resolved relative
to the Nix file containing it.

Add the input:

```nix
star-citizen-input = {
  url = "github:ewilhelm1979-netizen/starcitizen-linux-input";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the module exactly once, normally in the system module list:

```nix
modules = [
  inputs.star-citizen-input.nixosModules.default
  ./hosts/nixos/configuration.nix
];
```

A host configuration that already receives `inputs` through `specialArgs` may
instead import it through its `imports` list.

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

When an existing `hardware = { ... };` block is present, place only
`starCitizenInput = { ... };` inside it.

Do not also enable the bundled `saitek-x56-rhino` manifest when the local file
describes the same USB identities.

Validate, switch, and reconnect the controller components:

```console
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Then verify native discovery and access again. Read [NixOS](docs/nixos.md) for
the complete Flake, modular host, Home Manager, and troubleshooting examples.

## Udev rule preview

```console
sc-input udev render --known-manifest 3dconnexion-spacemouse-wireless-usb
sc-input udev render --known-manifest saitek-x56-rhino
```

The SpaceMouse rule is backed by a tested reference. The bundled X-56 output is
a research candidate only and does not claim to resolve the X-56 issue.

## Diagnostic stages

Citizen Input Manager keeps the following states separate:

1. native Linux detection;
2. effective native access;
3. Wine visibility;
4. Star Citizen visibility;
5. binding confirmation;
6. gameplay confirmation.

Use [Wine diagnostics](docs/wine-diagnostics.md) and
[Star Citizen diagnostics](docs/star-citizen-diagnostics.md) only after native
discovery and access are understood.

## Generic Linux

The Nix package is the recommended dependency-complete path. Direct checkout
execution requires the commands listed in [Generic Linux](docs/generic-linux.md).
The imperative installer performs no privilege escalation, Udev reload, or
device trigger.

## Related Star Citizen Linux projects

Citizen Input Manager complements the existing Star Citizen Linux community
tooling:

- [LUG Helper](https://github.com/starcitizen-lug/lug-helper) is the official
  installer maintained by the Star Citizen Linux Users Group and community. It
  covers broader installation, Wine-runner management, system preparation,
  maintenance, and general troubleshooting workflows.
- [nix-citizen](https://github.com/LovingMelody/nix-citizen) provides
  NixOS-oriented Star Citizen packages, including LUG Helper and
  `wine-astral`.

Citizen Input Manager is maintained independently; no affiliation or
endorsement by the LUG Helper or nix-citizen maintainers is implied.

## Support boundaries

- SpaceMouse Wireless USB `256f:c63a` is the tested reference: NixOS 26.05,
  nix-citizen, Astral Wine 11.12, Star Citizen LIVE 4.9.188.23497, six axes,
  flight and shared ground-vehicle movement, no drift or cross-axis input.
  Bluetooth and Universal Receiver operation remain unverified.
- X-56 stick `0738:2221` and throttle `0738:a221` remain a research case.
  Linux and `joy.cpl` visibility were reported, but in-game input remained
  unreliable and Ghost controllers were observed.
- The tool does not change Wine registry settings, Wine runners, or Star
  Citizen bindings and does not distribute controller profiles.

Read [Support matrix](docs/support-matrix.md), the
[SpaceMouse case study](docs/research/spacemouse-case-study.md), and the
[X-56 research summary](docs/research/nix-citizen-issue-108.md).

## Documentation

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Security model](docs/security-model.md)
- [GUI and TUI](docs/gui.md)
- [Device manifests](docs/device-manifests.md)
- [NixOS](docs/nixos.md)
- [Generic Linux](docs/generic-linux.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Wine diagnostics](docs/wine-diagnostics.md)
- [Star Citizen diagnostics](docs/star-citizen-diagnostics.md)
- [Support matrix](docs/support-matrix.md)

## Development

```console
nix develop
tests/run.sh
nix flake check --no-write-lock-file
nix build .#packages.x86_64-linux.default
nix build .#packages.x86_64-linux.gui
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## AI-assisted development

This project was developed with substantial assistance from OpenAI Codex.
The human maintainer remains responsible for architecture, implementation
review, security decisions, testing, licensing, provenance, and releases.

## License

GPL-3.0-only. The original [LICENSE](LICENSE) file remains unchanged.
