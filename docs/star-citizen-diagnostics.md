# Star Citizen diagnostics

Game-log analysis requires an explicit canonical absolute `--game-log` path.
The file is limited to 8 MiB and must be NUL-free UTF-8. The tool does not scan
the complete home directory or filesystem. It extracts only lines containing
`Connected joystick`; it never copies the full log. Public output contains only
counts and comparison status, because controller names and other matching text
are attacker-controlled. Private output may display bounded matching lines and
names only for the local runtime report. The result compares device counts with
the current bounded native discovery without claiming that matching counts
prove functional input.

Exported controller profiles can be checked with
`star-citizen validate-profile --profile`. The canonical input is limited to 2
MiB of NUL-free UTF-8 XML. The validator rejects document type and entity
declarations, excessive depth or element counts, malformed tokens, duplicate
rebinds, and mixed joystick instances. It does not repair XML, edit the
game-wide action map, or include complete profiles in a support report.

`STAR_CITIZEN_VISIBLE` means only that the selected evidence reports a connected
device. Binding and gameplay states remain manual confirmations. The tool does
not launch the RSI Launcher or Star Citizen and does not create, modify, or
publish controller profiles.

See the [architecture overview](architecture.md) for the independently
reported visibility, binding, and gameplay stages.
