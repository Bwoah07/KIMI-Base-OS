package com.bwoah07.kiminetworkplug;

import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.api.peripheral.IPeripheral;
import net.minecraft.server.level.ServerLevel;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

public final class NetworkPlugPeripheral implements IPeripheral {
    private final NetworkPlugBlockEntity plug;

    public NetworkPlugPeripheral(NetworkPlugBlockEntity plug) { this.plug = plug; }

    @Override public String getType() { return "kimi_network_plug"; }
    @Override public Object getTarget() { return plug; }
    @Override public boolean equals(@Nullable IPeripheral other) { return other instanceof NetworkPlugPeripheral p && p.plug == plug; }

    @LuaFunction(mainThread = true)
    public final String getVersion() { return "0.1.0-alpha.12"; }

    @LuaFunction(mainThread = true)
    public final Map<String, Object> getInfo() {
        ServerLevel level = serverLevel();
        if (level == null) return Map.of("status", "OFFLINE");
        PowerNetworkSavedData data = PowerNetworkSavedData.get(level);
        PowerNetworkSavedData.NetworkSnapshot network = data.snapshot(plug.getNetworkName(), level.getGameTime());
        Map<String, Object> out = plugMap(new PowerNetworkSavedData.PlugRecord(
                plug.getPlugId(), level.dimension(), plug.getBlockPos().immutable(), plug.getNetworkName(), plug.getMode(),
                plug.getTransferLimit(), plug.getLocalEnergy(), plug.getLastTransfer(), true));
        out.put("networkStored", network.energy());
        out.put("networkCapacity", network.capacity());
        out.put("networkInput", network.input());
        out.put("networkOutput", network.output());
        out.put("networkPlugCount", network.plugs());
        out.put("status", "ONLINE");
        return out;
    }

    @LuaFunction(mainThread = true)
    public final List<Map<String, Object>> listNetworks() {
        ServerLevel level = serverLevel();
        if (level == null) return List.of();
        PowerNetworkSavedData data = PowerNetworkSavedData.get(level);
        long gameTime = level.getGameTime();
        List<Map<String, Object>> out = new ArrayList<>();
        for (String name : data.getNetworkNames()) out.add(networkMap(data.snapshot(name, gameTime)));
        return out;
    }

    @LuaFunction(mainThread = true)
    public final Map<String, Object> getNetwork(String networkName) {
        ServerLevel level = serverLevel();
        if (level == null) return Map.of("status", "OFFLINE");
        Map<String, Object> out = networkMap(PowerNetworkSavedData.get(level).snapshot(networkName, level.getGameTime()));
        out.put("status", "ONLINE");
        return out;
    }

    @LuaFunction(mainThread = true)
    public final List<Map<String, Object>> listPlugs() {
        ServerLevel level = serverLevel();
        if (level == null) return List.of();
        List<Map<String, Object>> out = new ArrayList<>();
        for (PowerNetworkSavedData.PlugRecord record : PowerNetworkSavedData.get(level).getPlugRecords()) out.add(plugMap(record));
        return out;
    }

    @LuaFunction(mainThread = true)
    public final List<Map<String, Object>> listNetworkPlugs(String networkName) {
        ServerLevel level = serverLevel();
        if (level == null) return List.of();
        List<Map<String, Object>> out = new ArrayList<>();
        for (PowerNetworkSavedData.PlugRecord record : PowerNetworkSavedData.get(level).getPlugRecords(networkName)) out.add(plugMap(record));
        return out;
    }

    @LuaFunction(mainThread = true)
    public final boolean setPlugMode(String plugId, String mode) {
        NetworkPlugBlockEntity target = resolve(plugId);
        if (target == null) return false;
        try { target.setMode(PlugMode.valueOf(mode.trim().toUpperCase(Locale.ROOT))); return true; }
        catch (IllegalArgumentException ignored) { return false; }
    }

    @LuaFunction(mainThread = true)
    public final boolean setPlugNetwork(String plugId, String networkName) {
        NetworkPlugBlockEntity target = resolve(plugId);
        if (target == null) return false;
        target.setNetworkName(networkName);
        return true;
    }

    @LuaFunction(mainThread = true)
    public final boolean setPlugTransferLimit(String plugId, double transferLimit) {
        NetworkPlugBlockEntity target = resolve(plugId);
        if (target == null || Double.isNaN(transferLimit) || Double.isInfinite(transferLimit)) return false;
        target.setTransferLimit((long) transferLimit);
        return true;
    }

    @LuaFunction(mainThread = true)
    public final int disableNetwork(String networkName) {
        ServerLevel level = serverLevel();
        if (level == null) return 0;
        PowerNetworkSavedData data = PowerNetworkSavedData.get(level);
        int changed = 0;
        for (PowerNetworkSavedData.PlugRecord record : data.getPlugRecords(networkName)) {
            NetworkPlugBlockEntity target = data.resolvePlug(level.getServer(), record.id());
            if (target != null && target.getMode() != PlugMode.DISABLED) { target.setMode(PlugMode.DISABLED); changed++; }
        }
        return changed;
    }

    private @Nullable NetworkPlugBlockEntity resolve(String rawId) {
        ServerLevel level = serverLevel();
        if (level == null) return null;
        try { return PowerNetworkSavedData.get(level).resolvePlug(level.getServer(), UUID.fromString(rawId)); }
        catch (IllegalArgumentException ignored) { return null; }
    }

    private @Nullable ServerLevel serverLevel() { return plug.getLevel() instanceof ServerLevel serverLevel ? serverLevel : null; }

    private static Map<String, Object> networkMap(PowerNetworkSavedData.NetworkSnapshot snapshot) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("name", snapshot.name());
        out.put("stored", snapshot.energy());
        out.put("capacity", snapshot.capacity());
        out.put("input", snapshot.input());
        out.put("output", snapshot.output());
        out.put("net", snapshot.input() - snapshot.output());
        out.put("plugs", snapshot.plugs());
        out.put("fill", snapshot.capacity() <= 0 ? 0.0 : snapshot.energy() / (double) snapshot.capacity());
        return out;
    }

    private static Map<String, Object> plugMap(PowerNetworkSavedData.PlugRecord record) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("id", record.id().toString());
        out.put("dimension", record.dimension().location().toString());
        out.put("x", record.pos().getX());
        out.put("y", record.pos().getY());
        out.put("z", record.pos().getZ());
        out.put("network", record.network());
        out.put("mode", record.mode().name());
        out.put("transferLimit", record.transferLimit());
        out.put("localStored", record.localEnergy());
        out.put("localCapacity", NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY);
        out.put("lastTransfer", record.lastTransfer());
        out.put("chunkLoaded", record.chunkLoaded());
        return out;
    }
}
