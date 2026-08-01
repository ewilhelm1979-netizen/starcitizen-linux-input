# Security policy

## Reporting a vulnerability

Do not open a public issue containing a secret, private device identifier,
personal path, or exploitable proof against an active system. Use GitHub's
private vulnerability reporting for this repository when available. Include a
minimal synthetic reproducer and the affected version.

## Security boundaries

Citizen Input Manager treats sysfs links, manifests, output paths, and
installation roots as untrusted. It resolves paths canonically, limits parent
walking, rejects unexpected JSON fields, never executes manifest content, and
refuses symlink installation targets. Its standard renderer emits only scoped
HIDRAW `uaccess` rules with exact VID:PID pairs.

The project intentionally does not automate privilege escalation, Wine
registry changes, controller profile repair, rule reloads, device triggers, or
game launches. Reports are public and redacted by default.

Supported security fixes should include an isolated regression test. Never use
real controller nodes or active Udev directories in the test suite.
