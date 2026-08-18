# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, CC:Tweaked/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.9

Alpha.9 is the visual-language and ComputerCraft pass agreed after alpha.8 in-game testing.

### Custom KIMI hardware textures

The PowerNet family no longer depends on visible vanilla Minecraft block textures in the built JAR. The Gradle build generates a small dedicated KIMI texture set for graphite bodywork, dark graphite, metallic trim, panel surfaces, green/orange/gray status accents, and cyan infrastructure accents.

This keeps the source repository text-only while the compiled mod still contains real PNG texture assets.

### Network Plug

The Network Plug remains a tiny face-mounted connector:

- compact machine-face plate
- very short neck
- small floating head
- custom graphite body and metallic trim
- gray = disabled
- green = input
- orange = output
- self chunk-loading
- 8 GFE local buffer
- 64 GFE/t maximum transfer
- named-network dropdown/create system

### Wireless Charger

The KIMI Wireless Charger is now a low floor pad instead of a machine-sized block:

- roughly 12x12 pixel footprint
- under 5 pixels tall
- custom graphite/metal/cyan materials
- non-full-cube collision and no occlusion
- does not hide the floor block below it
- draws directly from a selected KIMI PowerNet network
- inventory, armor, offhand and Curios charging
- 4–96 block configurable range
- up to 8 GFE/t charge budget

### Chunk Loader

The standalone Chunk Loader is now a small low-profile floor puck:

- roughly 10x10 pixel footprint
- under 4 pixels tall
- custom dark graphite/metal/cyan materials
- non-full-cube collision and no occlusion
- one chunk only
- enable/disable state is persisted in KIMI chunk-loader saved data

### Floating GUI

The Network Plug and Wireless Charger interfaces now intentionally float over the live world rather than darkening the entire screen.

The visual style is inspired by the density and clarity of Flux Networks without reusing its assets:

- semi-transparent dark control card
- clipped/rounded-looking corners drawn with GUI primitives
- thin mode-colored border
- compact tabs hovering above the panel
- custom flat controls instead of large vanilla stone buttons
- slim outlined text fields
- human-readable FE/t and buffer values
- General / Network / Stats / KIMI separation on the Network Plug
- General / Targets / Stats separation on the Wireless Charger

### PowerNet backend

Per Network Plug:

- minimum transfer: 100 kFE/t
- default transfer: 512 MFE/t
- maximum transfer: 64 GFE/t
- local buffer: 8 GFE

Per named network:

- shared transit buffer: 64 GFE

Named networks are isolated and `BASE_POWER` is created automatically.

### CC:Tweaked / KIMI Base OS

All three PowerNet device types now expose CC:Tweaked peripherals when ComputerCraft is installed:

- `kimi_network_plug`
- `kimi_wireless_charger`
- `kimi_chunk_loader`

`kimi_network_plug` keeps the server-wide PowerNet API for listing networks/plugs and remotely changing plug mode, network, transfer limit, or disabling a network.

`kimi_wireless_charger` exposes charger status plus network/range/rate/target control.

`kimi_chunk_loader` exposes enabled state, dimension, chunk coordinates, block coordinates, and remote enable/disable.

KIMI Base OS `modules/powernet.lua` now discovers all three peripheral types, publishes charger/chunk-loader telemetry, and routes remote charger/chunk-loader control commands as well as existing PowerNet commands.

## Alpha.9 test path

1. Replace alpha.8 with alpha.9 and boot FTB Evolution.
2. Confirm Plug, Wireless Charger, and Chunk Loader use the new KIMI textures rather than vanilla block textures.
3. Confirm the Wireless Charger and Chunk Loader are low-profile and do not visually remove the block underneath.
4. Open a Network Plug and verify the floating panel leaves the world visible behind it and the top tabs use the custom flat style.
5. Test the Network dropdown/create path and verify no overlapping controls at your normal GUI scale.
6. Test Energy Cube -> INPUT Plug -> named network -> OUTPUT Plug -> Energy Cube at high transfer limits.
7. Test Wireless Charger inventory/armor/offhand/Curios charging.
8. Test cross-dimensional PowerNet and plug self chunk-loading.
9. On CC:Tweaked, verify `peripheral.find("kimi_network_plug")`, `peripheral.find("kimi_wireless_charger")`, and `peripheral.find("kimi_chunk_loader")`.
10. Verify KIMI OS PowerNet telemetry sees plugs, chargers and chunk loaders before connecting Reactor Mk II.
