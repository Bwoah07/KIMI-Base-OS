# KIMI Base OS

A modular CC:Tweaked base-control operating system for FTB Evolution.

## Architecture

`installer.lua -> updater.lua -> startup.lua -> kimi.lua -> role -> modules -> client profile`

The design goal is to avoid hard-coded limits. New integrations, client types and UI profiles are added as modules/files without rewriting the updater or wiping local configuration.

## Roles

- `server` - one central source of truth for telemetry and commands
- `client` + `wall` profile - wall/room displays and touch panels
- `client` + `pocket` profile - mobile remote
- future profiles can be added without changing the kernel

## Modules

The server discovers `modules/*.lua` dynamically. A module can expose telemetry with `read()` and, later, commands with `handleCommand()`.

Planned modules include:

- Environment / weather / moon
- AE2 / ME Bridge
- Mekanism Induction Matrix and power grid
- Redstone relays / doors
- RFTools teleport hub
- Quarry/mining telemetry
- Factory and machine integrations

## Updating

`manifest.json` defines all update-managed files. The updater downloads every file into staging before touching the running install, snapshots the current managed files to `.kimi/rollback`, and restores that snapshot if installation fails.

Local files under `.kimi/` are deliberately not update-managed, so monitor assignments, themes, names and future device configuration survive software upgrades.

## Networking

The network core opens every attached CC modem, so a server can use wired and wireless networking at the same time. Wall computers, room computers and pocket computers consume the same central state feed.

## Current version

`5.0.0-alpha.1`

This repository must be public for unauthenticated in-game updates from `raw.githubusercontent.com`.
