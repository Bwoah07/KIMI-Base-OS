# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, ComputerCraft/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.7

Alpha.7 is the compact visual/UI pass requested after in-game alpha.6 testing.

### Blocks

- **Network Plug** — compact face-mounted cross-dimensional FE connector. It self-chunkloads.
- **Chunk Loader** — standalone one-chunk loader for areas that do not need a power plug.
- **KIMI Wireless Charger** — draws directly from a selected PowerNet network and wirelessly charges nearby player equipment. It does not need a Network Plug attached.

### Compact tabbed UI

The Network Plug screen is reduced from the large alpha.6 panel to a compact 196x174 card with three tabs:

- **HOME** — mode, transfer limit, live FE/t, local buffer, chunkload state
- **NETWORK** — one-click existing-network selector/dropdown, create-new-network controls, plug count, network buffer
- **KIMI** — KIMI link state, local/network buffers, network in/out FE/t, coordinates

The Wireless Charger uses the same compact visual language:

- **HOME** — network, range, rate, live draw, players in range
- **TARGETS** — inventory, armor, offhand, Curios toggles
- **STATS** — KIMI link, live draw, player count, network buffer/status

The goal is a Flux-style compact machine-panel feel without copying Flux Networks pixel-for-pixel.

### Visual polish

The Network Plug model is slimmer again: smaller machine-face plate, thinner connector neck, smaller floating head, thin colored status ring, and recessed front panel. Materials stay smooth and low-noise using dark concrete-like surfaces with light-gray trim and mode accent colors.

The Wireless Charger is also no longer a plain full cube: it now renders as a shorter dark PowerNet node with a thin metallic/cyan top assembly.

Mode accents:

- Gray = `DISABLED`
- Lime = `INPUT`
- Orange = `OUTPUT`

### PowerNet backend retained from alpha.6

Per Network Plug:

- minimum transfer: 100 kFE/t
- default transfer: 512 MFE/t
- maximum transfer: 64 GFE/t
- local plug buffer: 8 GFE

Per named network:

- shared transit buffer: 64 GFE

Named networks remain isolated from one another and `BASE_POWER` is created automatically. Existing networks are selectable from the dropdown in one click.

### KIMI Wireless Charger

The Wireless Charger is a native PowerNet device. It selects a named network and consumes FE directly from that network without requiring a physical Network Plug or cable.

Defaults/limits:

- default range: 32 blocks
- adjustable range: 4–96 blocks
- default charge rate: 512 MFE/t
- maximum charge rate: 8 GFE/t

Configurable targets:

- normal inventory
- armor
- offhand
- Curios slots when Curios is installed

### CC:Tweaked / KIMI Base OS

Network Plugs expose the `kimi_network_plug` peripheral when CC:Tweaked is installed. One attached computer can inspect and control the server-wide PowerNet registry.

KIMI Base OS includes `modules/powernet.lua` for telemetry and remote PowerNet control.

## Alpha.7 test path

1. Replace alpha.6 with alpha.7 and boot the pack.
2. Open a Network Plug and confirm the GUI is substantially smaller and tabs switch cleanly.
3. Open the NETWORK tab and verify the existing-network dropdown is one-click selectable with no overlap.
4. Confirm the slimmer plug model and hand icon still look correct from multiple mounting directions.
5. Test Energy Cube -> INPUT Plug -> named network -> OUTPUT Plug -> Energy Cube.
6. Open the Wireless Charger and test its HOME/TARGETS/STATS tabs.
7. Test normal inventory, armor, offhand and Curios wireless charging.
8. Test cross-dimensional PowerNet and chunk loading.
9. Test `peripheral.find("kimi_network_plug")` on a CC:Tweaked computer.
10. Only after harmless loads pass, connect the turbine and Induction Matrix.
