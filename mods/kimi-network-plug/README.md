# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, CC:Tweaked/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.12

Alpha.12 is a focused in-game bugfix and material-quality pass based on alpha.11 testing.

### Fixed item rendering

- Network Plug first/third-person transforms are reduced so the plug no longer fills half the player's hand view.
- Wireless Charger now has explicit GUI/ground/first-person/third-person transforms so the low floor pad is visible when held instead of rendering edge-on/invisible.
- Chunk Loader uses matching item transforms for consistency.

### Fixed model flicker

The Network Plug housing was rebuilt to remove coplanar/overlapping model faces that could z-fight and flicker.

The in-world proportions remain close to alpha.11, but the side rails, front panel, status ring, neck and backplate now occupy separated planes instead of sharing surfaces.

### Smoother unified hardware materials

The generated PowerNet texture sheet moves from noisy 32px materials to deliberately smoother 64px materials.

- no high-frequency per-pixel dither/grain
- broader graphite gradients and panel seams
- smoother brushed alloy
- cleaner recessed front plate
- softer green/orange/gray/cyan status glow
- Network Plug, Wireless Charger and Chunk Loader now use the same graphite + alloy + recessed-panel material language
- cyan on infrastructure blocks is reduced to a thin status ring rather than dominating the whole top surface

The hardware still uses custom KIMI assets rather than visible vanilla Minecraft block textures.

### Throughput fix

Alpha.11 allowed a configured transfer limit of 64 GFE/t but each plug only had an 8 GFE local buffer. Because the transfer path stages energy through that local buffer, the local buffer silently imposed an 8 GFE/t ceiling even when the GUI was set to 64 GFE/t.

Alpha.12 raises each Network Plug local buffer to **64 GFE**, matching one full tick at the maximum configured plug rate. The existing multi-call NeoForge energy loop remains, so a PowerNet plug is no longer internally buffer-limited below its configured 64 GFE/t ceiling.

If a test still tops out below 64 GFE/t, the next isolation step is the source/consumer capability limit (for example the creative source or Mekanism Induction Matrix transfer cap), not the PowerNet local buffer.

### GUI cleanup

The alpha.11 layout stays intact:

- General contains only mode, transfer limit, live FE/t, local buffer and chunk loading
- Network owns the scrollable network list/create controls
- Stats owns network/local telemetry
- KIMI owns ComputerCraft/server-registry status

Alpha.12 also right-aligns long buffer/value strings so the new 64 GFE local capacity does not collide with labels, removes the redundant selected-network line at the bottom of Network, and shortens KIMI status copy so it fits cleanly.

### ComputerCraft / KIMI architecture

A computer only needs to be physically attached to **one** `kimi_network_plug` peripheral.

That peripheral talks to the server-wide PowerNet registry and can:

- `listNetworks()`
- `getNetwork(name)`
- `listPlugs()`
- `listNetworkPlugs(name)`
- `setPlugMode(id, mode)`
- `setPlugNetwork(id, network)`
- `setPlugTransferLimit(id, limit)`
- `disableNetwork(name)`

So one attached computer can show and control every registered plug on a selected network, including plugs in other dimensions.

The other PowerNet peripherals remain:

- `kimi_wireless_charger`
- `kimi_chunk_loader`

KIMI Base OS `modules/powernet.lua` continues to discover and control all three device types.

### Current backend limits

Per Network Plug:

- minimum transfer: 100 kFE/t
- default transfer: 512 MFE/t
- maximum transfer: 64 GFE/t
- local buffer: 64 GFE
- self chunk-loading

Per named network:

- shared transit buffer: 64 GFE

Named networks remain isolated and `BASE_POWER` is created automatically.

Wireless Charger retains inventory/armor/offhand/Curios charging, 4-96 block range, and up to 8 GFE/t charge budget. The standalone Chunk Loader remains a one-chunk low-profile node with CC/KIMI enable/disable control.

## Alpha.12 test path

1. Replace alpha.11 with alpha.12 and boot FTB Evolution.
2. Hold the Network Plug and Wireless Charger and verify both item transforms look sane.
3. Inspect the Network Plug in-world for any texture/model flicker while moving the camera.
4. Compare Plug / Wireless Charger / Chunk Loader materials and confirm they visibly belong to the same hardware family.
5. Check the smoother 64px materials against dark Mekanism machines and bright floors.
6. Open General / Network / KIMI and verify value strings no longer overlap or clip.
7. Set both plugs to `64G` and retest Creative Energy source -> INPUT Plug -> BASE_POWER -> OUTPUT Plug -> Induction Matrix.
8. Compare the plug LIVE rate with the Induction Matrix input rate. If both plateau at the same lower number, isolate the source and Matrix transfer caps next.
9. Attach one CC:Tweaked computer to one plug and call `listNetworkPlugs("BASE_POWER")`; confirm all BASE_POWER plugs are returned.
10. Re-test Wireless Charger and standalone Chunk Loader before connecting Reactor Mk II.
