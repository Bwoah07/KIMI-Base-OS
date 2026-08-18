package com.bwoah07.kiminetworkplug;

import dan200.computercraft.api.peripheral.PeripheralCapability;
import net.neoforged.neoforge.capabilities.RegisterCapabilitiesEvent;

public final class KimiComputerCraftIntegration {
    private KimiComputerCraftIntegration() {
    }

    public static void registerCapabilities(RegisterCapabilitiesEvent event) {
        event.registerBlockEntity(
                PeripheralCapability.get(),
                KimiNetworkPlug.NETWORK_PLUG_BLOCK_ENTITY.get(),
                (blockEntity, side) -> new NetworkPlugPeripheral(blockEntity)
        );
    }
}
