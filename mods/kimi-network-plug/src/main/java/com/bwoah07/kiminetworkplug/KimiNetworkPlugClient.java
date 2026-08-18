package com.bwoah07.kiminetworkplug;

import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.client.event.RegisterMenuScreensEvent;

@Mod(value = KimiNetworkPlug.MODID, dist = Dist.CLIENT)
public final class KimiNetworkPlugClient {
    public KimiNetworkPlugClient(IEventBus modEventBus) {
        modEventBus.addListener(this::registerScreens);
    }

    private void registerScreens(RegisterMenuScreensEvent event) {
        event.register(KimiNetworkPlug.NETWORK_PLUG_MENU.get(), NetworkPlugScreen::new);
        event.register(KimiNetworkPlug.WIRELESS_CHARGER_MENU.get(), WirelessChargerScreen::new);
    }
}
