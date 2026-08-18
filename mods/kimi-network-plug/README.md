# KIMI Network Plug

Proof-of-concept NeoForge 1.21.1 mod for FTB Evolution.

## V0.1 alpha.2 behavior

Two blocks:

- **Network Plug** — wireless/cross-dimensional FE transport. Empty-hand right-click cycles `DISABLED -> INPUT -> OUTPUT -> DISABLED`.
- **Chunk Loader** — keeps its containing chunk loaded while the block exists.

Every **Network Plug also chunk-loads its own containing chunk automatically**, so the power link does not depend on a player standing nearby. The standalone Chunk Loader gives the same chunk-loading behavior anywhere else in the base without needing a power plug.

Network Plug colors:

- Gray = disabled
- Lime = input
- Orange = output

INPUT plugs pull FE from any adjacent NeoForge-compatible energy capability into a world-global transit buffer. OUTPUT plugs push FE from that same buffer into adjacent consumers.

Current limits:

- 16,000,000 FE/t per Network Plug
- 64,000,000 FE shared transit buffer
- One global power network/channel in V0.1
- Network Plug auto-loads its own chunk
- Standalone Chunk Loader loads its own chunk
- Multiple loaders in the same chunk are reference-tracked so removing one does not unload a chunk still owned by another loader
- No GUI yet

Chunk loading uses Minecraft's persistent forced-chunk mechanism. Loader positions are also stored per dimension so removing the final KIMI loader in a chunk releases that forced chunk again.

The deliberately bounded FE buffer means a missing/full destination stops the source instead of silently creating an infinite hidden battery.

## First test

1. Place an Energy Cube or other harmless FE source next to Plug A.
2. Empty-hand right-click Plug A until it is lime / INPUT.
3. Place Plug B in another location or dimension next to an empty Energy Cube.
4. Empty-hand right-click Plug B until it is orange / OUTPUT.
5. Leave both areas and confirm the destination continues filling while their chunks remain force-loaded.
6. Break Plug B and confirm its chunk can unload again when no other KIMI loader remains there.
7. Test the standalone Chunk Loader on a separate machine area.
8. Only after this passes, test Turbine -> INPUT Plug -> OUTPUT Plug -> green Induction Matrix port.

Do not use a fission reactor as the first test load. Reactor Mk I already handled that QA pass for us.
