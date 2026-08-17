# KIMI Base OS

A modular CC:Tweaked base-control operating system for FTB Evolution.

## Architecture

`installer.lua -> immutable startup recovery bootloader -> updater -> kimi.lua -> role -> modules -> client profile`

The design goal is to avoid hard-coded limits. New integrations, client types and UI profiles are added as modules/files without wiping local configuration.

## Install roles

- `Command Center` - main server plus local UI on the same Advanced Computer
- `Server only` - headless central server
- `Wall / room client` - remote display/control client
- `Pocket computer` - mobile client
- `Remote sensor / machine node` - publishes attached sensor/module data back to the server

Remote nodes can contribute telemetry from anywhere the KIMI network reaches. Their state is merged into the server's canonical state under `state.nodes`.

## Modules

The server and remote nodes discover `modules/*.lua` dynamically. Planned integrations include environment/weather/moon, AE2, Mekanism Induction Matrix/power, doors/redstone relays, RFTools teleport controls, quarry/mining telemetry, and factory machines.

## Ironproof updating

Normal KIMI OS files are update-managed by `manifest.json`. The tiny `startup.lua` recovery bootloader is intentionally preserved outside routine OS updates so there is always a known recovery anchor.

Update flow:

1. On every boot, the recovery bootloader best-effort refreshes the updater and checks GitHub.
2. If GitHub/internet is unavailable, KIMI boots the installed version normally.
3. A new release is downloaded completely into `.kimi/staging` before live files are touched.
4. Every downloaded Lua file is syntax-checked before installation.
5. The current OS is snapshotted to `.kimi/rollback`.
6. The staged release is installed transactionally.
7. A new release must survive a 15-second probation boot before it is marked healthy.
8. Repeated probation failures trigger automatic restoration of the last known-good OS.
9. The server checks GitHub periodically (default: every 10 minutes), announces new releases to known machines, then updates itself.
10. Online clients/nodes stagger their reboots, pull the release directly from GitHub, and keep their own rollback snapshot.
11. Every machine also performs independent periodic and boot-time checks, so missed broadcasts/offline machines catch up automatically.

Local config/state under `.kimi/` and the recovery `startup.lua` are preserved across normal OS updates.

## Networking

The network core opens every attached CC modem, allowing wired and wireless networking at the same time. Wall computers, room computers, pocket computers, and remote sensor nodes all communicate with the same central server.

## Current version

`5.0.0-alpha.5`

The repository is public so CC:Tweaked can perform unauthenticated HTTPS downloads from `raw.githubusercontent.com`.
