# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, CC:Tweaked/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.10

Alpha.10 is the plug-proportion, bespoke-texture, and Flux-style GUI refinement pass agreed after alpha.9 in-game testing.

### Network Plug proportions

The face-mounted Network Plug keeps the same plate -> short neck -> floating head layout, but the head is intentionally larger so it fills most of the selected block outline instead of looking undersized inside its hitbox.

The machine-facing plate and neck remain compact. The head is now approximately 10x10 pixels in cross-section with a thin status bezel and recessed front panel.

### Bespoke PowerNet textures

The built mod no longer references visible vanilla Minecraft block textures for PowerNet hardware.

Because the GitHub contents API used for development is text-only, Gradle deterministically generates the PowerNet PNG assets during the build. The alpha.10 sheet uses 32x32 purpose-made textures with:

- dark graphite metal casing with subtle panel seams and bevels
- brushed alloy mounting/trim surfaces
- recessed front/control plates
- green input glow
- orange output glow
- gray disabled glow
- cyan infrastructure glow for charger/chunk loader

Network Plug, Wireless Charger, and Chunk Loader all share this visual language.

### Flux-style floating Network Plug GUI

The Network Plug screen has been rebuilt again around the layout direction chosen from the Flux Networks reference without copying Flux assets.

- world stays visible behind the UI
- page title sits above the floating tab row
- compact icon tabs hover above the main card
- semi-transparent dark panel with cut/rounded-looking corners
- one-pixel state-coloured border
- slim custom controls rather than vanilla stone buttons
- selected network is available directly from General and Network pages
- compact segmented mode selector
- slim transfer-limit field with SET/MAX
- live FE/t, local buffer, chunk-loading state
- dedicated Network, Stats, and KIMI/ComputerCraft pages

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

So selecting `BASE_POWER` on a KIMI/CC computer can show every registered plug on `BASE_POWER`, including plugs in other dimensions, with coordinates, mode, limits, local energy, last transfer, and chunk-loaded state.

The other PowerNet peripherals remain:

- `kimi_wireless_charger`
- `kimi_chunk_loader`

KIMI Base OS `modules/powernet.lua` continues to discover and control all three device types.

### Backend retained

Per Network Plug:

- minimum transfer: 100 kFE/t
- default transfer: 512 MFE/t
- maximum transfer: 64 GFE/t
- local buffer: 8 GFE
- self chunk-loading

Per named network:

- shared transit buffer: 64 GFE

Named networks remain isolated and `BASE_POWER` is created automatically.

Wireless Charger retains inventory/armor/offhand/Curios charging, 4-96 block range, and up to 8 GFE/t charge budget. The standalone Chunk Loader remains a one-chunk low-profile node with CC/KIMI enable/disable control.

## Alpha.10 test path

1. Replace alpha.9 with alpha.10 and boot FTB Evolution.
2. Check the enlarged Network Plug head against its selection outline on multiple mounting directions.
3. Compare plug/charger/chunk-loader materials against alpha.9 and confirm there are no obvious vanilla concrete/obsidian textures.
4. Open the Network Plug and inspect General + Network + Stats + KIMI tabs at the normal GUI scale.
5. Open the network selector from General and confirm one-click network switching remains clean.
6. Test Energy Cube -> INPUT Plug -> named network -> OUTPUT Plug -> Energy Cube.
7. Test high transfer limits, cross-dimensional transport, and chunk loading.
8. Attach one CC:Tweaked computer to one plug and call `listNetworkPlugs("BASE_POWER")`; confirm all BASE_POWER plugs are returned.
9. Test Wireless Charger and standalone Chunk Loader again before connecting Reactor Mk II.
