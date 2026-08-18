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

public final class NetworkPlugBlockEntity extends BlockEntity {
    public static final int DEFAULT_TRANSFER_LIMIT = 16_000_000;
    public static final int MIN_TRANSFER_LIMIT = 100_000;
    public static final int MAX_TRANSFER_LIMIT = 2_000_000_000;

    private long lastTransfer;
    private int transferLimit = DEFAULT_TRANSFER_LIMIT;
    private final IEnergyStorage energyCapability = new PlugEnergyStorage();

    public NetworkPlugBlockEntity(BlockPos pos, BlockState state) {
        super(KimiNetworkPlug.NETWORK_PLUG_BLOCK_ENTITY.get(), pos, state);
    }

    public long getLastTransfer() {
        return lastTransfer;
    }

    public int getTransferLimit() {
        return transferLimit;
    }

    public void setTransferLimit(int transferLimit) {
        this.transferLimit = Math.max(MIN_TRANSFER_LIMIT, Math.min(MAX_TRANSFER_LIMIT, transferLimit));
        setChanged();
        if (level != null) {
            level.sendBlockUpdated(worldPosition, getBlockState(), getBlockState(), Block.UPDATE_CLIENTS);
        }
    }

    public void setMode(PlugMode mode) {
        if (level == null || !getBlockState().hasProperty(NetworkPlugBlock.MODE)) return;
        level.setBlock(worldPosition, getBlockState().setValue(NetworkPlugBlock.MODE, mode), Block.UPDATE_ALL);
    }

    public IEnergyStorage getEnergyCapability() {
        return energyCapability;
    }

    @Override
    protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        tag.putInt("TransferLimit", transferLimit);
    }

    @Override
    protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        transferLimit = Math.max(MIN_TRANSFER_LIMIT,
                Math.min(MAX_TRANSFER_LIMIT, tag.contains("TransferLimit") ? tag.getInt("TransferLimit") : DEFAULT_TRANSFER_LIMIT));
    }

    public static void serverTick(Level level, BlockPos pos, BlockState state, NetworkPlugBlockEntity blockEntity) {
        if (!(level instanceof ServerLevel serverLevel)) return;

        PlugMode mode = state.getValue(NetworkPlugBlock.MODE);
        long moved = switch (mode) {
            case INPUT -> pullIntoNetwork(serverLevel, pos, blockEntity.transferLimit);
            case OUTPUT -> pushFromNetwork(serverLevel, pos, blockEntity.transferLimit);
            case DISABLED -> 0L;
        };

        blockEntity.lastTransfer = moved;
    }

    private static long pullIntoNetwork(ServerLevel level, BlockPos pos, int transferLimit) {
        PowerNetworkSavedData network = PowerNetworkSavedData.get(level);
        int budget = transferLimit;
        long total = 0L;

        for (Direction direction : Direction.values()) {
            if (budget <= 0 || network.getSpace() <= 0) break;

            IEnergyStorage storage = level.getCapability(
                    Capabilities.EnergyStorage.BLOCK,
                    pos.relative(direction),
                    direction.getOpposite()
            );

            if (storage == null || !storage.canExtract()) continue;

            int requested = (int) Math.min((long) budget, network.getSpace());
            if (requested <= 0) break;

            int simulated = storage.extractEnergy(requested, true);
            if (simulated <= 0) continue;

            int extracted = storage.extractEnergy(simulated, false);
            if (extracted <= 0) continue;

            long accepted = network.addEnergy(extracted);
            budget -= (int) accepted;
            total += accepted;
        }

        return total;
    }

    private static long pushFromNetwork(ServerLevel level, BlockPos pos, int transferLimit) {
        PowerNetworkSavedData network = PowerNetworkSavedData.get(level);
        int budget = transferLimit;
        long total = 0L;

        for (Direction direction : Direction.values()) {
            if (budget <= 0 || network.getEnergy() <= 0) break;

            IEnergyStorage storage = level.getCapability(
                    Capabilities.EnergyStorage.BLOCK,
                    pos.relative(direction),
                    direction.getOpposite()
            );

            if (storage == null || !storage.canReceive()) continue;

            int offered = (int) Math.min((long) budget, network.getEnergy());
            if (offered <= 0) break;

            int received = storage.receiveEnergy(offered, false);
            if (received <= 0) continue;

            network.removeEnergy(received);
            budget -= received;
            total += received;
        }

        return total;
    }

    private final class PlugEnergyStorage implements IEnergyStorage {
        private PowerNetworkSavedData network() {
            return level instanceof ServerLevel serverLevel ? PowerNetworkSavedData.get(serverLevel) : null;
        }

        private PlugMode mode() {
            BlockState state = getBlockState();
            return state.hasProperty(NetworkPlugBlock.MODE) ? state.getValue(NetworkPlugBlock.MODE) : PlugMode.DISABLED;
        }

        @Override
        public int receiveEnergy(int maxReceive, boolean simulate) {
            if (maxReceive <= 0 || mode() != PlugMode.INPUT) return 0;
            PowerNetworkSavedData network = network();
            if (network == null) return 0;

            int accepted = (int) Math.min(
                    Math.min((long) maxReceive, (long) transferLimit),
                    network.getSpace()
            );
            if (!simulate && accepted > 0) network.addEnergy(accepted);
            return accepted;
        }

        @Override
        public int extractEnergy(int maxExtract, boolean simulate) {
            if (maxExtract <= 0 || mode() != PlugMode.OUTPUT) return 0;
            PowerNetworkSavedData network = network();
            if (network == null) return 0;

            int extracted = (int) Math.min(
                    Math.min((long) maxExtract, (long) transferLimit),
                    network.getEnergy()
            );
            if (!simulate && extracted > 0) network.removeEnergy(extracted);
            return extracted;
        }

        @Override
        public int getEnergyStored() {
            PowerNetworkSavedData network = network();
            return network == null ? 0 : (int) Math.min((long) Integer.MAX_VALUE, network.getEnergy());
        }

        @Override
        public int getMaxEnergyStored() {
            return (int) Math.min((long) Integer.MAX_VALUE, PowerNetworkSavedData.CAPACITY);
        }

        @Override
        public boolean canExtract() {
            return mode() == PlugMode.OUTPUT;
        }

        @Override
        public boolean canReceive() {
            return mode() == PlugMode.INPUT;
        }
    }
}
