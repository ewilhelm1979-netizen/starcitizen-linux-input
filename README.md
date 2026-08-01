# Star Citizen Linux Input

Citizen Input Manager is a security-focused Linux MVP for discovering,
grouping, diagnosing, and describing joysticks, HOTAS components, throttles,
rudder pedals, SpaceMouse devices, button boxes, and related USB HID input
hardware. Its command-line interface is `sc-input`; its graphical entry point
is `sc-input-gui`.

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
sc-input inspect --device usb-RUNTIME-ID --json
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

## Create a manifest

List runtime IDs, then create an unverified private local manifest:

```console
sc-input discover
sc-input manifest create \
  --devices usb-FIRST,usb-SECOND \
  --id my-hotas \
  --display-name 'My HOTAS' \
  --roles stick,throttle \
  --preview
```

Omit `--preview` only after reviewing the JSON. The default private location is
`${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests`.
Existing files are not overwritten. See [device manifests](docs/device-manifests.md).

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
targets, makes recoverable backups, and never reloads rules or triggers
devices. See [the generic Linux guide](docs/generic-linux.md).

## Support boundaries

- SpaceMouse Wireless USB `256f:c63a` is the tested reference: NixOS 26.05,
  Nix-Citizen, Astral Wine 11.12, Star Citizen LIVE 4.9.188.23497, six axes,
  flight and shared ground-vehicle movement, no drift or cross-axis input.
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
