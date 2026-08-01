# Contributing

Contributions must preserve the fail-closed security and privacy model. Open an
issue before adding a new device identity or widening an access policy. A new
USB ID needs reproducible hardware evidence; do not infer IDs from product
families or copy private controller profiles and logs.

Repository content, code comments, commit messages, and review replies must be
in English. Keep the AI-assistance disclosure in `README.md` intact.

Before submitting a change, run:

```console
tests/run.sh
nix flake check --no-write-lock-file
nix build .#packages.x86_64-linux.default
nix build .#packages.x86_64-linux.gui
git diff --check
```

Never test installer changes against active system rules. Use
`SC_INPUT_TEST_MODE=1` and an isolated temporary root. Do not include account
data, serial numbers, controller GUIDs, complete logs, complete exported
profiles, tokens, or absolute personal paths in issues or commits.
