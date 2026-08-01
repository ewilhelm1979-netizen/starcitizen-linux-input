# 2026-08 functional and security audit

## Scope and baseline

This was an independent, adversarial audit of Citizen Input Manager at main
commit `53070bf301d33281679ffaeabde513a5502371db` (tree
`7ade7b2b9ed912be113d03b7a86389bb44eee9c9`). Existing documentation, tests,
and previous conclusions were treated as claims to reproduce, not as proof.
The starting repository had 49 tracked files and one GitHub Actions workflow.
The GPL-3.0 license hash was
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.

The audit branch is `audit/deep-functional-security-2026-08`. Work used
synthetic USB/sysfs/device fixtures, isolated Udev roots, bounded hostile
inputs, mocked GUI/TUI backends, Nix builds, NixOS module evaluation,
fixed-seed property tests, static analyzers, and failure injection. No real
Udev rule, ACL, group, Wine registry, controller profile, launcher, or game
state was changed.

A HIGH public-report privacy flaw was reproduced early. All publishing was
stopped at that point. The flaw and every MEDIUM finding listed below have now
been fixed and locally verified. Live read-only testing has also passed; CI and
review of the live documentation remain pending.

## Methodology

The audit reviewed every original test assertion and fixture, mapped CLI and
documentation contracts to implementation, constructed independent negative
cases, exercised every command family and documented exit class, completed
SpaceMouse and X-56 fixture journeys, injected failures and signals around
file publication, and manually reviewed scanner output. A private reproducible
cross-project contract test compares both repositories' SpaceMouse policy and
support boundaries without adding a runtime dependency or copying the Star
Citizen profile into this repository.

## Live read-only hardware validation

On 2026-08-01, repository commit
`4968813470a7f16b932eedee0dde38f9744d8865` was tested read-only with one
connected USB SpaceMouse. VID:PID `256f:c63a` was confirmed through its
canonical USB ancestor. HIDRAW, event, and joystick node types were associated
dynamically under one unambiguous physical device. Effective HIDRAW read and
write access both succeeded.

The automatic status pipeline reported native detection and access only; Wine,
Star Citizen visibility, binding, and gameplay remained unconfirmed. The live
public report passed fixed-schema privacy validation without a username,
hostname field, node number, device or sysfs path, serial, GUID, Wine prefix,
account data, secret, or token. The private report was written only under the
private audit root with mode `0600`.

The rendered policy remained byte-identical to Project A and the active scoped
HIDRAW `TAG+="uaccess"` rule, with no `MODE`, `GROUP`, `OWNER`, executable,
global HIDRAW, or input-subsystem permission directive. No device event,
joystick event, or raw HID report was consumed. No system configuration, Udev
rule, ACL, group, Wine state, Star Citizen file, or game state was changed.
Gameplay was not retested during this phase, and X-56 remains
candidate/unverified.

## Functional claim matrix

