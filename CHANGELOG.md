# Changelog

All notable project changes are documented here.

## Unreleased

### Added

- Initial Citizen Input Manager MVP with bounded USB input discovery.
- Schema-version-1 manifests for the tested SpaceMouse reference and X-56
  hardware.
- Scoped HIDRAW Udev rendering, isolated installer tests, diagnostics, public
  and private reports, Zenity GUI, TUI fallback, Nix packages, and NixOS module.
- Synthetic sysfs/device fixtures and security, privacy, and regression tests.
- A dated live X-56 functional-validation record covering native Linux, Wine,
  Star Citizen visibility, and usable in-game stick and throttle input.

### Changed

- Promoted the bundled X-56 manifest to `tested` for native Linux, Wine, and
  Star Citizen after the 2026-08-03 maintainer validation.
- Kept X-56 HIDRAW `uaccess` at `candidate` because the successful game test did
  not independently prove that mechanism was causally required.
- Updated the support matrix, onboarding, NixOS, GUI, troubleshooting, research,
  and image-provenance documentation to use the same support boundaries.
