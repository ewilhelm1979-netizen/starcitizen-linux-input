# Star Citizen diagnostics

Game-log analysis requires an explicit absolute `--game-log` path. The tool
does not scan the complete home directory or filesystem. It extracts only lines
containing `Connected joystick`; it never copies the full log. Public output
redacts controller GUIDs, while private output may display them only for the
local runtime report. The result compares connected names and device counts
with the current bounded native discovery without claiming that matching counts
prove functional input.

Exported controller profiles can be checked with
`star-citizen validate-profile --profile`. The validator rejects document type
and entity declarations, requires well-formed XML, lists referenced joystick
instances, and reports empty inputs, malformed `js1_`/`js2_`-style tokens, and
duplicate rebinds. It does not repair XML, edit the game-wide action map, or
include complete profiles in a support report.

`STAR_CITIZEN_VISIBLE` means only that the selected evidence reports a connected
device. Binding and gameplay states remain manual confirmations. The tool does
not launch the RSI Launcher or Star Citizen and does not create, modify, or
publish controller profiles.
