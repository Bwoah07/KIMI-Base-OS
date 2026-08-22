package com.bwoah07.kiminetworkplug;

import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.api.peripheral.IPeripheral;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import org.jetbrains.annotations.Nullable;

import java.util.LinkedHashMap;
import java.util.Map;

public final class ChunkLoaderPeripheral implements IPeripheral {
    private final ServerLevel level;
    private final BlockPos pos;

    public ChunkLoaderPeripheral(ServerLevel level, BlockPos pos) {
        this.level = level;
        this.pos = pos.immutable();
    }

    @Override public String getType() { return "kimi_chunk_loader"; }
    @Override public Object getTarget() { return pos; }
    @Override public boolean equals(@Nullable IPeripheral other) {
        return other instanceof ChunkLoaderPeripheral p && p.level == level && p.pos.equals(pos);
    }

    @LuaFunction(mainThread = true)
    public final Map<String, Object> getInfo() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("enabled", ChunkLoaderBlock.isEnabled(level, pos));
        out.put("chunkX", pos.getX() >> 4);
        out.put("chunkZ", pos.getZ() >> 4);
        out.put("dimension", level.dimension().location().toString());
        out.put("x", pos.getX());
        out.put("y", pos.getY());
        out.put("z", pos.getZ());
        out.put("status", level.getBlockState(pos).is(KimiNetworkPlug.CHUNK_LOADER.get()) ? "ONLINE" : "REMOVED");
        return out;
    }

    @LuaFunction(mainThread = true) public final boolean isChunkLoaded() { return ChunkLoaderBlock.isEnabled(level, pos); }
    @LuaFunction(mainThread = true) public final boolean isEnabled() { return ChunkLoaderBlock.isEnabled(level, pos); }
    @LuaFunction(mainThread = true) public final int getChunkX() { return pos.getX() >> 4; }
    @LuaFunction(mainThread = true) public final int getChunkZ() { return pos.getZ() >> 4; }
    @LuaFunction(mainThread = true) public final String getDimension() { return level.dimension().location().toString(); }

    @LuaFunction(mainThread = true)
    public final boolean setEnabled(boolean enabled) {
        if (!level.getBlockState(pos).is(KimiNetworkPlug.CHUNK_LOADER.get())) return false;
        ChunkLoaderBlock.setEnabled(level, pos, enabled);
        return true;
    }
}
