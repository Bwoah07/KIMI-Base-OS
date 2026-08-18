# KIMI Network Plug

NeoForge 1.21.1 power transport + chunk loading mod for FTB Evolution.

## alpha.3

Two blocks:

- **Network Plug** — wireless/cross-dimensional FE transport with a proper right-click configuration GUI.
- **Chunk Loader** — keeps its containing chunk loaded while the block exists.

Every Network Plug also force-loads its own containing chunk automatically. The standalone Chunk Loader gives the same one-chunk loading behavior anywhere else in the base. Multiple KIMI loaders in the same chunk are reference-tracked so removing one does not unload a chunk still owned by another loader.

### Network Plug GUI

Right-clicking a Network Plug now opens a menu instead of cycling the mode directly.

The menu provides:

- Mode: `DISABLED`, `INPUT`, or `OUTPUT`
- Transfer limit in FE/t
- Typed custom transfer limit
- `+` / `-` preset stepping
- Default `16M FE/t` shortcut
- Maximum `2G FE/t` shortcut
- Live transfer rate
- Shared network buffer percentage

Transfer limits are stored per plug and persist across restarts.

### Appearance

The Network Plug is no longer rendered as a full cube. It uses a compact pedestal/socket-style model with a matching smaller collision/selection shape.

Mode accent colors remain:

- Gray = disabled
- Lime = input
- Orange = output

### Energy behavior

INPUT plugs can receive FE through the standard NeoForge energy capability and also pull from adjacent FE-capable blocks. OUTPUT plugs expose extract capability and also push into adjacent FE consumers.

The network uses one world-global 64,000,000 FE transit buffer in alpha.3. Because the buffer is bounded, a missing/full destination eventually stops the source rather than behaving like an infinite hidden battery.

Current transfer range per plug:

- Minimum: 100,000 FE/t
- Default: 16,000,000 FE/t
- Maximum: 2,000,000,000 FE/t

One global channel is still used for now; named networks come after the transport/UI path is proven reliable in-game.

## Test path

1. Powered Energy Cube -> INPUT Network Plug.
2. OUTPUT Network Plug -> empty Energy Cube.
3. Confirm power transfer.
4. Leave the area / change dimension and confirm both Network Plug chunks remain loaded.
5. Open each plug GUI and change mode + transfer limit.
6. Only after that passes, test Turbine -> INPUT Plug -> OUTPUT Plug -> green Induction Matrix port.

Do not use a fission reactor as the first test load. Reactor Mk I already handled that QA pass for us.
