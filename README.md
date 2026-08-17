# KIMI Base OS

A ComputerCraft/CC:Tweaked base-control system for FTB Evolution.

## Goals

- One central base server as the source of truth
- Wall-panel clients and pocket-computer clients
- Wired + wireless networking
- Self-updating from GitHub
- Automatic startup and crash recovery
- Environment telemetry with stale-data protection
- Future AE2, power, doors, quarry and teleport integrations

## Current version

`0.5.0-alpha`

## Planned roles

- `server` - central telemetry/control node
- `wall` - multi-monitor command center
- `pocket` - mobile remote

Local configuration and monitor assignments are intentionally kept outside the updater so updates do not wipe settings.
