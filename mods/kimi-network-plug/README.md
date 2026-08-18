# KIMI Network Plug

NeoForge 1.21.1 power networking + chunk loading for FTB Evolution.

## alpha.4

Two blocks:

- **Network Plug** — a small face-mounted connector for cross-dimensional FE transport.
- **Chunk Loader** — a standalone one-chunk loader for machine areas that do not need a power plug.

Every Network Plug force-loads its own containing chunk. Multiple KIMI loaders in the same chunk are reference-tracked so the chunk is only released when the final KIMI loader is removed.

### Face-mounted plug

Network Plugs now mount to the exact face clicked when placed and support all six directions. The model is a compact Flux-style connector rather than the old pedestal/fire-hydrant shape.

Mode accents:

- Gray = `DISABLED`
- Lime = `INPUT`
- Orange = `OUTPUT`

The plug only transfers with the block it is physically mounted against. Its exposed sides still provide the standard NeoForge energy capability so cables can interact with it too.

### Named networks

Power is isolated by named networks. `BASE_POWER` is created automatically and additional networks can be created simply by typing a name in the Network Plug GUI and pressing **SET / CREATE**.

Examples:

- `BASE_POWER`
- `REACTOR`
- `MINING`
- `FACTORY`
- `EMERGENCY`

Each named network has its own **64,000,000 FE shared transit buffer**. Energy never crosses between different network names.

### Per-plug buffer

Every Network Plug also has its own **64,000,000 FE local buffer**.

INPUT path:

`attached producer -> local plug buffer -> selected network buffer`

OUTPUT path:

`selected network buffer -> local plug buffer -> attached consumer`

The local buffer is persisted in the block entity and retained across restarts. Both local and shared buffers are bounded so a blocked destination eventually back-pressures the source instead of behaving like infinite storage.

### GUI

Right-clicking a Network Plug opens the configuration screen. It includes:

- `DISABLED`, `INPUT`, and `OUTPUT` mode buttons
- editable named network field with **SET / CREATE**
- `<` / `>` cycling through existing networks
- exact transfer-limit entry
- transfer-limit preset stepping
- default `16M FE/t` shortcut
- live FE/t transfer
- local plug buffer bar
- selected network buffer bar
- selected network input/output rate
- plug count on the selected network
- chunk-loaded status
- block coordinates

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

## First alpha.4 test

1. Remove the older Network Plug JAR and install alpha.4.
2. Place a powered Energy Cube.
3. Place a Network Plug directly onto its configured output face and set the plug to `INPUT` / `BASE_POWER`.
4. Place a second Network Plug directly onto an empty Energy Cube input face and set it to `OUTPUT` / `BASE_POWER`.
5. Confirm both the local buffers and the shared network buffer move FE correctly.
6. Create a second named network and confirm the two networks are isolated.
7. Move one endpoint to another dimension and confirm transport continues while the self-loaded chunks stay active.
8. Connect a CC:Tweaked computer to a Network Plug and run `peripheral.find("kimi_network_plug")` to confirm the KIMI API is visible.
9. Only after the harmless Energy Cube test passes, connect the turbine and Induction Matrix.
