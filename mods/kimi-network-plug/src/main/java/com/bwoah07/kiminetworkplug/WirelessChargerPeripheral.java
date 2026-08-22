package com.bwoah07.kiminetworkplug;

import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.api.peripheral.IPeripheral;
import net.minecraft.server.level.ServerLevel;
import org.jetbrains.annotations.Nullable;

import java.util.LinkedHashMap;
import java.util.Map;

public final class WirelessChargerPeripheral implements IPeripheral {
    private final WirelessChargerBlockEntity charger;

    public WirelessChargerPeripheral(WirelessChargerBlockEntity charger) { this.charger = charger; }

    @Override public String getType() { return "kimi_wireless_charger"; }
    @Override public Object getTarget() { return charger; }
    @Override public boolean equals(@Nullable IPeripheral other) { return other instanceof WirelessChargerPeripheral p && p.charger == charger; }

    @LuaFunction(mainThread = true)
    public final Map<String, Object> getInfo() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("network", charger.getNetworkName());
        out.put("range", charger.getRange());
        out.put("chargeRate", charger.getChargeRate());
        out.put("liveDraw", charger.getLastDraw());
        out.put("playersInRange", charger.getLastPlayers());
        out.put("inventory", charger.chargesInventory());
        out.put("armor", charger.chargesArmor());
        out.put("offhand", charger.chargesOffhand());
        out.put("curios", charger.chargesCurios());
        if (charger.getLevel() instanceof ServerLevel level) {
            out.put("networkStored", PowerNetworkSavedData.get(level).getEnergy(charger.getNetworkName()));
            out.put("dimension", level.dimension().location().toString());
            out.put("x", charger.getBlockPos().getX());
            out.put("y", charger.getBlockPos().getY());
            out.put("z", charger.getBlockPos().getZ());
            out.put("status", "ONLINE");
        } else {
            out.put("status", "OFFLINE");
        }
        return out;
    }

    @LuaFunction(mainThread = true) public final String getNetwork() { return charger.getNetworkName(); }
    @LuaFunction(mainThread = true) public final int getRange() { return charger.getRange(); }
    @LuaFunction(mainThread = true) public final double getChargeRate() { return charger.getChargeRate(); }
    @LuaFunction(mainThread = true) public final double getLiveDraw() { return charger.getLastDraw(); }
    @LuaFunction(mainThread = true) public final int getPlayersInRange() { return charger.getLastPlayers(); }

    @LuaFunction(mainThread = true)
    public final boolean setNetwork(String network) {
        charger.applyClientConfig(network, charger.getRange(), charger.getChargeRate(), charger.chargesInventory(), charger.chargesArmor(), charger.chargesOffhand(), charger.chargesCurios());
        return true;
    }

    @LuaFunction(mainThread = true)
    public final boolean setRange(int range) {
        charger.applyClientConfig(charger.getNetworkName(), range, charger.getChargeRate(), charger.chargesInventory(), charger.chargesArmor(), charger.chargesOffhand(), charger.chargesCurios());
        return true;
    }

    @LuaFunction(mainThread = true)
    public final boolean setChargeRate(double rate) {
        if (Double.isNaN(rate) || Double.isInfinite(rate)) return false;
        charger.applyClientConfig(charger.getNetworkName(), charger.getRange(), (long) rate, charger.chargesInventory(), charger.chargesArmor(), charger.chargesOffhand(), charger.chargesCurios());
        return true;
    }

    @LuaFunction(mainThread = true)
    public final boolean setTargetEnabled(String target, boolean enabled) {
        boolean inv = charger.chargesInventory();
        boolean armor = charger.chargesArmor();
        boolean offhand = charger.chargesOffhand();
        boolean curios = charger.chargesCurios();
        switch (target.trim().toLowerCase()) {
            case "inventory", "inv" -> inv = enabled;
            case "armor" -> armor = enabled;
            case "offhand" -> offhand = enabled;
            case "curios" -> curios = enabled;
            default -> { return false; }
        }
        charger.applyClientConfig(charger.getNetworkName(), charger.getRange(), charger.getChargeRate(), inv, armor, offhand, curios);
        return true;
    }
}
