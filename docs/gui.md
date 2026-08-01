# GUI and TUI

`sc-input-gui` prefers Zenity, then `dialog`, then `whiptail`. If none is
available, it prints a direct CLI hint. Every device and manifest result comes
from `sc-input`, normally through `discover --json`, `inspect --json`, or
`manifest list --json`.

The Zenity workflow provides a start notice, physical-device list,
multi-selection for HOTAS sets, device details, known-manifest selection,
private local manifest creation with preview, rule preview, safe dry-run command
display, native diagnosis, public report export, and a warning before any
suggested system action.

The TUI keeps the same backend boundary and offers discovery, known manifests,
rule/report command guidance, and security notices. Advanced manifest entry is
available through the CLI when Zenity is unavailable.

No GUI component accepts a free-form discovery command, stores a password,
starts a privilege helper, installs a rule, changes a permission, launches Wine
or Star Citizen, or edits a registry or binding.
