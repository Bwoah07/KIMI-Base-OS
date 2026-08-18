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

The server and remote nodes discover `modules/*.lua` dynamically. Current integrations include environment/weather/moon, AE2, and Mekanism Induction Matrix power telemetry, with room for doors/redstone, RFTools, quarry/mining, factories, and other peripherals.

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
10. The server checks periodically, announces releases to known machines, and fleet members independently catch up if they were offline.

Local config/state under `.kimi/` is preserved across normal OS updates.

## Networking

The network core opens every attached CC modem, allowing wired and wireless networking at the same time. Wall computers, room computers, pocket computers, remote sensor nodes, and SCADA bridge nodes can all report to the same central server.

## Current version

`5.0.0-alpha.26`

The repository is public so CC:Tweaked can perform unauthenticated HTTPS downloads from GitHub.
