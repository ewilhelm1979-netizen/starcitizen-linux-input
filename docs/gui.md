# GUI and TUI

`sc-input-gui` is a thin frontend for the `sc-input` backend. Device discovery,
manifest creation, rule rendering, and diagnostics remain implemented by the
CLI.

## Requirements

The easiest launch path is:

```console
nix run github:ewilhelm1979-netizen/starcitizen-linux-input#gui
```

![Citizen Input Manager main menu with actions for discovery, device inspection, local manifest creation, diagnostics, and security information](images/gui/citizen-input-manager-main-menu.png)

*Citizen Input Manager main menu. Start with physical-device discovery or choose the local HOTAS manifest workflow.*

This packaged GUI requires only:

- Linux with Nix and Flakes enabled;
- a graphical desktop session;
- a connected controller for live discovery.

The package supplies the CLI, Zenity, and `dialog`. No separate installation of
`jq`, Python, libxml2, Udev tools, or Zenity is required when using this Nix
command.

For direct checkout execution, install the CLI dependencies documented in the
[Generic Linux guide](generic-linux.md) plus at least one frontend:

1. Zenity;
2. `dialog`;
3. `whiptail`.

Zenity provides the complete graphical manifest workflow. The TUI fallbacks
provide discovery, known-manifest guidance, rule/report command hints, and
security notices. Advanced manifest creation remains available through the CLI
when Zenity is unavailable.

## Backend selection

The frontend preference is:

1. Zenity;
2. `dialog`;
3. `whiptail`;
4. CLI guidance when none is available.

Inspect the selected backend with:

```console
sc-input-gui --backend-info
```

Every device and manifest result comes from `sc-input`, normally through
`discover --json`, `inspect --json`, or `manifest list --json`.

## Zenity workflow

The Zenity workflow provides:

- a read-only safety notice;
- physical-device discovery;
- multi-selection for HOTAS sets;
- device details;
- known-manifest selection;
- private local manifest creation with preview;
- rule preview;
- safe dry-run command display;
- native diagnosis;
- public report export.

### Create a multi-device HOTAS manifest

For a stick and throttle set, choose **Create local HOTAS manifest** and select
both physical components in the same device list.

Hold **Ctrl** while clicking non-adjacent rows. A focus outline alone does not
mean that a second row is selected; both selected rows should be visibly
highlighted.

![Sanitized physical-device selection showing the SpaceMouse and both Saitek X-56 components; runtime identifiers and unrelated device inventory are redacted](images/gui/citizen-input-manager-physical-devices-redacted.png)

*Selecting the X-56 throttle and stick together. Opaque bars cover ephemeral runtime IDs and unrelated local device inventory.*

Create one grouped manifest unless the components are intentionally managed as
independent controllers.

For an X-56 where the throttle row appears before the stick row:

```text
Safe slug id: saitek-x56-rhino-local
Display name: Saitek X-56 Rhino
Roles, comma-separated: throttle,stick
```

When the stick row appears first, use `stick,throttle`. The role order must
match the selected row order.

![Citizen Input Manager local manifest form with fields for a safe slug ID, display name, and ordered comma-separated roles](images/gui/citizen-input-manager-create-local-manifest.png)

*The local manifest form. All support fields intentionally start as `unverified`.*

Review the preview and confirm:

```text
0738:a221 -> throttle
0738:2221 -> stick
```

The `-local` suffix avoids a name collision with the bundled research
manifest. New local support states remain `unverified`.

The GUI stores the manifest under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

The saved file is not automatically installed into NixOS. Validate it, preview
the rule, and then follow the [Getting started guide](getting-started.md) or the
[NixOS guide](nixos.md).

## Screenshot privacy note

The screenshots in this guide are sanitized documentation assets. No username,
hostname, local path, password, token, device serial number, or Wine prefix is
shown. The public USB VID:PID values remain visible because they are part of the
documented hardware-identification workflow.

## Safety boundary

No GUI component accepts a free-form discovery command, stores a password,
starts a privilege helper, installs a rule, changes a permission, launches
Wine or Star Citizen, or edits a registry or binding.

The GUI can display a safe dry-run command, but every later system change
remains an explicit administrator action outside the GUI.
