# Troubleshooting

## Quick symptom table

| Symptom | Likely cause | Next check |
| --- | --- | --- |
| `sc-input` is not found | The CLI package is not installed | Use `nix run ... -- COMMAND`, enable the NixOS module, or install the package through Home Manager |
| The GUI does not start | No graphical session or frontend is available | Use the packaged `#gui` app, check `sc-input-gui --backend-info`, or use the CLI |
| `hardware.starCitizenInput` does not exist | The NixOS module was not imported | Add `nixosModules.default` to the system module list exactly once |
| Nix cannot find the manifest | The relative path is resolved from a different `.nix` file | Locate the containing Nix file and place the JSON in its relative `manifests/` directory |
| A Git-backed Flake ignores the manifest | The JSON is not tracked by Git | Add it to Git before rebuilding |
| Duplicate VID:PID assertion | The local and bundled X-56 manifests are enabled together | Leave `knownManifests = [ ];` when using the local X-56 file |
| Home Manager installed the GUI but access did not change | Home Manager does not install system Udev rules | Configure the NixOS system module and rebuild |
| Access is unchanged after a successful rebuild | Existing device nodes predate the new rule | Disconnect and reconnect the affected controller components |
| Linux access succeeds but Wine or the game does not | A later diagnostic layer failed | Check Wine visibility, Star Citizen visibility, bindings, and gameplay separately |

## A required command is missing

The recommended `nix run`, Nix package, and NixOS module paths supply the CLI
runtime commands automatically. Direct checkout execution requires the command
set listed in the [Generic Linux guide](generic-linux.md).

For the GUI, the packaged Nix app supplies Zenity and `dialog`. A direct
checkout needs Zenity, `dialog`, or `whiptail` installed separately.

## `hardware.starCitizenInput` is unknown

The system module was not imported. Import it in one place:

```nix
modules = [
  inputs.star-citizen-input.nixosModules.default
  ./hosts/nixos/configuration.nix
];
```

Or, when `inputs` is passed through `specialArgs`, import it from the host
configuration:

```nix
imports = [
  ./hardware-configuration.nix
  inputs.star-citizen-input.nixosModules.default
];
```

Do not add the same module in both places unnecessarily.

## The manifest path is wrong

Relative Nix paths are resolved relative to the file that contains them.

For:

```text
/etc/nixos/configuration.nix
```

this path:

```nix
./manifests/saitek-x56-rhino-local.json
```

means:

```text
/etc/nixos/manifests/saitek-x56-rhino-local.json
```

For:

```text
/etc/nixos/hosts/nixos/configuration.nix
```

it means:

```text
/etc/nixos/hosts/nixos/manifests/saitek-x56-rhino-local.json
```

A Git-backed Flake includes only tracked source files. Add the JSON to Git before
rebuilding. A local path Flake only requires the file beneath the Flake root.

## The option is inside an existing `hardware` block

At top level, this is valid:

```nix
hardware.starCitizenInput = {
  enable = true;
};
```

Inside an existing `hardware = { ... };` block, use:

```nix
hardware = {
  starCitizenInput = {
    enable = true;
  };
};
```

Do not repeat `hardware.` inside the nested attribute set.

## Duplicate X-56 manifest or VID:PID error

A local X-56 manifest and the bundled `saitek-x56-rhino` manifest describe the
same stick and throttle identities. Select only one source:

```nix
hardware.starCitizenInput = {
  enable = true;
  knownManifests = [ ];
  manifestFiles = [
    ./manifests/saitek-x56-rhino-local.json
  ];
};
```

## Local CLI says the manifest path is invalid

Local manifest commands require an absolute canonical path:

```console
manifest="$(realpath ./saitek-x56-rhino-local.json)"
sc-input manifest validate "$manifest"
sc-input udev render --manifest "$manifest"
```

## Stick and throttle were saved separately

For a normal X-56 HOTAS set, create one grouped manifest. In the Zenity device
list, hold **Ctrl** and select both physical rows. The roles must follow the row
order.

If the throttle row is first:

```text
Roles, comma-separated: throttle,stick
```

If the stick row is first:

```text
Roles, comma-separated: stick,throttle
```

Review the manifest preview before saving.

## A device is absent from discovery

Confirm that Linux created a HIDRAW, event, or joystick class entry and that its
USB ancestor exposes valid `idVendor` and `idProduct` attributes. Discovery does
not trust leaf-node Udev properties alone. A malformed or escaping class link
causes a fail-closed error.

## Multiple identical devices are reported

Runtime IDs can distinguish physical devices for the current run, but a pure
VID:PID rule applies to all identical units. Review the warning and do not store
a serial number as a hidden workaround. Single-device manifest creation fails
closed when an identical unit was omitted.

## Native access succeeds but the game does not

Check each layer independently:

1. native detection;
2. effective native access;
3. Wine visibility;
4. Star Citizen visibility;
5. binding confirmation;
6. gameplay confirmation.

A scoped Udev rule does not repair Wine presentation, Ghost controllers, XML
tokens, or game bindings.

## Event or joystick access is missing

The diagnosis reports the node and effective access. The standard renderer does
not widen input-subsystem access. Inspect the distribution's normal seat and
input-device policy instead.

## A report is intended for a public issue

Use the default `--privacy public`, inspect the result, and share only the
minimal relevant report. Never attach a complete Game.log, exported profile,
registry dump, or environment listing.

Read [Getting started](getting-started.md) for the complete installation flow.
