package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.energy.IEnergyStorage;

public final class NetworkPlugBlockEntity extends BlockEntity {
    public static final int TRANSFER_LIMIT_PER_TICK = 16_000_000;

    private long lastTransfer;

    public NetworkPlugBlockEntity(BlockPos pos, BlockState state) {
        super(KimiNetworkPlug.NETWORK_PLUG_BLOCK_ENTITY.get(), pos, state);
    }

    public long getLastTransfer() {
        return lastTransfer;
    }

    public static void serverTick(Level level, BlockPos pos, BlockState state, NetworkPlugBlockEntity blockEntity) {
        if (!(level instanceof ServerLevel serverLevel)) return;

        PlugMode mode = state.getValue(NetworkPlugBlock.MODE);
        long moved = switch (mode) {
            case INPUT -> pullIntoNetwork(serverLevel, pos);
            case OUTPUT -> pushFromNetwork(serverLevel, pos);
            case DISABLED -> 0L;
        };

        blockEntity.lastTransfer = moved;
    }

    private static long pullIntoNetwork(ServerLevel level, BlockPos pos) {
        PowerNetworkSavedData network = PowerNetworkSavedData.get(level);
        int budget = TRANSFER_LIMIT_PER_TICK;
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
            if (accepted < extracted) {
                KimiNetworkPlug.LOGGER.warn("Network buffer accepted less energy than extracted ({} < {}).", accepted, extracted);
            }

            budget -= (int) accepted;
            total += accepted;
        }

        return total;
    }

    private static long pushFromNetwork(ServerLevel level, BlockPos pos) {
        PowerNetworkSavedData network = PowerNetworkSavedData.get(level);
        int budget = TRANSFER_LIMIT_PER_TICK;
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
}
