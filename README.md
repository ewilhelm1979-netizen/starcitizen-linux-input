# Star Citizen Linux Input

Citizen Input Manager is a security-focused Linux MVP for discovering,
grouping, diagnosing, and describing joysticks, HOTAS components, throttles,
rudder pedals, SpaceMouse devices, button boxes, and related USB HID input
hardware. Its command-line interface is `sc-input`; its graphical entry point
is `sc-input-gui`.

![Citizen Input Manager architecture from Linux controller discovery to Wine and Star Citizen diagnostic stages](docs/images/citizen-input-manager-overview.svg)

Native hardware discovery is separate from Wine and game behavior. Citizen
Input Manager reports every diagnostic stage independently and never infers a
later status from native detection. Scoped Udev rendering addresses one access
boundary; it does not guarantee Wine visibility, binding, or gameplay.

Linux, Wine, and Star Citizen expose different input layers. A controller can
work through native event nodes and still lack the HIDRAW access or Windows
input path needed for an in-game binding. This project reports those layers
separately instead of inferring gameplay support from Linux detection.

## Architecture

- `sc-input` is the only device-discovery backend and provides JSON output.
- `sc-input-gui` consumes the backend JSON through Zenity, then `dialog` or
  `whiptail`; it contains no independent hardware-discovery code.
- Versioned JSON manifests describe stable USB identities and multi-device
  groups without runtime paths or serial numbers.
- The Udev renderer emits only device-scoped HIDRAW `uaccess` rules.
- The NixOS module reads the same manifest model and uses
  `services.udev.packages`.

See [the architecture document](docs/architecture.md) for the trust boundaries
and status pipeline.

## Related Star Citizen Linux projects

Citizen Input Manager complements the existing Star Citizen Linux community
tooling:

