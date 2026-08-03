# Device manifests

Manifests are JSON documents with `schemaVersion: 1`. They describe stable USB
identities and logical controller roles without storing runtime device paths or
private hardware identifiers.

## Manifest contents

A manifest contains:

- a safe slug ID;
- a display name and description;
- one or more uniquely named roles;
- exact lowercase USB VID:PID pairs;
- expected node types;
- the access policy;
- support states;
- public references.

Allowed support values are `tested`, `reported`, `candidate`, `unverified`, and
`unsupported`. New local manifests default every support field to
`unverified`. The only version-one access policy is HIDRAW `uaccess` with input
nodes in `verify-only` mode.

Manifest files are limited to 256 KiB, must be NUL-free UTF-8 JSON, may nest at
most 32 levels, and must contain every documented key exactly once. Duplicate
JSON keys, duplicate roles, duplicate VID:PID pairs, and unknown keys are
rejected.

Persistent manifests must not contain:

- runtime IDs;
- device node numbers;
- sysfs paths or USB port paths;
- serial numbers;
- usernames or hostnames;
- home-directory paths;
- shell fragments;
- executable fields.

Validation rejects unknown fields, unsafe slugs, malformed hexadecimal IDs,
absolute paths inside the JSON, and unknown policies.

## Single-device and grouped manifests

One manifest may describe one physical controller or a grouped HOTAS set.
Every selected physical device needs exactly one unique role.

For a multi-device GUI workflow, the comma-separated role list must follow the
same order as the selected rows. For example:

```text
0738:a221 -> throttle
0738:2221 -> stick
```

requires:

```text
Roles, comma-separated: throttle,stick
```

Use one grouped manifest for a stick and throttle that should be managed as one
HOTAS set. Create separate manifests only when the devices should be managed
independently.

## Create a manifest

`manifest create` uses `jq` for safe JSON construction. Preview the generated
document before saving it.

Example for one discovered device:

```console
runtime_id=$(sc-input discover --json | jq -er '.devices[0].runtimeId')

sc-input manifest create \
  --devices "$runtime_id" \
  --id my-controller \
  --display-name 'My Controller' \
  --roles controller \
  --preview
```

The Zenity GUI can select multiple physical devices and create a grouped local
manifest. See [GUI and TUI](gui.md).

## Storage and file permissions

Local storage defaults to:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/
```

New directories and files are private, and existing files are never silently
replaced.

The XDG copy is appropriate for local inspection. A NixOS system configuration
should evaluate a reviewed copy below the Flake root rather than a mutable file
in the user's home directory.

## Validate and render

The CLI accepts either a bundled manifest ID or an absolute path.
Local paths must be absolute and canonical:

```console
manifest="${XDG_DATA_HOME:-$HOME/.local/share}/starcitizen-linux-input/manifests/saitek-x56-rhino-local.json"
manifest="$(realpath "$manifest")"

sc-input manifest validate "$manifest"
sc-input manifest show "$manifest"
sc-input udev render --manifest "$manifest"
```

Rendering is read-only. It prints the exact scoped HIDRAW rules and does not
install, reload, or trigger anything.

## Use a local manifest on NixOS

Copy the reviewed JSON into the NixOS configuration source and reference it
through `hardware.starCitizenInput.manifestFiles`.

Simple layout:

```text
/etc/nixos/manifests/saitek-x56-rhino-local.json
```

Modular host layout:

```text
/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json
```

The relative path in `configuration.nix` depends on the layout:

```nix
manifestFiles = [
  ./manifests/saitek-x56-rhino-local.json
];
```

Do not enable the bundled `saitek-x56-rhino` manifest at the same time when the
local file describes the same X-56 stick and throttle. The module rejects
duplicate VID:PID selections.

For the complete process, including Flake input, module import, rebuild, and
post-rebuild verification, read [Getting started](getting-started.md) and the
[NixOS guide](nixos.md).
