# KIMI Network Plug

NeoForge 1.21.1 power networking + chunk loading for FTB Evolution.

## alpha.5

Alpha.5 is the visual cleanup pass on top of the alpha.4 PowerNet backend.

Two blocks remain:

- **Network Plug** — a compact face-mounted connector for cross-dimensional FE transport.
- **Chunk Loader** — a standalone one-chunk loader for machine areas that do not need a power plug.

Every Network Plug force-loads its own containing chunk. Multiple KIMI loaders in the same chunk are reference-tracked so the chunk is only released when the final KIMI loader is removed.

### Compact Flux-style plug

The Network Plug now uses the intended connector silhouette rather than a pedestal/machine shape:

- small mounting plate flush to the clicked machine face
- short connector neck
- compact floating cube head
- centered on the clicked face
- supports all six directions
- never rests on the floor unless it was actually mounted to the floor face

Mode accents remain:

- Gray = `DISABLED`
- Lime = `INPUT`
- Orange = `OUTPUT`

The plug only transfers with the block it is physically mounted against. Its exposed sides still provide the standard NeoForge energy capability so cables can interact with it too.

### Clean GUI

Right-clicking opens a deliberately compact configuration card inspired by the clarity of Flux Networks without cloning its interface.

The alpha.5 screen has four non-overlapping bands:

- mode: `DISABLED`, `INPUT`, `OUTPUT`
- network: `<`, editable network name, `>`, `APPLY`
- transfer limit: `-`, exact numeric entry, `SET`, `+`, `16M`
- live status: live FE/t, network input/output, local buffer, network buffer, plug count, chunk-loaded state, and coordinates

The noisy helper text and overlapping controls from alpha.4 are removed.

### Named networks

Power is isolated by named networks. `BASE_POWER` is created automatically and additional networks can be created by typing a name in the Network Plug GUI and pressing **APPLY**.

Examples:

- `BASE_POWER`
- `REACTOR`
- `MINING`
- `FACTORY`
- `EMERGENCY`

Each named network has its own **64,000,000 FE shared transit buffer**. Energy never crosses between different network names.

### Per-plug buffer

Every Network Plug has its own **64,000,000 FE local buffer**.

INPUT path:

`attached producer -> local plug buffer -> selected network buffer`

OUTPUT path:

`selected network buffer -> local plug buffer -> attached consumer`

The local buffer is persisted in the block entity and retained across restarts. Both local and shared buffers are bounded so a blocked destination eventually back-pressures the source instead of behaving like infinite storage.

### Transfer limits

Transfer limits are persisted per plug:

- minimum: 100,000 FE/t
- default: 16,000,000 FE/t
- maximum: 2,000,000,000 FE/t

### CC:Tweaked / KIMI Base OS

When CC:Tweaked is installed, every Network Plug exposes a `kimi_network_plug` peripheral. A ComputerCraft computer only needs access to one plug peripheral to inspect and control the server-wide KIMI PowerNet registry.

Peripheral operations include:

- `getInfo()`
- `listNetworks()`
- `getNetwork(name)`
- `listPlugs()`
- `listNetworkPlugs(name)`
- `setPlugMode(id, mode)`
- `setPlugNetwork(id, network)`
- `setPlugTransferLimit(id, limit)`
- `disableNetwork(name)`

KIMI Base OS includes `modules/powernet.lua`, which automatically detects the peripheral, publishes all PowerNet telemetry to KIMI, and exposes the remote control operations through a KIMI node.

## Alpha.5 test

1. Remove the older Network Plug JAR and install alpha.5.
2. Confirm the plug appears as a small plate + neck + cube head attached to the clicked machine face.
3. Open the GUI and confirm there is no overlapping text or controls.
4. Powered Energy Cube -> INPUT Plug on `BASE_POWER`.
5. OUTPUT Plug on `BASE_POWER` -> empty Energy Cube.
6. Confirm local and network buffers transfer correctly.
7. Create a second named network and confirm isolation.
8. Move one endpoint to another dimension and confirm transport continues while chunks stay loaded.
9. Connect a CC:Tweaked computer and confirm `peripheral.find("kimi_network_plug")` sees the PowerNet API.
10. Only after the harmless Energy Cube test passes, connect the turbine and Induction Matrix.
