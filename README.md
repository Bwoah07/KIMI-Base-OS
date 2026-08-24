# KIMI Base OS

A modular CC:Tweaked base-control operating system for FTB Evolution.

## Architecture

`installer.lua -> recovery startup -> updater -> kimi.lua -> role -> modules -> client profile`

The design goal is to avoid hard-coded limits. New integrations, client types and UI profiles are added as modules/files without wiping local configuration.

## Install roles

- `Command Center` - main server plus local admin UI on the same Advanced Computer
- `Server only` - headless central server
- `Wall / room client` - remote display/control client
- `Pocket computer` - mobile client
- `Remote sensor / machine node` - publishes attached sensor/module data back to the server

Remote clients/nodes can contribute telemetry from anywhere the KIMI network reaches. The server merges the healthiest/newest telemetry into one canonical state while retaining source/fleet metadata.

## Modules

The server and remote nodes discover `modules/*.lua` dynamically. Current integrations include environment/weather/moon, AE2, complete attachment/sensor discovery, Flux Networks, Mekanism Induction Matrix power telemetry, and door/redstone control.

Every attached peripheral is reported with all of its CC:Tweaked types and methods. Detector/scanner/reader/environment/player/block/Geo-style devices are classified from both their peripheral types and their method signatures. KIMI takes only safe, read-only summary samples; expensive world scans and methods requiring arguments remain visible in the method list without being invoked automatically.

Flux Networks telemetry is shown directly on Command Center, wall, and terminal clients. The native `flux_controller` API from the KIMI Flux Networks fork is supported, including exact large-FE values, all devices, health warnings, storage, live input/output/net flow, device counts, and average tick cost. Legacy `flux_device` integrations remain compatible. Every attached Flux controller remains visible even if multiple networks have the same name or omit a network ID. Flux networks, Mekanism Induction Matrices, and energy detectors are collected at the same time.

## Adaptive monitor planning

KIMI does not require monitor names or manual screen assignment for normal use. Every render pass discovers all attached monitors, sets the supported text scale, measures each screen, sorts them by usable area, inspects the local machine's capabilities, and automatically chooses useful views.

A Command Center prioritizes a clean overview and then allocates remaining displays to configured doors, power, sensors, fleet/status views according to what actually exists. A wall/room client prioritizes things attached to that computer first: a configured local door becomes a large local door panel, local power becomes a power panel, local sensors become a sensor panel, and remaining monitors are filled with time/weather/status and useful fleet-wide information.

A single remote monitor attached to a computer which owns a configured door automatically becomes a large door panel with the current open/closed state plus time/weather context. The screen size and number of monitors may change at runtime; KIMI re-detects and replans after peripheral changes.

ComputerCraft labels are used as friendly machine names automatically when an older install still has its generated `KIMI-<id>` name. Technical computer IDs remain available for diagnostics but are no longer the primary label in fleet/door views.

Touch controls redraw immediately when pressed so the UI gives instant visual acknowledgement instead of waiting for the next telemetry refresh.

## Door control

The main server keeps a persistent registry of real KIMI doors. Raw computer/redstone-integrator outputs and real door/gate peripherals are discovered only as setup candidates; they are never guessed to be doors.

The Command Center presents configured doors as large OPEN/CLOSED tiles and keeps raw output/controller details inside the separate setup screen. When a generic `DOOR 01` style name belongs to a labelled remote computer, dashboards prefer that friendly source name so a panel labelled `Front Gate` reads like a real door instead of a numbered debug object.

Door controllers may be attached to the server or any connected KIMI client/node. Server-originated remote door commands are still restricted by the Command Center safety model. A wall client may directly operate only a configured door whose registry says that same local computer owns the output; this gives a physically local door panel instant response without turning wall computers into arbitrary remote redstone consoles.

Detached controllers show as offline. The registry is stored under `.kimi/doors` on the main server and survives OS updates.

## Adaptive dashboards and sensors

The new shared adaptive UI is used by both Command Center and wall clients. It uses a quieter black/gray base palette with color reserved for state/action feedback instead of rendering every section as a different bright block.

Sensor pages show live counts, friendly source names, sensor type, and the most useful available metric. If the normal attachment sensor list is empty but an environment detector is live, the environment module is surfaced as a sensor fallback instead of leaving the page apparently blank.

Detector/scanner/reader/analyzer types plus common temperature, humidity, radiation, player, entity, block, biome, dimension, light, weather, pressure, range and environment method signatures are classified automatically. Safe no-argument metrics are shown with each device.

## Fleet synchronization

The main server is the version authority for every normal KIMI computer. It checks the reported version of every connected wall client, pocket, and sensor node, automatically retries outdated machines, and catches up computers that reconnect later.

From alpha.32 onward, `update.available` notices include the server's installed immutable release manifest. Updated clients/nodes persist that exact manifest before rebooting, and `updater.lua` installs the server-authority ref instead of silently substituting whatever newer commit happens to be on GitHub `main`.

The recovery bootloader no longer replaces a known-good `updater.lua` from mutable `main` on every boot; it only performs that fetch as an emergency bootstrap when the updater is missing. Server boot checks also respect `update.auto` and `update.checkOnBoot`.

## cc-mek-scada / Nuclear

`scada/` contains the KIMI bridge for MikaylaFischler's `cc-mek-scada` project.

The integration deliberately keeps upstream SCADA code and its original HMI intact. Dedicated Reactor PLC, RTU, Supervisor and Coordinator computers run the upstream applications while a small KIMI wrapper reports their version/update state into the normal KIMI fleet.

The Reactor PLC remains the local autonomous safety authority. KIMI is supervisory and must never be required for a reactor SCRAM.

See `scada/README.md` for installation and monitor requirements.

## Transactional updating

Normal KIMI OS files are update-managed by `manifest.json`.

Update flow:

1. The server resolves the current GitHub `main` commit through the GitHub API.
2. `manifest.json` is fetched from that exact commit to avoid stale branch/raw caches.
3. Releases point at an immutable commit ref.
4. A new release is downloaded completely into `.kimi/staging` before live files are touched.
5. Every downloaded Lua file is syntax-checked before installation.
6. The current OS is snapshotted to `.kimi/rollback`.
7. The staged release is installed transactionally.
8. A new release must survive a probation boot before it is marked healthy.
9. Repeated probation failures restore the previous known-good files.
10. The server announces its exact installed release manifest to normal fleet members so reconnecting machines catch up to the server-authority version.

Local config/state under `.kimi/` is preserved across normal OS updates.

## Testing

GitHub Actions syntax-checks the Lua OS with Lua 5.2, validates that every managed manifest path exists and matches `version.txt`, and runs an adaptive-display smoke test that mocks differently sized monitors plus local door/power/sensor telemetry.

## Networking

The network core opens every attached CC modem, allowing wired and wireless networking at the same time. Wall computers, room computers, pocket computers, remote sensor nodes, and SCADA bridge nodes can all report to the same central server.

## Current version

`5.0.0-alpha.32`

The repository is public so CC:Tweaked can perform unauthenticated HTTPS downloads from GitHub.
