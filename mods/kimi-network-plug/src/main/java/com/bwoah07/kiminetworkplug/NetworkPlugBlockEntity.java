package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.energy.IEnergyStorage;

import java.util.UUID;

public final class NetworkPlugBlockEntity extends BlockEntity {
    public static final long DEFAULT_TRANSFER_LIMIT = 512_000_000L;
    public static final long MIN_TRANSFER_LIMIT = 100_000L;
    public static final long MAX_TRANSFER_LIMIT = 64_000_000_000L;
    // The local buffer must be at least one full max-rate tick. Alpha.11 used
    // 8 GFE here, which silently capped a nominal 64 GFE/t plug to 8 GFE/t.
    public static final long LOCAL_BUFFER_CAPACITY = 64_000_000_000L;

    private UUID plugId = UUID.randomUUID();
    private String networkName = PowerNetworkSavedData.DEFAULT_NETWORK;
    private long localEnergy;
    private long lastTransfer;
    private long transferLimit = DEFAULT_TRANSFER_LIMIT;
    private final IEnergyStorage energyCapability = new PlugEnergyStorage();

    public NetworkPlugBlockEntity(BlockPos pos, BlockState state) {
        super(KimiNetworkPlug.NETWORK_PLUG_BLOCK_ENTITY.get(), pos, state);
    }

    public UUID getPlugId() { return plugId; }
    public String getNetworkName() { return networkName; }
    public long getLocalEnergy() { return localEnergy; }
    public long getLocalSpace() { return LOCAL_BUFFER_CAPACITY - localEnergy; }
    public long getLastTransfer() { return lastTransfer; }
    public long getTransferLimit() { return transferLimit; }

    public PlugMode getMode() {
        BlockState state = getBlockState();
        return state.hasProperty(NetworkPlugBlock.MODE) ? state.getValue(NetworkPlugBlock.MODE) : PlugMode.DISABLED;
    }

    public Direction getFacing() {
        BlockState state = getBlockState();
        return state.hasProperty(NetworkPlugBlock.FACING) ? state.getValue(NetworkPlugBlock.FACING) : Direction.NORTH;
    }

    public void setTransferLimit(long transferLimit) {
        this.transferLimit = Math.max(MIN_TRANSFER_LIMIT, Math.min(MAX_TRANSFER_LIMIT, transferLimit));
        setChangedAndSync();
    }

    public void setNetworkName(String networkName) {
        this.networkName = PowerNetworkSavedData.normalizeNetworkName(networkName);
        if (level instanceof ServerLevel serverLevel) PowerNetworkSavedData.get(serverLevel).createNetwork(this.networkName);
        setChangedAndSync();
    }

    public void cycleNetwork(int direction) {
        if (!(level instanceof ServerLevel serverLevel)) return;
        PowerNetworkSavedData data = PowerNetworkSavedData.get(serverLevel);
        setNetworkName(data.cycleNetwork(networkName, direction));
    }

    public void setMode(PlugMode mode) {
        if (level == null || !getBlockState().hasProperty(NetworkPlugBlock.MODE)) return;
        BlockState oldState = getBlockState();
        level.setBlock(worldPosition, oldState.setValue(NetworkPlugBlock.MODE, mode), Block.UPDATE_ALL);
        level.invalidateCapabilities(worldPosition);
        setChangedAndSync();
    }

    private void setChangedAndSync() {
        setChanged();
        if (level != null) level.sendBlockUpdated(worldPosition, getBlockState(), getBlockState(), Block.UPDATE_CLIENTS);
        syncRegistry();
    }

    private void syncRegistry() {
        if (level instanceof ServerLevel serverLevel) PowerNetworkSavedData.get(serverLevel).updatePlug(this, serverLevel);
    }

    public IEnergyStorage getEnergyCapability() { return energyCapability; }

