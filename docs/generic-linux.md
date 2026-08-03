# Generic Linux

The packaged Nix path is recommended because it supplies the CLI and its
runtime dependencies together. A direct checkout is possible for advanced
users, but the repository does not install dependencies automatically.

## Prerequisites

### Packaged Nix path

Required:

- Linux;
- Nix with Flakes enabled;
- a connected USB HID controller for live discovery.

The Nix package supplies the runtime command sets used by the CLI:

- `acl` utilities;
- coreutils and findutils;
- `gawk`, grep, and sed;
- `jq`;
- libxml2 tools such as `xmllint`;
- Python 3;
- systemd/Udev tools such as `udevadm`;
- util-linux tools such as `realpath`.

Use read-only discovery without installing anything permanently:

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input -- discover
```

The packaged GUI also supplies Zenity and `dialog`:

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input#gui
```

### Direct checkout path

Running `bin/sc-input` directly requires Bash plus equivalent commands from the
packages listed above. The GUI additionally requires one supported interface:

1. Zenity;
2. `dialog`;
3. `whiptail`.

Zenity provides the complete graphical manifest workflow. The TUI fallbacks
provide a smaller command-guidance interface; advanced manifest creation
remains available through the CLI.

Package names differ between distributions. Verify the required commands
rather than assuming a particular package-manager name.

Wine, Star Citizen, LUG Helper, nix-citizen, and Home Manager are not required
for native discovery, manifest creation, rule rendering, or native access
verification.

## Read-only start

Start with discovery and diagnostics:

```console
sc-input discover
sc-input list
sc-input verify --known-manifest 3dconnexion-spacemouse-wireless-usb
sc-input udev render --known-manifest 3dconnexion-spacemouse-wireless-usb
```

For a local manifest, the CLI requires an absolute path:

```console
manifest="$(realpath ./my-controller.json)"
sc-input manifest validate "$manifest"
sc-input udev render --manifest "$manifest"
sc-input verify --manifest "$manifest" --json
```

Rendering prints a deterministic rule and changes nothing. Review every
VID:PID against the physical hardware before considering installation.

## Imperative installation

The imperative installer is deliberately separate from the renderer. It has a
dry-run, accepts an alternate root only in explicit test mode, rejects symlink
directories plus symlinked or hard-linked targets, backs up existing files,
writes a same-directory temporary file, rechecks the destination immediately
before replacement, and uses file mode `0644`. Failure injection and INT, TERM,
or HUP after publication restore the previous target.

It does not invoke a privilege helper, reload Udev, or trigger a device.

Preview the exact operation first:

```console
sc-input udev install --manifest "$manifest" --dry-run
```

On a real system, an administrator must invoke the final installation from an
already authenticated UID-0 shell. After a deliberate installation, reload
only the relevant rules and then disconnect and reconnect the selected
controller, or log out and back in. Never trigger all devices. Those
real-system steps are not part of automated tests or the GUI.

NixOS users should prefer the declarative [NixOS module](nixos.md) rather than
the imperative installer.

## Access boundaries

Missing event or joystick access is reported. The standard path never creates
an input-subsystem rule; investigate the distribution's normal seat and
input-device policy instead of widening access globally.

A successful native result does not prove Wine visibility, Star Citizen
visibility, binding, or gameplay. Test those stages independently.

See [Getting started](getting-started.md) for the complete workflow and
[Troubleshooting](troubleshooting.md) for common failures.
