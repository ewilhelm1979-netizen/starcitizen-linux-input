# X-56 functional validation

## Validation result

On 2026-08-03, the human maintainer completed a live end-to-end test of the
Saitek/Mad Catz X-56 Rhino HOTAS with Citizen Input Manager on NixOS.

The tested USB identities were:

- stick: `0738:2221`;
- throttle: `0738:a221`.

Both components were detected separately by native Linux tools, presented to
the Wine runtime, listed by Star Citizen as enabled and connected controllers,
and used successfully in game. Stick and throttle axes responded, and the
controls were usable after loading the standard CIG X-56 profile.

The standard CIG profile was sufficient to prove input, but its default mapping
was not optimal and still requires user-specific binding adjustments. That is a
profile-layout limitation, not a device-detection failure.

## Tested environment

The validation used the maintainer's reference workstation with:

- NixOS 26.05;
- Citizen Input Manager through its NixOS module;
- nix-citizen and an Astral Wine/Proton runtime;
- the Star Citizen LIVE client;
- one grouped X-56 stick-and-throttle manifest.

The test did not modify Wine registry values, inject a controller profile from
this repository, or add broad input-device permissions.

## Evidence observed

Native controller inspection showed both physical X-56 components with their
own joystick nodes. Axis and button activity was visible for the stick and the
throttle.

The Star Citizen controller list showed both devices as separate, enabled, and
connected joystick instances. The in-game joystick numbering differed from the
native Linux `/dev/input/js*` numbering, which confirms that instance numbers
are runtime-local and must not be persisted in manifests.

After loading the standard CIG X-56 profile, axis movement and controller input
worked in game for both components.

## Support-state decision

The bundled `saitek-x56-rhino` manifest records:

| Stage | State | Basis |
| --- | --- | --- |
| Native Linux | `tested` | Both components were detected and produced axis/button input |
| HIDRAW `uaccess` | `candidate` | The scoped policy was present in the tested configuration, but gameplay success alone does not prove that HIDRAW access was the necessary causal factor |
| Wine | `tested` | Both devices reached the Wine-hosted game runtime |
| Star Citizen | `tested` | Both devices were listed as connected and supplied usable in-game input |

Keeping HIDRAW `uaccess` at `candidate` is intentional. Citizen Input Manager
separates effective access from Wine presentation, game visibility, binding,
and gameplay; a successful later stage must not be used to overstate an
independently unmeasured earlier mechanism.

## Scope and limitations

This result confirms the documented maintainer reference environment. It does
not guarantee identical behavior with every Star Citizen build, Wine runner,
distribution, USB topology, firmware revision, or existing controller profile.

The repository does not distribute an X-56 binding profile. Users should expect
to review and adjust the standard CIG mapping for their preferred axes,
throttle direction, curves, dead zones, and button layout.

The earlier findings summarized in
[nix-citizen issue 108 research](nix-citizen-issue-108.md) remain useful
historical context. This live validation updates the current support state; it
does not rewrite the conditions or results of the earlier point-in-time audit.