    @Override
    protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        tag.putString("PlugId", plugId.toString());
        tag.putString("Network", networkName);
        tag.putLong("LocalEnergy", localEnergy);
        tag.putLong("TransferLimit", transferLimit);
    }

    @Override
    protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        if (tag.contains("PlugId")) {
            try { plugId = UUID.fromString(tag.getString("PlugId")); }
            catch (IllegalArgumentException ignored) { plugId = UUID.randomUUID(); }
        }
        networkName = tag.contains("Network") ? PowerNetworkSavedData.normalizeNetworkName(tag.getString("Network")) : PowerNetworkSavedData.DEFAULT_NETWORK;
        localEnergy = Math.max(0L, Math.min(LOCAL_BUFFER_CAPACITY, tag.getLong("LocalEnergy")));
        long savedLimit;
        if (tag.contains("TransferLimit")) savedLimit = tag.getLong("TransferLimit");
        else savedLimit = DEFAULT_TRANSFER_LIMIT;
        transferLimit = Math.max(MIN_TRANSFER_LIMIT, Math.min(MAX_TRANSFER_LIMIT, savedLimit));
    }

    public static void serverTick(Level level, BlockPos pos, BlockState state, NetworkPlugBlockEntity blockEntity) {
        if (!(level instanceof ServerLevel serverLevel)) return;
        blockEntity.networkName = PowerNetworkSavedData.normalizeNetworkName(blockEntity.networkName);
        PowerNetworkSavedData network = PowerNetworkSavedData.get(serverLevel);
        network.createNetwork(blockEntity.networkName);

        PlugMode mode = state.getValue(NetworkPlugBlock.MODE);
        long moved;
        if (mode == PlugMode.INPUT) {
            pullAttachedBlockIntoLocal(serverLevel, pos, state, blockEntity);
            moved = flushLocalIntoNetwork(serverLevel, blockEntity);
        } else if (mode == PlugMode.OUTPUT) {
            fillLocalFromNetwork(serverLevel, blockEntity);
            moved = pushLocalIntoAttachedBlock(serverLevel, pos, state, blockEntity);
        } else moved = 0L;

        blockEntity.lastTransfer = moved;
        network.updatePlug(blockEntity, serverLevel);
    }

    private static void pullAttachedBlockIntoLocal(ServerLevel level, BlockPos pos, BlockState state, NetworkPlugBlockEntity blockEntity) {
        if (blockEntity.getLocalSpace() <= 0) return;
        Direction facing = state.getValue(NetworkPlugBlock.FACING);
        Direction towardAttached = facing.getOpposite();
        IEnergyStorage storage = level.getCapability(Capabilities.EnergyStorage.BLOCK, pos.relative(towardAttached), facing);
        if (storage == null || !storage.canExtract()) return;

        long budget = Math.min(blockEntity.transferLimit, blockEntity.getLocalSpace());
        long moved = 0L;
        while (budget > 0 && blockEntity.getLocalSpace() > 0) {
            int requested = (int) Math.min(Math.min(budget, blockEntity.getLocalSpace()), (long) Integer.MAX_VALUE);
            if (requested <= 0) break;
            int simulated = storage.extractEnergy(requested, true);
            if (simulated <= 0) break;
            int extracted = storage.extractEnergy(simulated, false);
            if (extracted <= 0) break;
            blockEntity.localEnergy += extracted;
            budget -= extracted;
            moved += extracted;
            if (extracted < simulated) break;
        }
        if (moved > 0) blockEntity.setChanged();
    }

    private static long flushLocalIntoNetwork(ServerLevel level, NetworkPlugBlockEntity blockEntity) {
        if (blockEntity.localEnergy <= 0) return 0L;
        PowerNetworkSavedData network = PowerNetworkSavedData.get(level);
        long offered = Math.min(blockEntity.transferLimit, blockEntity.localEnergy);
        long accepted = network.addEnergy(blockEntity.networkName, offered, level.getGameTime());
        if (accepted > 0) {
            blockEntity.localEnergy -= accepted;
            blockEntity.setChanged();
        }
        return accepted;
    }

    private static void fillLocalFromNetwork(ServerLevel level, NetworkPlugBlockEntity blockEntity) {
        if (blockEntity.getLocalSpace() <= 0) return;
        PowerNetworkSavedData network = PowerNetworkSavedData.get(level);
        long requested = Math.min(blockEntity.transferLimit, blockEntity.getLocalSpace());
        long removed = network.removeEnergy(blockEntity.networkName, requested, level.getGameTime());
        if (removed > 0) {
            blockEntity.localEnergy += removed;
            blockEntity.setChanged();
        }
    }

    private static long pushLocalIntoAttachedBlock(ServerLevel level, BlockPos pos, BlockState state, NetworkPlugBlockEntity blockEntity) {
        if (blockEntity.localEnergy <= 0) return 0L;
        Direction facing = state.getValue(NetworkPlugBlock.FACING);
        Direction towardAttached = facing.getOpposite();
        IEnergyStorage storage = level.getCapability(Capabilities.EnergyStorage.BLOCK, pos.relative(towardAttached), facing);
        if (storage == null || !storage.canReceive()) return 0L;

        long budget = Math.min(blockEntity.transferLimit, blockEntity.localEnergy);
        long moved = 0L;
        while (budget > 0 && blockEntity.localEnergy > 0) {
            int offered = (int) Math.min(Math.min(budget, blockEntity.localEnergy), (long) Integer.MAX_VALUE);
            if (offered <= 0) break;
            int simulated = storage.receiveEnergy(offered, true);
            if (simulated <= 0) break;
            int received = storage.receiveEnergy(simulated, false);
            if (received <= 0) break;
            blockEntity.localEnergy -= received;
            budget -= received;
            moved += received;
            if (received < simulated) break;
        }
        if (moved > 0) blockEntity.setChanged();
        return moved;
    }

    private final class PlugEnergyStorage implements IEnergyStorage {
        @Override
        public int receiveEnergy(int maxReceive, boolean simulate) {
            if (maxReceive <= 0 || getMode() != PlugMode.INPUT) return 0;
            int accepted = (int) Math.min(Math.min((long) maxReceive, transferLimit), getLocalSpace());
            if (!simulate && accepted > 0) { localEnergy += accepted; setChangedAndSync(); }
            return accepted;
        }

        @Override
        public int extractEnergy(int maxExtract, boolean simulate) {
            if (maxExtract <= 0 || getMode() != PlugMode.OUTPUT) return 0;
            int extracted = (int) Math.min(Math.min((long) maxExtract, transferLimit), localEnergy);
            if (!simulate && extracted > 0) { localEnergy -= extracted; setChangedAndSync(); }
            return extracted;
        }

        @Override public int getEnergyStored() { return (int) Math.min(Integer.MAX_VALUE, localEnergy); }
        @Override public int getMaxEnergyStored() { return Integer.MAX_VALUE; }
        @Override public boolean canExtract() { return getMode() == PlugMode.OUTPUT; }
        @Override public boolean canReceive() { return getMode() == PlugMode.INPUT; }
    }
}
