# KIMI Network Plug

Proof-of-concept NeoForge 1.21.1 mod for FTB Evolution.

## V0.1 behavior

One block: **Network Plug**.

Empty-hand right-click cycles:

`DISABLED -> INPUT -> OUTPUT -> DISABLED`

The block color shows the current mode:

- Gray = disabled
- Lime = input
- Orange = output

INPUT plugs pull FE from any adjacent NeoForge-compatible energy capability into a world-global transit buffer. OUTPUT plugs push FE from that same buffer into adjacent consumers. Because the buffer is stored on the server Overworld, plugs can bridge dimensions as long as both plug chunks are loaded/ticking.

Current limits:

- 16,000,000 FE/t per plug
- 64,000,000 FE shared transit buffer
- One global network/channel in V0.1
- No chunk loading
- No GUI yet

The deliberately bounded buffer means a missing/full destination stops the source instead of silently creating an infinite hidden battery.

## First test

1. Place an Energy Cube or other harmless FE source next to Plug A.
2. Empty-hand right-click Plug A until it is lime / INPUT.
3. Place Plug B in another location or dimension next to an empty Energy Cube.
4. Empty-hand right-click Plug B until it is orange / OUTPUT.
5. Keep both chunks loaded and confirm the destination fills.
6. Only after this passes, test Turbine -> INPUT Plug -> OUTPUT Plug -> green Induction Matrix port.

Do not use a fission reactor as the first test load. Reactor Mk I already handled that QA pass for us.