- [LUG Helper](https://github.com/starcitizen-lug/lug-helper) is the official
  installer maintained by the Star Citizen Linux Users Group and community. It
  covers broader installation, Wine-runner management, system preparation,
  maintenance, and general troubleshooting workflows.
- [nix-citizen](https://github.com/LovingMelody/nix-citizen) provides
  NixOS-oriented Star Citizen packages, including LUG Helper and the
  `wine-astral` package used in the documented SpaceMouse reference
  environment.

Citizen Input Manager focuses on a narrower input-device problem: controller
discovery, physical-device grouping, access verification, device-scoped Udev
rendering, privacy-aware reports, and separation of native Linux, Wine, Star
Citizen visibility, binding, and gameplay states.

These references are provided for attribution and technical context. Citizen
Input Manager is maintained independently; no affiliation or endorsement by
the LUG Helper or nix-citizen maintainers is implied.

## Security model

Discovery is bounded to `/sys/class/hidraw`, `/sys/class/input`, the matching
device nodes, and `/proc/bus/input/devices`. USB identity is confirmed by
walking at most 32 parents to readable `idVendor` and `idProduct` attributes.
Alternative roots work only in explicit test mode.

The project never grants global HIDRAW or input access, changes group
membership, writes persistent ACLs, launches Wine or Star Citizen, edits Wine
registry values, or changes controller bindings. Rendering a rule is not an
installation. A scoped rule can fix one permission boundary, but it cannot by
itself guarantee a usable Wine or Star Citizen input path.

Read [the full security model](docs/security-model.md) before using the
imperative installer code outside an isolated fixture.

## Read-only quick start

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- discover

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  manifest show 3dconnexion-spacemouse-wireless-usb

nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- \
  udev render --known-manifest 3dconnexion-spacemouse-wireless-usb
```

The third command only prints a rule. It does not write under `/etc`, reload
Udev, trigger hardware, or change a device permission.

## CLI examples

```console
sc-input discover --json
sc-input list
runtime_id=$(sc-input discover --json | jq -er '.devices[0].runtimeId')
sc-input inspect --device "$runtime_id" --json
sc-input manifest list --json
sc-input verify --known-manifest 3dconnexion-spacemouse-wireless-usb
sc-input verify --known-manifest 3dconnexion-spacemouse-wireless-usb \
  --confirm WINE_VISIBLE
sc-input report --known-manifest saitek-x56-rhino --privacy public
```

Every command has `--help` and documented exit codes. Runtime IDs identify one
physical device for the current discovery run only; they are never stored in a
manifest. Explicit `--confirm` states affect only the current output and are
never persisted.

## Citizen Input Manager GUI

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input#gui
# or
sc-input gui
```

The GUI can list and inspect devices, group multiple devices into a local
manifest, preview a manifest and Udev rule, display a safe dry-run command, and
export diagnostics. It never asks for a password and never performs a
privileged change. See [GUI behavior and fallbacks](docs/gui.md).

For a multi-component HOTAS, select every physical component in the device
list. With the Zenity interface, hold **Ctrl** while clicking non-adjacent rows
such as the throttle and stick. Create one grouped manifest for the complete
HOTAS set; separate manifests are needed only when the components should be
managed independently.

## Create a manifest

A manifest may describe either one physical device or a grouped set of HOTAS
components. Every selected device needs exactly one role, and the comma-separated
role list must follow the same order as the selected device rows.

### Single device

Select one discovered runtime ID, then create an unverified private local
manifest:

```console
runtime_id=$(sc-input discover --json | jq -er '.devices[0].runtimeId')
sc-input manifest create \
  --devices "$runtime_id" \
  --id my-controller \
  --display-name 'My Controller' \
  --roles controller \
  --preview
```

### Multi-device HOTAS in the GUI

For an X-56 set, select both physical components in the same device dialog:

- Saitek Pro Flight X-56 Rhino Throttle — `0738:a221`
- Saitek Pro Flight X-56 Rhino Stick — `0738:2221`

If the throttle row appears before the stick row, enter:

```text
Safe slug id: saitek-x56-rhino-local
Display name: Saitek X-56 Rhino
Roles, comma-separated: throttle,stick
```

If the stick row appears first, use `stick,throttle` instead. Review the
manifest preview and confirm that `0738:a221` maps to `throttle` and
`0738:2221` maps to `stick` before saving. The `-local` suffix avoids a naming
collision with the built-in `saitek-x56-rhino` research manifest. New local
support states remain `unverified` until they are confirmed separately.

Omit `--preview` only after reviewing the JSON. The default private location is
`${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests`.
Existing files are not overwritten. See [device manifests](docs/device-manifests.md).

### Use the local manifest on NixOS

The hardware integration is provided by a **NixOS system module**. The
`hardware.starCitizenInput` block belongs at the top level of the NixOS system
configuration, not inside `services`, `environment.systemPackages`, or a Home
Manager user module.

Home Manager may install the CLI or GUI for one user, but Home Manager alone
cannot install the required system Udev rules. Hardware access still requires
the NixOS module and `manifestFiles` in the system configuration.

For a simple Flake-based `/etc/nixos` layout, keep these files together:

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
└── manifests/
    └── saitek-x56-rhino-local.json
```

The Flake imports `star-citizen-input.nixosModules.default`, while
`/etc/nixos/configuration.nix` contains the top-level option block:

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

Because the path is relative to `configuration.nix`, the example expects the
manifest at `/etc/nixos/manifests/saitek-x56-rhino-local.json`.

Copy the reviewed GUI output into the configuration source:

```console
sudo mkdir -p /etc/nixos/manifests
sudo cp \
  "${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/saitek-x56-rhino-local.json" \
  /etc/nixos/manifests/
```

Do not also add `saitek-x56-rhino` to `knownManifests` when the local manifest
describes the same stick and throttle. The module rejects duplicate manifest
selections and duplicate VID:PID pairs.

Validate first, then switch:

```console
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

After rebuilding, reconnect both X-56 components so the scoped `uaccess` rules
apply to freshly enumerated HIDRAW nodes.

A traditional non-Flake import is not currently part of the tested public
interface. Existing `/etc/nixos/configuration.nix` users can keep that file and
add a minimal `/etc/nixos/flake.nix` wrapper. See the
[NixOS guide](docs/nixos.md) for the complete Flake-module and Home Manager
examples.

The module installs only the exact HIDRAW rules described by the manifest. It
does not change the local `unverified` support states or prove Wine visibility,
Star Citizen bindings, or gameplay.

## Udev rule preview

```console
sc-input udev render --known-manifest 3dconnexion-spacemouse-wireless-usb
sc-input udev render --known-manifest saitek-x56-rhino
```

The SpaceMouse rule is backed by a tested reference. The X-56 output is a
research candidate only. It does not claim to resolve the X-56 issue.

## NixOS

```nix
{
  inputs.star-citizen-input.url =
    "github:ewilhelm1979-netizen/starcitizen-linux-input";

  outputs = { nixpkgs, star-citizen-input, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        star-citizen-input.nixosModules.default
        {
          hardware.starCitizenInput.enable = true;
          hardware.starCitizenInput.knownManifests = [
            "3dconnexion-spacemouse-wireless-usb"
          ];
          hardware.starCitizenInput.gui = false;
        }
      ];
    };
  };
}
```

The module is disabled by default. Read [the NixOS guide](docs/nixos.md) before
enabling a manifest.

## Generic Linux

Use `discover`, `verify`, and `udev render` first. The imperative installer has
`--dry-run`, performs no automatic privilege escalation, rejects symlink
and hard-linked targets, makes recoverable backups, rolls back interrupted or
failed publication, and never reloads rules or triggers devices. See [the
generic Linux guide](docs/generic-linux.md).

## Support boundaries

- SpaceMouse Wireless USB `256f:c63a` is the tested reference: NixOS 26.05,
  Nix-Citizen, Astral Wine 11.12, Star Citizen LIVE 4.9.188.23497, six axes,
  flight and shared ground-vehicle movement, no drift or cross-axis input.
  Bluetooth and Universal Receiver operation remain unverified and may use
  different USB identities or presentation paths.
- X-56 stick `0738:2221` and throttle `0738:a221` are a research case. Linux and
  `joy.cpl` visibility were reported, but in-game input remained unreliable and
  Ghost controllers were observed across DInput and Windows.Gaming.Input.
- The tool does not change Wine registry settings, Wine runners, or Star Citizen
  bindings. It does not create or distribute Star Citizen controller profiles.

Read the [support matrix](docs/support-matrix.md), the
[SpaceMouse case study](docs/research/spacemouse-case-study.md), and the
[X-56 research summary](docs/research/nix-citizen-issue-108.md).

Public references:

- [SpaceMouse reference project](https://github.com/ewilhelm1979-netizen/spacemouse)
- [LovingMelody/nix-citizen issue #108](https://github.com/LovingMelody/nix-citizen/issues/108)

This project is not affiliated with Cloud Imperium Games, Logitech, Saitek,
3Dconnexion, WinWing, or any other hardware manufacturer.

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
