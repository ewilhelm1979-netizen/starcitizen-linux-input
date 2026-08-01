# Security model

The primary risks are overbroad HID access, malicious sysfs or output symlinks,
untrusted manifest content, accidental changes to active devices, and privacy
leaks in support reports.

Mitigations include exact USB VID:PID matching, HIDRAW-only rendering, logind
`uaccess`, canonical path containment, a 32-parent traversal limit, bounded
strict JSON parsing with duplicate-key rejection, safe slug and hexadecimal
validation, no execution of data, transactional same-directory installation,
backups, signal cleanup, no automatic reload or trigger, and public-by-default
reports.

World-writable device modes, global HIDRAW rules, standard-path input rules,
persistent ACL manipulation, blanket input-group membership, and automatic
privilege escalation are outside the trust model. The application also starts
no daemon, creates no virtual input device, and requires no proprietary driver.

Test-only roots are honored only when `SC_INPUT_TEST_MODE` is exactly `1` and
both roots are explicit. Production use rejects alternate root environment
variables. Tests create regular temporary files in place of device nodes and
never open an event stream.

Private and public reports are separate. Public reports use a fixed output
schema and expose only identifiers, enumerated support states, booleans, and
counts—not free-form manifest, device, or log text. They omit device paths,
runtime IDs, sysfs paths, usernames, hostnames, serial numbers, GUIDs, account
data, complete logs and profiles, registry dumps, environment contents, and
tokens. Private mode is intended for local troubleshooting and should still be
reviewed before sharing.

The [architecture overview](architecture.md) shows where automatic checks end
and evidence-assisted or manual diagnostic stages begin.
