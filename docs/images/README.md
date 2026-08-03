# Documentation image provenance

## Architecture illustration

`citizen-input-manager-overview.svg` is a schematic architecture illustration
created with substantial assistance from OpenAI Codex. It uses only
repository-native SVG primitives and no vendor artwork, proprietary artwork,
or external image asset.

The controller silhouettes are generic. They do not represent verified support
for every controller shown. SpaceMouse is tested within its documented scope.
X-56 native Linux, Wine, and Star Citizen operation are also tested in the
documented maintainer reference environment; X-56 HIDRAW `uaccess` remains a
separately tracked candidate. The human maintainer reviewed and approved the
illustration and remains responsible for its publication.

## GUI captures

The files below are documentation captures derived from screenshots supplied by
the human maintainer from a live Citizen Input Manager session:

- `gui/citizen-input-manager-main-menu-sanitized.svg`;
- `gui/citizen-input-manager-physical-devices-redacted.svg`;
- `gui/citizen-input-manager-create-local-manifest.png`.

The main-menu and physical-device views were recreated as repository-native SVG
captures so the privacy redaction is explicit, deterministic, and reviewable.
They contain no scripts, external references, embedded raster data, usernames,
hostnames, local paths, secrets, or device serial numbers. Ephemeral runtime
IDs and unrelated local device inventory are covered with opaque redaction
bars. The documented SpaceMouse and X-56 product names plus their public USB
VID:PID values remain visible because they are required to explain the
workflow.

The local-manifest form is a sanitized PNG capture. It contains no embedded
text metadata and no private system information. New GUI-created manifests
still begin with `unverified` support fields; that safe default is independent
of the separately reviewed support states in bundled manifests. The human
maintainer remains responsible for the privacy review, technical context, and
publication decision.
