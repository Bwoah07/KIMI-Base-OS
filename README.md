# KIMI Base OS

A modular CC:Tweaked base-control operating system for FTB Evolution.

## Architecture

`installer.lua -> immutable startup recovery bootloader -> updater -> kimi.lua -> role -> modules -> client profile`

The design goal is to avoid hard-coded limits. New integrations, client types and UI profiles are added as modules/files without wiping local configuration.

## Roles

- `server` - one central source of truth for telemetry, commands and fleet update coordination
- `client` + `wall` profile - wall/room displays and touch panels
- `client` + `pocket` profile - mobile remote
- future profiles can be added without changing the kernel

## Modules

The server discovers `modules/*.lua` dynamically. Planned integrations include environment/weather/moon, AE2, Mekanism Induction Matrix/power, doors/redstone relays, RFTools teleport controls, quarry/mining telemetry, and factory machines.

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
9. The server checks GitHub periodically (default: every 10 minutes). When it sees a new release it broadcasts the target version to known KIMI clients, then performs its own controlled reboot/update.
10. Online clients stagger their reboots by a few seconds, pull the release directly from GitHub, and use their own independent staging/rollback snapshot.
11. Clients also perform their own periodic fallback check, so a missed broadcast cannot leave them permanently behind.
12. Offline clients simply catch up through the normal boot-time update check when they next turn on.

Local config/state under `.kimi/` and the recovery `startup.lua` are preserved across normal OS updates.

## Networking

The network core opens every attached CC modem, allowing wired and wireless networking at the same time. Wall computers, room computers and pocket computers consume the same central state feed.

## Current version

`5.0.0-alpha.4`

The repository is public so CC:Tweaked can perform unauthenticated HTTPS downloads from `raw.githubusercontent.com`.
