package com.bwoah07.kiminetworkplug;

import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.saveddata.SavedData;

public final class PowerNetworkSavedData extends SavedData {
    public static final long CAPACITY = 64_000_000L;
    private static final String DATA_NAME = "kimi_network_plug_power";
    private static final SavedData.Factory<PowerNetworkSavedData> FACTORY =
            new SavedData.Factory<>(PowerNetworkSavedData::new, PowerNetworkSavedData::load);

    private long energy;

    public PowerNetworkSavedData() {
    }

    private static PowerNetworkSavedData load(CompoundTag tag, HolderLookup.Provider registries) {
        PowerNetworkSavedData data = new PowerNetworkSavedData();
        data.energy = Math.clamp(tag.getLong("Energy"), 0L, CAPACITY);
        return data;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        tag.putLong("Energy", energy);
        return tag;
    }

    public static PowerNetworkSavedData get(ServerLevel level) {
        return level.getServer().overworld().getDataStorage().computeIfAbsent(FACTORY, DATA_NAME);
    }

    public long getEnergy() {
        return energy;
    }

    public long getSpace() {
        return CAPACITY - energy;
    }

    public long addEnergy(long amount) {
        long accepted = Math.min(Math.max(0L, amount), getSpace());
        if (accepted > 0) {
            energy += accepted;
            setDirty();
        }
        return accepted;
    }

    public long removeEnergy(long amount) {
        long removed = Math.min(Math.max(0L, amount), energy);
        if (removed > 0) {
            energy -= removed;
            setDirty();
        }
        return removed;
    }
}
