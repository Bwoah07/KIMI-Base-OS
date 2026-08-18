package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.HashSet;
import java.util.Set;

public final class ChunkLoadingSavedData extends SavedData {
    private static final String DATA_NAME = "kimi_network_plug_chunk_loaders";
    private static final SavedData.Factory<ChunkLoadingSavedData> FACTORY =
            new SavedData.Factory<>(ChunkLoadingSavedData::new, ChunkLoadingSavedData::load);

    private final Set<Long> loaderPositions = new HashSet<>();

    public ChunkLoadingSavedData() {}

    private static ChunkLoadingSavedData load(CompoundTag tag, HolderLookup.Provider registries) {
        ChunkLoadingSavedData data = new ChunkLoadingSavedData();
        for (long value : tag.getLongArray("Loaders")) data.loaderPositions.add(value);
        return data;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        long[] values = new long[loaderPositions.size()];
        int index = 0;
        for (long value : loaderPositions) values[index++] = value;
        tag.putLongArray("Loaders", values);
        return tag;
    }

    public static ChunkLoadingSavedData get(ServerLevel level) {
        return level.getDataStorage().computeIfAbsent(FACTORY, DATA_NAME);
    }

    public static boolean isRegistered(ServerLevel level, BlockPos pos) {
        return get(level).loaderPositions.contains(pos.asLong());
    }

    public static void register(ServerLevel level, BlockPos pos) {
        ChunkLoadingSavedData data = get(level);
        if (data.loaderPositions.add(pos.asLong())) data.setDirty();
        level.setChunkForced(pos.getX() >> 4, pos.getZ() >> 4, true);
    }

    public static void unregister(ServerLevel level, BlockPos pos) {
        ChunkLoadingSavedData data = get(level);
        if (data.loaderPositions.remove(pos.asLong())) data.setDirty();
        int chunkX = pos.getX() >> 4;
        int chunkZ = pos.getZ() >> 4;
        if (!data.hasLoaderInChunk(chunkX, chunkZ)) level.setChunkForced(chunkX, chunkZ, false);
    }

    private boolean hasLoaderInChunk(int chunkX, int chunkZ) {
        for (long packed : loaderPositions) {
            BlockPos pos = BlockPos.of(packed);
            if ((pos.getX() >> 4) == chunkX && (pos.getZ() >> 4) == chunkZ) return true;
        }
        return false;
    }
}
