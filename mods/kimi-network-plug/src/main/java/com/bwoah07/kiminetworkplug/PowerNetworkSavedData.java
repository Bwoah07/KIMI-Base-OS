package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;

public final class PowerNetworkSavedData extends SavedData {
    public static final long NETWORK_CAPACITY = 64_000_000_000L;
    public static final String DEFAULT_NETWORK = "BASE_POWER";
    public static final int MAX_NETWORK_NAME_LENGTH = 24;

    private static final String DATA_NAME = "kimi_network_plug_power";
    private static final SavedData.Factory<PowerNetworkSavedData> FACTORY =
            new SavedData.Factory<>(PowerNetworkSavedData::new, PowerNetworkSavedData::load);

    private final Map<String, NetworkState> networks = new TreeMap<>();
    private final Map<UUID, PlugRecord> plugs = new LinkedHashMap<>();

    public PowerNetworkSavedData() { ensureNetwork(DEFAULT_NETWORK); }

    private static PowerNetworkSavedData load(CompoundTag tag, HolderLookup.Provider registries) {
        PowerNetworkSavedData data = new PowerNetworkSavedData();
        data.networks.clear();
        if (tag.contains("Networks")) {
            CompoundTag networksTag = tag.getCompound("Networks");
            for (String rawName : networksTag.getAllKeys()) {
                String name = normalizeNetworkName(rawName);
                long energy = clampEnergy(networksTag.getLong(rawName));
                data.networks.put(name, new NetworkState(energy));
            }
        } else if (tag.contains("Energy")) {
            data.networks.put(DEFAULT_NETWORK, new NetworkState(clampEnergy(tag.getLong("Energy"))));
        }
        data.ensureNetwork(DEFAULT_NETWORK);
        return data;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        CompoundTag networksTag = new CompoundTag();
        for (Map.Entry<String, NetworkState> entry : networks.entrySet()) {
            networksTag.putLong(entry.getKey(), clampEnergy(entry.getValue().energy));
        }
        tag.put("Networks", networksTag);
        return tag;
    }

    public static PowerNetworkSavedData get(ServerLevel level) {
        return level.getServer().overworld().getDataStorage().computeIfAbsent(FACTORY, DATA_NAME);
    }

    public static String normalizeNetworkName(String value) {
        String name = value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
        name = name.replaceAll("[^A-Z0-9_-]", "_");
        while (name.contains("__")) name = name.replace("__", "_");
        if (name.length() > MAX_NETWORK_NAME_LENGTH) name = name.substring(0, MAX_NETWORK_NAME_LENGTH);
        if (name.isBlank()) name = DEFAULT_NETWORK;
        return name;
    }

    private static long clampEnergy(long value) { return Math.max(0L, Math.min(NETWORK_CAPACITY, value)); }

    private NetworkState ensureNetwork(String rawName) {
        String name = normalizeNetworkName(rawName);
        NetworkState existing = networks.get(name);
        if (existing != null) return existing;
        NetworkState created = new NetworkState(0L);
        networks.put(name, created);
        setDirty();
        return created;
    }

    public void createNetwork(String rawName) { ensureNetwork(rawName); }

    public List<String> getNetworkNames() {
        if (networks.isEmpty()) ensureNetwork(DEFAULT_NETWORK);
        return List.copyOf(networks.keySet());
    }

    public String cycleNetwork(String current, int direction) {
        List<String> names = getNetworkNames();
        if (names.isEmpty()) return DEFAULT_NETWORK;
        String normalized = normalizeNetworkName(current);
        int index = names.indexOf(normalized);
        if (index < 0) index = 0;
        index = Math.floorMod(index + (direction < 0 ? -1 : 1), names.size());
        return names.get(index);
    }

    public long getEnergy(String networkName) { return ensureNetwork(networkName).energy; }
    public long getSpace(String networkName) { return NETWORK_CAPACITY - getEnergy(networkName); }