| Claim | Documentation | Implementation | Evidence | Result | Remaining limitation |
| --- | --- | --- | --- | --- | --- |
| Discovery groups nodes by canonical USB ancestor, not leaf identity text. | architecture and security model | sysfs/discovery libraries | Ancestor-only, wrong vendor/product, missing attributes, escaping links, stale nodes, depth cap, multiple-interface fixtures plus live USB-ancestor grouping | VERIFIED | The USB SpaceMouse reference was tested; Bluetooth and Universal Receiver remain unverified. |
| Every CLI command has fail-closed option, exit-code, plain/JSON, and privacy contracts. | README and command help | `bin/sc-input` and libraries | Exhaustive no/missing/unknown/duplicate/ordering cases plus JSON-shape assertions | VERIFIED | Interactive TTY prompting was not used; noninteractive creation is fully covered. |
| Manifests are strict, bounded, non-executable data. | device-manifest guide and schema | manifest/common libraries | Unknown/duplicate keys, types, roles/pairs, confusables, controls, URLs, paths, 33 devices, 256 KiB, depth, UTF-8/NUL, malformed input | VERIFIED | The JSON Schema file is documentation; the shell validator remains authoritative. |
| The Udev renderer is whitelist-only and installation is recoverable. | security and generic Linux guides | renderer/installer | Injection corpus, exact rules, `udevadm verify`, hardlink/symlink/special/root checks, all failpoints, signals, cleanup/rollback-failure recovery | VERIFIED | No real rule was installed or reloaded. |
| Public reports cannot expose free-form manifest, device, or Game.log content. | security model and diagnostics guide | diagnostics/privacy libraries | High-severity reproducer, hostile privacy corpus, and live fixed-schema public-report validation | VERIFIED | Users must still review any support artifact before sharing. |
| Private report output is local, no-overwrite, and mode `0600`. | README and security model | secure publication helper | End-to-end publication defenses plus live private-report mode and structure validation | VERIFIED | Private reports intentionally contain local diagnostic details. |
| SpaceMouse fixture and live recognition journeys work end to end. | README architecture | all CLI layers | Complete synthetic journey plus live discover, list, runtime-ID inspect, known-manifest verify, and public/private reports | VERIFIED | No event stream, Wine, game binding, or gameplay test was performed live. |
| X-56 remains a two-component research case. | support matrix and research guide | X-56 manifest and verification | stick/throttle grouping, roles, missing/duplicate/wrong devices, identical-pair ambiguity, deterministic two-rule output | VERIFIED | No X-56 hardware or gameplay was tested; Star Citizen status remains `unverified`, HIDRAW policy `candidate`. |
| Wine diagnostics display a safely quoted command and never run or mutate Wine. | Wine guide | diagnostics CLI | Hostile path previews and mutation-source scans | VERIFIED | DInput/WGI behavior cannot be inferred or exercised without Wine, which was not started. |
| Game.log and XML helpers are bounded, read-only validators. | diagnostics guide | diagnostics library | Malformed/binary/link/FIFO/oversized/deep/element-count/entity/token/duplicate/mixed-device/huge-line/ghost cases | VERIFIED | Evidence indicates visibility only, never binding or gameplay success. |
| GUI/TUI contains no independent discovery or privileged path. | GUI guide | `bin/sc-input-gui` | Backend delegation, empty/one/multiple devices, hostile names, Unicode, Zenity/dialog/whiptail/CLI fallback, nested cancellation and error mocks | VERIFIED | Native toolkit rendering was not smoke-tested under Xvfb; backend and argument boundaries were tested. |
| Documented commands agree with the implemented CLI. | README and guides | CLI, GUI, and flake outputs | Help, safe render/preview, development commands, and synthetic equivalents of discovery/inspect/create/report examples | PARTIALLY_VERIFIED | Remote-flake and live-hardware forms were not used during the gated local audit. |
| The NixOS module installs exact early rules and optional GUI only when selected. | NixOS guide | module and flake | Enabled/disabled/GUI/empty/duplicate/X-56 evaluations, exact file bytes, no service/user/group/tmpfiles integration | VERIFIED | Evaluated on both declared systems; built on `x86_64-linux`; no booted VM. |
| Generic Linux distribution compatibility is proven. | Explicitly limited | scripts | Nix-built synthetic tests | NOT_VERIFIED | Distribution Udev policy, desktop seats, and packaging vary. |

## Findings and fixes

No CRITICAL finding was found. The HIGH finding caused an immediate publishing
stop. It and all MEDIUM findings are fixed in the audit branch.

### B-01 — HIGH — attacker-controlled text leaked into public reports

- Affected: public support reports and public Game.log analysis.
- Root cause: redaction attempted to remove known sensitive patterns while
  retaining free-form manifest descriptions, reference URLs, device names, and
  matching log lines. Unknown secrets and account-like values are not safely
  redactable by blacklist.
