# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, CC:Tweaked/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.14

Alpha.14 is a focused GUI consistency and readability pass based on alpha.13 in-game screenshots.

### Shared rounded PowerNet UI

Network Plug and Wireless Charger now use the same shared `KimiUiTheme` for:

- rounded neutral-silver floating panels
- rounded fields and buttons
- rounded buffer bars and toggles
- the same charcoal/glass background treatment
- the same tab size, spacing and icon style
- smaller secondary text so values no longer collide with labels or controls

The goal is to keep the Flux-style floating-world feel while removing the large crunchy/pixel-heavy boxes and mismatched Charger presentation.

### Cleaner tab artwork

All PowerNet tabs use the same rounded tab widget and simplified artwork:

- plug connector
- network list
- power statistics
- KIMI/ComputerCraft monitor
- wireless charger
- charge targets

The old ambiguous network-node/spaghetti icon is gone.

### Wireless Charger now has a real Network tab

The Charger no longer edits a raw network name on its General page.

It now has four clean tabs:

1. Wireless Charger — range, charge rate, live draw and players in range
2. Networks — always-visible scrollable list of existing PowerNet networks
3. Charge Targets — Inventory / Armor / Offhand / Curios as clean row toggles
4. Statistics — live draw, players, network buffer, peripheral and selected network

The Charger network list is synced server-side just like the Network Plug list. Clicking an existing network immediately assigns the Charger to it.

### Network Plug readability

The Plug keeps the alpha.13 transfer-path diagnostics but uses smaller/fit-to-width labels and the shared rounded UI theme.

General remains plug-local only. Network selection remains exclusively on the Network tab.

Power Path continues to show:

- `RECEIVING FROM` / `SENDING TO`
- attached block name
- attached-block FE/t
- PowerNet FE/t
- `LIMITED BY` (`NONE`, `SOURCE`, `NETWORK`, `TARGET`, `NO BLOCK`)

### Matrix throughput result

Alpha.13 testing proved the current Mekanism Induction Matrix is the active target bottleneck: the output plug reported `LIMITED BY: TARGET` at about 1.25 GFE/t, matching the Matrix Statistics screen's 1.25 GFE/t maximum input.

PowerNet itself remains configured for up to **64 GFE/t per plug** with a **64 GFE local staging buffer** and **64 GFE shared network buffer**.

To exceed the current ~1.25 GFE/t into that Matrix, increase the Matrix's own transfer capacity (more providers / higher Matrix transfer cap) or feed a high-draw machine directly from PowerNet instead of routing through that Matrix.

### ComputerCraft / KIMI

`kimi_network_plug` continues to expose server-wide network/plug control and the full path diagnostics:

- `attachedBlockId`
- `attachedBlockName`
- `attachedTransfer`
- `networkTransfer`
- `bottleneck`
- `direction`

A computer only needs to be physically attached to one Network Plug to list/control all registered PowerNet plugs.

Wireless Charger remains available as `kimi_wireless_charger`; Chunk Loader remains `kimi_chunk_loader`.

## Alpha.14 test path

1. Replace alpha.13 with alpha.14 and boot FTB Evolution.
2. Open Plug General / Network / Power Path and confirm rounded corners and no clipped/overlapping text.
3. Open Wireless Charger and confirm its panel/tabs now visibly match the Plug.
4. Open the Charger's Network tab and verify the scrollable PowerNet network list and one-click selection.
5. Open Charge Targets and verify the four compact row toggles are readable and do not overlap.
6. Confirm General no longer contains the Charger network selector.
7. Re-test the Matrix path; it should still report TARGET around the Matrix's ~1.25 GFE/t cap.
8. Re-test Wireless Charger actual item charging after selecting `BASE_POWER` from the list.
9. Re-test CC/KIMI registry access before Reactor Mk II.
