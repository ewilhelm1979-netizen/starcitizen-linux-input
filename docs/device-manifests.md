# Device manifests

Manifests are JSON documents with `schemaVersion: 1`. They contain a safe slug
ID, display text, one or more uniquely named roles, exact lowercase USB VID:PID
pairs, expected node types, access policy, support states, and public
references.

Allowed support values are `tested`, `reported`, `candidate`, `unverified`, and
`unsupported`. New local manifests default every support field to
`unverified`. The only version-one access policy is HIDRAW `uaccess` with input
nodes in `verify-only` mode.

Persistent manifests must not contain runtime IDs, device node numbers, sysfs
paths, USB port paths, serial numbers, usernames, hostnames, home paths, shell
fragments, or executable fields. Validation rejects unknown fields, unsafe
slugs, duplicate roles, malformed hexadecimal IDs, absolute paths, and unknown
policies.

`manifest create` uses `jq` for safe JSON construction. Preview the generated
document before saving it. Local storage defaults to the XDG data directory;
new directories and files are private, and existing files are never silently
replaced.
