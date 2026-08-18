# KIMI Base OS + cc-mek-scada

This integration keeps **cc-mek-scada** upstream code and its original monitor UI intact while adding a small KIMI bridge around each dedicated SCADA computer.

Upstream project: `MikaylaFischler/cc-mek-scada` (MIT licensed).

## Architecture

For a full networked facility, cc-mek-scada keeps its normal roles:

- Reactor PLC — local autonomous reactor protection / SCRAM logic.
- RTU — turbine, matrix, waste, radiation and other I/O.
- Supervisor — facility logic.
- Coordinator — original cc-mek-scada HMI on Advanced Monitors.
- Pocket — optional remote UI.

The KIMI bridge does **not** replace those programs. It launches the selected upstream app and, in parallel, reports component/version/update state into the normal KIMI telemetry network.

## Install upstream SCADA first

On each dedicated Advanced Computer, install the appropriate cc-mek-scada role using its official installer (`ccmsi.lua`) and configure it normally.

After the upstream role is installed and working, run the KIMI bridge installer:

```text
wget run https://raw.githubusercontent.com/Bwoah07/KIMI-Base-OS/main/scada/install_bridge.lua
```

Then reboot.

The bridge auto-detects `reactor-plc`, `rtu`, `supervisor`, `coordinator`, or `pocket`, opens available ComputerCraft modems, finds the KIMI server (`kimi_base_os_v1` / `kimi-base`), and publishes telemetry as a `scada` fleet member.

## Upstream updates

The bridge checks the official cc-mek-scada deployment manifest every 10 minutes and reports installed vs upstream component versions to KIMI.

It also supports a KIMI `scada.update.request` message. When that command is wired into the KIMI command-center UI, the bridge will:

1. SCRAM any directly attached reactor peripheral exposing `scram()`.
2. Reboot into update mode.
3. Stage the official upstream build files.
4. Syntax-check Lua files.
5. Back up affected files.
6. Install the upstream update.
7. Restore the KIMI bridge as `/startup.lua`.
8. Roll back if installation fails.

The original cc-mek-scada source/UI stays upstream-owned; KIMI only wraps and supervises it. This keeps future upstream updates far easier to consume than maintaining a heavily modified fork.

## Coordinator monitors

The original Coordinator intentionally validates monitor geometry. Its current code requires:

- Main monitor: 8 blocks wide.
- Flow monitor: 8 blocks wide.
- Each unit/reactor display: exactly 4 x 4 blocks.

The required heights for Main/Flow depend on reactor count and cooling configuration, so use the Coordinator configurator for the final dimensions. KIMI should not resize/re-theme these monitors; preserving the stock HMI is deliberate.

## Safety rule

The Reactor PLC remains the local safety authority. KIMI is supervisory. Loss of the KIMI server or rednet must never be required for the PLC to SCRAM the reactor.
