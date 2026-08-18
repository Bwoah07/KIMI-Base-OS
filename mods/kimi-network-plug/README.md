# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, CC:Tweaked/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.13

Alpha.13 is the unified-art + transfer-diagnostics pass based on alpha.12 in-game testing.

### One visual system

Network Plug, Wireless Charger, and Chunk Loader now deliberately share the same graphite + brushed-alloy + recessed-panel material family. Device role is communicated with restrained status colour rather than a completely different casing style.

The Network Plug exterior geometry from alpha.12 is retained.

The Network Plug and Wireless Charger GUIs now use the same floating neutral-silver PowerNet shell, spacing, flat controls, tab proportions, and status treatment. The Charger no longer uses a giant cyan perimeter.

Tab artwork was simplified into recognisable icons:

- plug connector
- network list
- statistics bars
- KIMI/ComputerCraft monitor
- wireless charger battery
- charge target

The Network tab remains the only place where a Network Plug can select/change its network, and it retains the always-visible scrollable list.

### Crystal-clear transfer path telemetry

Every Network Plug now records both sides of the transfer path instead of exposing only one vague LIVE number.

A plug tracks:

- attached block registry ID
- attached block display name
- direction (`RECEIVING_FROM`, `SENDING_TO`, or `DISABLED`)
- attached-block transfer rate
- PowerNet transfer rate
- bottleneck classification: `NONE`, `SOURCE`, `NETWORK`, `TARGET`, or `NO_BLOCK`

The General page shows a compact path summary. The Power Path/Statistics page shows the attached machine, both stage rates, and `LIMITED BY` diagnostic clearly.

Examples:

- INPUT: `Creative Energy Cell -> Plug -> BASE_POWER`
- OUTPUT: `BASE_POWER -> Plug -> Induction Port`
- if the target only accepts 1.25 GFE/t while PowerNet can stage more, the plug reports `LIMITED BY: TARGET`

### ComputerCraft / KIMI

`kimi_network_plug` now exposes the same path diagnostics in `getInfo()`, `listPlugs()`, and `listNetworkPlugs(name)`:

- `attachedBlockId`
- `attachedBlockName`
- `attachedTransfer`
- `networkTransfer`
- `bottleneck`
- `direction`

One physically attached Network Plug still provides server-wide registry access and can list/control plugs in other dimensions.

KIMI Base OS `modules/powernet.lua` also adds the `list_network_plugs` command so a monitor/client can request every registered plug on a chosen network directly.

### Throughput policy

Alpha.13 intentionally keeps the alpha.12 engineering ceiling while diagnostics identify the real limiting component:

Per Network Plug:

- minimum transfer: 100 kFE/t
- default transfer: 512 MFE/t
- maximum transfer: **64 GFE/t**
- local staging buffer: **64 GFE**
- self chunk-loading

Per named network:

- shared transit buffer: **64 GFE**

The transfer engine already performs multiple NeoForge energy capability calls when required instead of being limited to one signed-int-sized call. Alpha.13 does not blindly raise the ceiling above 64 GFE/t; the new SOURCE/TARGET/NETWORK diagnostics are intended to prove where the current 1.25 GFE/t Matrix test is actually limited before increasing call volume further.

### Other devices

Wireless Charger retains inventory/armor/offhand/Curios charging, 4-96 block range, and up to 8 GFE/t charge budget.

Standalone Chunk Loader remains a low-profile one-chunk loader with CC/KIMI enable/disable control.

## Alpha.13 test path

1. Replace alpha.12 with alpha.13 and boot FTB Evolution.
2. Compare Network Plug / Wireless Charger / Chunk Loader materials and confirm they visibly belong to the same family.
3. Open Plug and Charger GUIs and compare the shell, tabs, controls, borders and spacing.
4. Confirm the Network Plug network list still exists only on the Network tab and scrolling/selection works.
5. Put an INPUT Plug on the Creative Energy source and an OUTPUT Plug on the Mekanism Induction Port; set both to `64G`.
6. Open Power Path/Statistics on both plugs and record attached-block rate, PowerNet rate, and `LIMITED BY` result.
7. Compare those figures against the Induction Matrix input monitor. This should identify SOURCE vs TARGET vs NETWORK without guessing.
8. Attach one CC:Tweaked computer to one plug and inspect `listNetworkPlugs("BASE_POWER")`; confirm attached machine, both rates and bottleneck are returned for every plug.
9. Re-test Wireless Charger and Chunk Loader before connecting Reactor Mk II.
