# KIMI PowerNet

NeoForge 1.21.1 power networking, chunk loading, CC:Tweaked/KIMI integration, and wireless player charging for FTB Evolution.

## alpha.11

Alpha.11 is a visual-quality pass. Backend behavior from alpha.10 is intentionally preserved.

### Network Plug GUI

The floating PowerNet UI is now split cleanly by responsibility:

- **Power Plug** — mode, transfer limit, live FE/t, local buffer, chunk loading
- **Network Selection** — existing-network list, network creation, plug count, network buffer
- **Power Statistics** — network in/out, local/network buffers, selected network and coordinates
- **KIMI / ComputerCraft** — peripheral/API and server-wide registry status

The selected network no longer appears on the General page.

### Scrollable network list

The old dropdown/arrow network picker has been removed.

The Network tab now presents existing named networks as an always-visible list. Four entries are shown at once with a visible scrollbar; mouse-wheel scrolling and scrollbar clicking move through up to 32 synced network names. Clicking a row immediately moves the plug to that network. Network creation stays as a separate compact row below the list.

### Human-readable transfer limits

The transfer editor accepts readable values such as:

- `64G`
- `500M`
- `250k`
- raw FE/t numbers when desired

The UI displays human-readable FE/t values instead of leading with raw values such as `64000000000`.

### Refined visual language

The main floating panel now keeps a neutral silver/gray frame regardless of plug mode. Green/orange are limited to the selected mode, live flow/status and a small accent strip rather than wrapping the whole UI in a warning-colored border.

Top tabs use custom-drawn PowerNet icons instead of Unicode glyphs.

The generated KIMI texture sheet was also refined with deliberate graphite panel seams, bevel highlights, recessed control plates, brushed alloy, restrained status glow and shared charger/chunk-loader tech surfaces. The Network Plug model keeps its alpha.10 overall size but now uses narrow metal side rails and a much thinner four-piece status ring rather than a large picture-frame bezel.

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

## Alpha.11 test path

1. Replace alpha.10 with alpha.11 and boot FTB Evolution.
2. Inspect the Network Plug housing/status ring against dark Mekanism blocks.
3. Open General and confirm there is no network selector on that page.
4. Open Network and verify the always-visible list, mouse wheel, scrollbar and one-click network selection.
5. Create enough networks to verify scrolling and selected-row highlighting.
6. Enter transfer limits such as `64G`, `500M` and `250k` and verify they apply correctly.
7. Check Stats and KIMI pages for compact spacing and no overlaps.
8. Test Energy Cube -> INPUT Plug -> named network -> OUTPUT Plug -> Energy Cube.
9. Attach one CC:Tweaked computer to one plug and call `listNetworkPlugs("BASE_POWER")`; confirm all BASE_POWER plugs are returned.
10. Re-test Wireless Charger and standalone Chunk Loader before connecting Reactor Mk II.