- Reproduction: inject unique private markers into every free-form manifest
  field and a connected-controller log line, then request public output.
- Impact: a user could publish account identifiers, hostnames, tokens, or other
  secrets supplied by hardware, manifests, or logs.
- Fix: public mode now uses a fixed allowlist schema containing only safe slugs,
  validated USB IDs/roles/node enums/support enums, booleans, and counts.
  Free-form text exists only in private mode. Public Game.log output contains
  counts/status only.
- Regression: deterministic adversarial and property tests inject all required
  privacy classes and fail on any marker or GUID-like residue.
- Residual risk: public JSON still reports intended system version/kernel and
  device-count metadata; users must review before sharing.

### B-02 — MEDIUM — malformed multi-rule NixOS output

- Affected: NixOS module Udev generation.
- Root cause: an indented Nix string emitted the two characters `\` and `n`
  instead of a real line break between selected device rules.
- Reproduction: evaluate the X-56 or combined module and compare the generated
  file byte-for-byte with two/three expected lines.
- Impact: multi-device rules could be rejected or interpreted incorrectly by
  Udev.
- Fix: emit real newline-separated rules and compare exact X-56 and combined
  files during flake checks.
- Regression: module evaluation and Udev parser verification.
- Residual risk: no real-system activation was performed.

### B-03 — MEDIUM — permissive and unbounded manifest parsing

- Affected: manifest and schema validation.
- Root cause: duplicate JSON keys and duplicate VID:PID entries were accepted;
  size, depth, encoding, required-key, and device-count boundaries were
  incomplete.
- Reproduction: supply duplicate keys/pairs, 33 devices, deep or oversized
  JSON, invalid UTF-8/NUL, unknown keys, wrong types, confusable identifiers,
  unsafe URLs, paths, and executable-looking fields.
- Impact: parser differentials, ambiguous rules, resource exhaustion, or
  unintended persistent data.
- Fix: strict duplicate-key parsing, exact required keys, a 256 KiB/32-level/32-
  device limit, NUL-free UTF-8, and unique ASCII roles and pairs.
- Regression: exhaustive schema corpus and fixed-seed property tests.
- Residual risk: safe Unicode remains allowed only in display text and is never
  used as an identifier or executable value.

### B-04 — MEDIUM — ambiguous identical devices could report native success

- Affected: verification status pipeline.
- Root cause: automatic native state required nodes but did not require exactly
  one physical match for each manifest component.
- Reproduction: expose two physical devices with the same VID:PID and verify a
  single-component manifest.
- Impact: `NATIVE_DETECTED` and `NATIVE_ACCESS_OK` could be overstated even
  though a VID:PID rule cannot select one unit.
- Fix: both automatic statuses now require exactly one physical match per
  component and fail closed on ambiguity.
- Regression: duplicate SpaceMouse and duplicate X-56 component fixtures.
- Residual risk: a VID:PID rule intentionally applies to all identical units;
  serial-number workarounds remain prohibited.

### B-05 — MEDIUM — file publication and Udev rollback gaps

- Affected: report/manifest output and isolated Udev installation.
- Root cause: incomplete hardlink, canonical-target, signal, and post-rename
  rollback handling.
- Reproduction: use link/special targets, noncanonical outputs, injected
  failures at every transaction phase, cleanup/rollback faults, and signals.
- Impact: unintended overwrite/link modification, residual candidates, or a
  changed target after interruption.
- Fix: canonical no-overwrite publication, same-directory random candidates,
  hardlink checks, pre-rename recheck, signal cleanup, rollback, and unique
  recoverable backups.
- Regression: full adversarial transaction matrix.
- Residual risk: hostile concurrent mount replacement is outside the trusted
  administrator/filesystem boundary.

### B-06 — MEDIUM — XML and Game.log parsers lacked complete resource/path bounds

- Affected: Star Citizen diagnostic helpers.
- Root cause: path, encoding, line, depth, element-count, duplicate-token, and
  mixed-device constraints were incomplete.
- Reproduction: malformed/binary/link/FIFO/oversized/deep/entity-expansion,
  huge-line, duplicate, and mixed-instance inputs.
- Impact: misleading output, excess work, or unsafe evidence handling.
- Fix: canonical regular files, 8 MiB Game.log and 2 MiB XML limits, NUL-free
  UTF-8, 4 KiB/128-line log evidence caps, DTD/entity rejection, 64 XML depth,
  100,000 elements, and strict token uniqueness/instance rules.
- Regression: diagnostic adversarial suite and property corpus.
- Residual risk: parsers validate bounded evidence; they do not repair data or
  prove gameplay.

### B-07 — MEDIUM — nested GUI cancellation returned an error

- Affected: Zenity device, manifest, form, preview, confirmation, and export
  flows.
- Root cause: `set -e` propagated expected dialog cancellation from helper
  functions as a process failure.
- Reproduction: make each nested mocked dialog return its normal cancel status.
- Impact: routine user cancellation unexpectedly terminated the GUI with an
  error status.
- Fix: translate expected nested cancellation to a successful return to the main
  loop while preserving actual backend errors.
- Regression: cancellation at every nested step plus explicit Zenity error.
- Residual risk: native toolkit rendering itself was not exercised under Xvfb.

### B-08 — LOW — executable library seams and CI defense-in-depth

- Affected: CLI/GUI environment overrides and workflow metadata.
- Root cause: executable library/backend overrides were broader than needed;
  the workflow lacked concurrency cancellation and a stable job name.
- Impact: unsafe invocation environments had an unnecessary code-loading seam,
  and redundant CI runs were possible.
- Fix: executable sources must be adjacent packaged files or root-owned Nix
  store paths; workflow concurrency and job naming were added.
- Regression: override rejection, backend delegation, actionlint, and zizmor.
- Residual risk: source-checkout execution still requires a trusted PATH.

## Shared threat model

`PREVENTED` means data cannot become code or reach the protected boundary.
`DETECTED_AND_REJECTED` means input validation fails closed.
`OUT_OF_SCOPE_WITH_JUSTIFICATION` records an explicit trust boundary.

| Threat | Status | Evidence or justification |
| --- | --- | --- |
| Command injection through CLI arguments | DETECTED_AND_REJECTED | Fixed parsers, duplicate-option rejection, quoting, and property tests. |
| Command injection through JSON manifest values | DETECTED_AND_REJECTED | Strict typed schema and whitelist-only jq rendering; hostile corpus. |
| Command injection through manufacturer/product strings | PREVENTED | Strings remain JSON/GUI arguments and are never evaluated; hostile-name test. |
| Command injection through filenames and paths | DETECTED_AND_REJECTED | Canonical absolute paths, safe slugs, quoting, and executable-source restrictions. |
| Command injection through Game.log or XML content | PREVENTED | Content is bounded data parsed by fixed grep/XML logic and never executed. |
| Use of eval, unsafe source, indirect expansion, or executable data | PREVENTED | No `eval`; sourced code is restricted to adjacent package or Nix store; manifest data is never sourced. |
| Unquoted word splitting and glob expansion | PREVENTED | Manual review, ShellCheck, arrays, and intentional bounded globs. |
| Malicious PATH and command shadowing | OUT_OF_SCOPE_WITH_JUSTIFICATION | Nix-wrapped packages prepend pinned store tools; source-checkout execution requires a trusted developer PATH. |
| Hostile IFS, locale, TMPDIR, HOME, XDG variables, and umask | DETECTED_AND_REJECTED | `umask 077`, explicit modes, canonical output directories, locale-stable parsing, and environment/path tests. |
| Path traversal | DETECTED_AND_REJECTED | Canonical absolute inputs and output normalization. |
| Symlink traversal | DETECTED_AND_REJECTED | Roots, class links, directories, inputs, and outputs resolve within approved roots. |
| Hardlink abuse | DETECTED_AND_REJECTED | Existing mutable targets require link count one; new outputs use exclusive no-overwrite publication. |
| Mountpoint confusion | OUT_OF_SCOPE_WITH_JUSTIFICATION | The invoking administrator must provide a stable trusted mount namespace. |
| Canonicalization mismatch | DETECTED_AND_REJECTED | Lexical path must equal canonical resolution. |
| Time-of-check/time-of-use races | OUT_OF_SCOPE_WITH_JUSTIFICATION | Targets are rechecked before atomic publication; hostile concurrent mount/ancestor replacement needs a lower-level API. |
| Unsafe temporary files | PREVENTED | Random same-directory files, restrictive umask/modes, and cleanup traps. |
| Predictable backup names | PREVENTED | `mktemp` random suffixes. |
| Backup overwrite | PREVENTED | Exclusive unique backup creation. |
| Partial write or interrupted rename | PREVENTED | Candidate is complete before atomic same-directory rename. |
| Failure between backup and publication | PREVENTED | Original remains active; backup is retained. |
| Rollback failure | DETECTED_AND_REJECTED | Injected rollback fault reports failure and preserves the original backup. |
| Special files, FIFOs, sockets, block devices, and character devices | DETECTED_AND_REJECTED | Inputs/targets must be regular files; synthetic `/dev` test files are permitted only in explicit test mode. |
| Oversized JSON, XML, Game.log, and manifest inputs | DETECTED_AND_REJECTED | Manifest 256 KiB, XML 2 MiB, Game.log 8 MiB; output is bounded. |
| Excessive element/node counts | DETECTED_AND_REJECTED | XML 100,000 elements; manifests 32 devices; evidence 128 lines; discovery roots bounded. |
| Deeply nested JSON or XML | DETECTED_AND_REJECTED | JSON 32 levels and XML 64 levels. |
| Malformed UTF-8 | DETECTED_AND_REJECTED | All external text inputs decode strictly. |
| Embedded NULs where relevant | DETECTED_AND_REJECTED | External text validation rejects NUL bytes. |
| XML external entities and network entity resolution | DETECTED_AND_REJECTED | DTD/entity declarations are rejected before ElementTree parsing. |
| Regex denial of service | PREVENTED | Anchored/simple patterns operate only on bounded fields and lines. |
| Duplicate devices | DETECTED_AND_REJECTED | Manifest duplicates are rejected and discovery ambiguity fails automatic status. |
| Identical VID:PID devices | DETECTED_AND_REJECTED | Verification and partial selection fail closed; warnings are emitted. |
| Missing USB ancestor attributes | DETECTED_AND_REJECTED | No physical record is created. |
| Malicious or disappearing sysfs paths | DETECTED_AND_REJECTED | Canonical containment and existence checks; escape fixture fails discovery. |
| More than 32 ancestor levels | DETECTED_AND_REJECTED | Parent walking is capped; deep fixture is ignored. |
| Multiple matching HIDRAW nodes | PREVENTED | Nodes are associated with one physical ancestor and all expected/access states are evaluated; physical ambiguity still fails closed. |
| Stale `/dev` nodes | DETECTED_AND_REJECTED | A current contained class link and canonical node are both required. |
| Permission changes between discovery and verification | OUT_OF_SCOPE_WITH_JUSTIFICATION | Access is reported at verification time; no persistent permission lease is claimed. |
| Privacy leakage | DETECTED_AND_REJECTED | Public fixed schema replaced unsafe blacklist redaction; adversarial regression corpus. |
| Secret leakage | PREVENTED | Gitleaks, Trivy secret scanning, public-output corpus, and manual review are clean after the fix. |
| GitHub Actions supply-chain risks | PREVENTED | Hosted runner, minimal permissions, no fork secrets, artifacts, or untrusted context interpolation. |
| Unpinned Actions | PREVENTED | Every Action uses an independently tag-verified full commit SHA. |
| Excessive workflow permissions | PREVENTED | Only `contents: read`. |
| Nix evaluation-time network access | PREVENTED | Locked local evaluation completed offline. |
| Import-from-derivation | PREVENTED | Local `readFile`/`fromJSON` only; no IFD mechanism. |
| Accidental inclusion of private files in Flake sources | PREVENTED | An untracked sentinel was absent from the Git-derived source closure. |
| Incorrect support-status escalation | DETECTED_AND_REJECTED | Automatic states cannot overwrite manual/game states; new manifests are unverified; X-56 remains candidate/unverified. |
| Unsafe Udev output | PREVENTED | Renderer constructs fixed literal syntax from four-digit lowercase IDs only. |
| Unexpected input-subsystem permission widening | PREVENTED | Exact rules match HIDRAW only; input nodes are verify-only. |

## Tooling and test results

The final local matrix passed with Nix 2.34.8, Bash 5.3.15, ShellCheck 0.11.0,
shfmt 3.13.1, jq 1.8.2, Python 3.14.6, libxml 2.15.3, Udev 260,
actionlint 1.7.12, zizmor 1.28.0, gitleaks 8.30.1, Trivy 0.72.0, and
Semgrep 1.164.0. Semgrep ran three local shell rules and found nothing. Trivy's
secret scan was clean; its misconfiguration scanner recognized no supported
configuration files, so workflow conclusions rely on actionlint, zizmor, and
manual review. Gitleaks found no secret.

The complete Bash suite, CLI/GUI journeys, deterministic property suite (seed
`20260801`), `nix flake metadata --offline`, all-system `nix flake show`,
`nix flake check --no-write-lock-file`, both exposed `x86_64-linux` packages,
and both app help paths passed. The lock hash remained
`9f7c125146ac516be8b1ed04433e83871bf512ae54b567e60ca3859dade87f87`.
`aarch64-linux` outputs evaluated but were not built. Module evaluation proves
the exact early-rule files, GUI selection, disabling behavior, invalid/empty
configuration rejection, and absence of services, users/groups, and tmpfiles;
no booted VM or hardware is required for those properties.

## GitHub Actions review

The workflow has minimal permissions, no `pull_request_target`, no self-hosted
runner, no artifact upload, no mutable download, no secret path for fork pull
requests, and no untrusted GitHub context interpolation in shell. Checkout
credential persistence is disabled. The pinned `actions/checkout` SHA maps to
upstream `v5.1.0`; the pinned `cachix/install-nix-action` SHA maps to upstream
`v31`. Actionlint and offline pedantic zizmor report no finding. CI executes
the same core `nix flake check --no-write-lock-file` matrix used locally.

## Unverified boundaries and readiness

- Live USB discovery, runtime-ID inspection, effective access verification, and
  public/private reports passed for the tested USB reference.
- No live event stream, Wine process, launcher, game, or controller binding was
  exercised.
- No X-56 hardware was available; its support status was not promoted.
- Bluetooth and Universal Receiver SpaceMouse paths remain unverified.
- Native Zenity rendering under Xvfb, generic Linux distributions,
  `aarch64-linux` hardware, and a booted NixOS VM were not exercised.
- Pre-live follow-up CI passed. CI for this live-documentation commit and
  automated pull-request review remain pending.

Current state: `CITIZEN_INPUT_AUDIT_READY=NO`. The reasons are the pending live
documentation CI/review, not an unresolved CRITICAL/HIGH/MEDIUM code finding or
a failed live check.

## AI-assisted audit

This audit and its supporting test development were performed with
substantial assistance from OpenAI Codex. The human maintainer remains
responsible for reviewing the findings, validating fixes, assessing residual
risk, and making release and merge decisions.
