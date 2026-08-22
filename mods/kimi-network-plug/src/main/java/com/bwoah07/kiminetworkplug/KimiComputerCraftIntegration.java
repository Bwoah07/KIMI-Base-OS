package com.bwoah07.kiminetworkplug;

import dan200.computercraft.api.peripheral.PeripheralCapability;
import net.minecraft.server.level.ServerLevel;
import net.neoforged.neoforge.capabilities.RegisterCapabilitiesEvent;

public final class KimiComputerCraftIntegration {
    private KimiComputerCraftIntegration() {}

    public static void registerCapabilities(RegisterCapabilitiesEvent event) {
        event.registerBlockEntity(
                PeripheralCapability.get(),
                KimiNetworkPlug.NETWORK_PLUG_BLOCK_ENTITY.get(),
                (blockEntity, side) -> new NetworkPlugPeripheral(blockEntity)
        );
        event.registerBlockEntity(
                PeripheralCapability.get(),
                KimiNetworkPlug.WIRELESS_CHARGER_BLOCK_ENTITY.get(),
                (blockEntity, side) -> new WirelessChargerPeripheral(blockEntity)
        );
        event.registerBlock(
                PeripheralCapability.get(),
                (level, pos, state, blockEntity, side) -> level instanceof ServerLevel serverLevel
                        ? new ChunkLoaderPeripheral(serverLevel, pos) : null,
                KimiNetworkPlug.CHUNK_LOADER.get()
        );
    }
}