    public long addEnergy(String networkName, long amount, long gameTime) {
        if (amount <= 0) return 0L;
        NetworkState state = ensureNetwork(networkName);
        state.prepareTick(gameTime);
        long accepted = Math.min(amount, NETWORK_CAPACITY - state.energy);
        if (accepted > 0) {
            state.energy += accepted;
            state.inputThisTick += accepted;
            setDirty();
        }
        return accepted;
    }

    public long removeEnergy(String networkName, long amount, long gameTime) {
        if (amount <= 0) return 0L;
        NetworkState state = ensureNetwork(networkName);
        state.prepareTick(gameTime);
        long removed = Math.min(amount, state.energy);
        if (removed > 0) {
            state.energy -= removed;
            state.outputThisTick += removed;
            setDirty();
        }
        return removed;
    }

    public long getInputRate(String networkName, long gameTime) {
        NetworkState state = ensureNetwork(networkName);
        return state.statsTick == gameTime ? state.inputThisTick : 0L;
    }

    public long getOutputRate(String networkName, long gameTime) {
        NetworkState state = ensureNetwork(networkName);
        return state.statsTick == gameTime ? state.outputThisTick : 0L;
    }

    public int getPlugCount(String networkName) {
        String normalized = normalizeNetworkName(networkName);
        int count = 0;
        for (PlugRecord record : plugs.values()) if (record.network().equals(normalized)) count++;
        return count;
    }

    public void updatePlug(NetworkPlugBlockEntity plug, ServerLevel level) {
        String networkName = normalizeNetworkName(plug.getNetworkName());
        ensureNetwork(networkName);
        plugs.put(plug.getPlugId(), new PlugRecord(
                plug.getPlugId(), level.dimension(), plug.getBlockPos().immutable(), networkName,
                plug.getMode(), plug.getTransferLimit(), plug.getLocalEnergy(), plug.getLastTransfer(), true));
    }

    public void unregisterPlug(UUID id) { plugs.remove(id); }

    public List<PlugRecord> getPlugRecords() {
        List<PlugRecord> out = new ArrayList<>(plugs.values());
        out.sort(Comparator.comparing((PlugRecord p) -> p.network())
                .thenComparing(p -> p.dimension().location().toString())
                .thenComparingInt(p -> p.pos().getX())
                .thenComparingInt(p -> p.pos().getY())
                .thenComparingInt(p -> p.pos().getZ()));
        return out;
    }

    public List<PlugRecord> getPlugRecords(String networkName) {
        String normalized = normalizeNetworkName(networkName);
        List<PlugRecord> out = new ArrayList<>();
        for (PlugRecord record : getPlugRecords()) if (record.network().equals(normalized)) out.add(record);
        return out;
    }

    public NetworkSnapshot snapshot(String networkName, long gameTime) {
        String normalized = normalizeNetworkName(networkName);
        return new NetworkSnapshot(normalized, getEnergy(normalized), NETWORK_CAPACITY,
                getInputRate(normalized, gameTime), getOutputRate(normalized, gameTime), getPlugCount(normalized));
    }

    public NetworkPlugBlockEntity resolvePlug(MinecraftServer server, UUID id) {
        PlugRecord record = plugs.get(id);
        if (record == null) return null;
        ServerLevel level = server.getLevel(record.dimension());
        if (level == null) return null;
        BlockEntity blockEntity = level.getBlockEntity(record.pos());
        if (blockEntity instanceof NetworkPlugBlockEntity plug && plug.getPlugId().equals(id)) return plug;
        plugs.remove(id);
        return null;
    }

    private static final class NetworkState {
        private long energy;
        private long statsTick = Long.MIN_VALUE;
        private long inputThisTick;
        private long outputThisTick;
        private NetworkState(long energy) { this.energy = clampEnergy(energy); }
        private void prepareTick(long gameTime) {
            if (statsTick == gameTime) return;
            statsTick = gameTime;
            inputThisTick = 0L;
            outputThisTick = 0L;
        }
    }

    public record NetworkSnapshot(String name, long energy, long capacity, long input, long output, int plugs) {}
    public record PlugRecord(UUID id, ResourceKey<Level> dimension, BlockPos pos, String network, PlugMode mode,
                             long transferLimit, long localEnergy, long lastTransfer, boolean chunkLoaded) {}
}
