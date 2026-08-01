# Generic Linux

Start with read-only discovery and diagnostics:

```console
sc-input discover
sc-input verify --known-manifest 3dconnexion-spacemouse-wireless-usb
sc-input udev render --known-manifest 3dconnexion-spacemouse-wireless-usb
```

Rendering prints a deterministic rule and changes nothing. Review the VID:PID
against the physical hardware before considering installation.

The imperative installer is deliberately separate from the renderer. It has a
dry-run, accepts an alternate root only in explicit test mode, rejects symlink
directories plus symlinked or hard-linked targets, backs up existing files,
writes a same-directory temporary file, rechecks the destination immediately
before replacement, and uses file mode `0644`. Failure injection and INT, TERM,
or HUP after publication restore the previous target. It does not invoke a
privilege helper, reload Udev, or trigger a device.

On a real system, an administrator must invoke the final installation from an
already authenticated UID-0 shell. After a deliberate installation, reload
only the rules and then disconnect and reconnect the selected controller, or
log out and back in. Never trigger all devices. Those real-system steps are not
part of automated tests or the GUI.

Missing event or joystick access is reported. The standard path never creates
an input-subsystem rule; investigate the distribution's normal seat policy
instead of widening access globally.
