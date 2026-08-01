# Wine diagnostics

Citizen Input Manager does not start Wine. With an explicit existing prefix
and executable runner, `sc-input wine command` prints a shell-quoted
`control joy.cpl` command for later manual use. It does not run the command or
search the home directory for prefixes and runners.

Registry experiments are outside the MVP. The tool never writes or recommends
automatic changes to HIDRAW, SDL, or controller-mapping registry values.
Existing values should be read only after a separate, explicit user decision.

Treat DirectInput and Windows.Gaming.Input as separate presentations. Duplicate
or placeholder devices can originate in Wine, winebus, SDL, or the WGI layer;
native Linux detection alone cannot identify which presentation Star Citizen
uses.

See the [architecture overview](architecture.md) for Wine's position between
native access checks and later Star Citizen evidence.
