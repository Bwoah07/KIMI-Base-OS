# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, ComputerCraft/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.6

Alpha.6 adds the requested usability and throughput pass.

### Blocks

- **Network Plug** — compact face-mounted cross-dimensional FE connector. It self-chunkloads.
- **Chunk Loader** — standalone one-chunk loader for areas that do not need a power plug.
- **KIMI Wireless Charger** — draws directly from a selected PowerNet network and wirelessly charges nearby player equipment. It does not need a Network Plug attached.

### Network Plug

The plug keeps the face-mounted plate + short neck + compact head design, but now uses smoother black-concrete-based materials. The item/hand display transform also shows the actual connector silhouette instead of reading like a generic cube.

Mode accents:

- Gray = `DISABLED`
- Lime = `INPUT`
- Orange = `OUTPUT`

The GUI now uses an actual network selector: click the selected network, pick an existing network from the dropdown, done. A separate field creates new named networks. Up to 12 networks are shown directly in the selector.

Named networks remain isolated from one another. `BASE_POWER` is created automatically.

### Throughput and buffers

Per Network Plug:

- minimum transfer: 100 kFE/t
- default transfer: 512 MFE/t
- maximum transfer: 64 GFE/t
- local plug buffer: 8 GFE

Per named network:

- shared transit buffer: 64 GFE

NeoForge energy capability calls use integer-sized transfers, so alpha.6 safely performs multiple capability operations per tick when a configured transfer limit is above the per-call integer limit.

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

It charges any compatible item exposing NeoForge's item energy capability and reports current players in range, live FE draw, and selected-network energy in its GUI.

### CC:Tweaked / KIMI Base OS

Network Plugs expose the `kimi_network_plug` peripheral when CC:Tweaked is installed. One attached computer can inspect and control the server-wide PowerNet registry.

Operations include `getInfo()`, `listNetworks()`, `getNetwork(name)`, `listPlugs()`, `listNetworkPlugs(name)`, `setPlugMode(id, mode)`, `setPlugNetwork(id, network)`, `setPlugTransferLimit(id, limit)`, and `disableNetwork(name)`.

KIMI Base OS includes `modules/powernet.lua` for telemetry and remote PowerNet control.

## Alpha.6 test path

1. Replace alpha.5 with alpha.6 and boot the pack.
2. Confirm the Network Plug icon and in-world model look correct.
3. Open a plug and test the network dropdown by selecting an existing network in one click.
4. Test Energy Cube -> INPUT Plug -> named network -> OUTPUT Plug -> Energy Cube.
5. Raise the transfer limit and confirm throughput scales without duping or losing FE.
6. Place the KIMI Wireless Charger, select `BASE_POWER`, and test a chargeable inventory/armor/offhand item.
7. Test a chargeable Curios item.
8. Test cross-dimensional PowerNet and chunk loading.
9. Test `peripheral.find("kimi_network_plug")` on a CC:Tweaked computer.
10. Only after harmless loads pass, connect the turbine and Induction Matrix.
