package com.bwoah07.kiminetworkplug;

import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.inventory.SimpleContainerData;

public final class NetworkPlugMenu extends AbstractContainerMenu {
    private static final int[] LIMIT_PRESETS = {
            100_000,
            500_000,
            1_000_000,
            5_000_000,
            16_000_000,
            64_000_000,
            256_000_000,
            1_000_000_000,
            2_000_000_000
    };

    private final NetworkPlugBlockEntity blockEntity;
    private final ContainerData data;

    public NetworkPlugMenu(int containerId, Inventory inventory) {
        this(containerId, inventory, null, new SimpleContainerData(4));
    }

    public NetworkPlugMenu(int containerId, Inventory inventory, NetworkPlugBlockEntity blockEntity) {
        this(containerId, inventory, blockEntity, createData(blockEntity));
    }

    private NetworkPlugMenu(int containerId, Inventory inventory, NetworkPlugBlockEntity blockEntity, ContainerData data) {
        super(KimiNetworkPlug.NETWORK_PLUG_MENU.get(), containerId);
        this.blockEntity = blockEntity;
        this.data = data;
        checkContainerDataCount(data, 4);
        addDataSlots(data);
    }

    private static ContainerData createData(NetworkPlugBlockEntity blockEntity) {
        return new ContainerData() {
            @Override
            public int get(int index) {
                return switch (index) {
                    case 0 -> blockEntity.getBlockState().getValue(NetworkPlugBlock.MODE).ordinal();
                    case 1 -> blockEntity.getTransferLimit();
                    case 2 -> (int) Math.min(Integer.MAX_VALUE, blockEntity.getLastTransfer());
                    case 3 -> {
                        if (!(blockEntity.getLevel() instanceof net.minecraft.server.level.ServerLevel serverLevel)) yield 0;
                        PowerNetworkSavedData network = PowerNetworkSavedData.get(serverLevel);
                        yield (int) Math.round((network.getEnergy() * 1000.0) / PowerNetworkSavedData.CAPACITY);
                    }
                    default -> 0;
                };
            }

            @Override
            public void set(int index, int value) {
            }

            @Override
            public int getCount() {
                return 4;
            }
        };
    }

    public PlugMode getMode() {
        int ordinal = Math.max(0, Math.min(PlugMode.values().length - 1, data.get(0)));
        return PlugMode.values()[ordinal];
    }

    public int getTransferLimit() {
        return data.get(1);
    }

    public int getLastTransfer() {
        return data.get(2);
    }

    public int getNetworkPermille() {
        return data.get(3);
    }

    @Override
    public boolean clickMenuButton(Player player, int id) {
        if (blockEntity == null) return false;

        if (id >= 0 && id <= 2) {
            blockEntity.setMode(PlugMode.values()[id]);
            return true;
        }

        if (id == 10 || id == 11) {
            int current = blockEntity.getTransferLimit();
            int index = nearestPresetIndex(current);
            index += id == 10 ? -1 : 1;
            index = Math.max(0, Math.min(LIMIT_PRESETS.length - 1, index));
            blockEntity.setTransferLimit(LIMIT_PRESETS[index]);
            return true;
        }

        return false;
    }

    private static int nearestPresetIndex(int value) {
        int bestIndex = 0;
        long bestDistance = Long.MAX_VALUE;
        for (int i = 0; i < LIMIT_PRESETS.length; i++) {
            long distance = Math.abs((long) LIMIT_PRESETS[i] - value);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    @Override
    public boolean stillValid(Player player) {
        if (blockEntity == null || blockEntity.getLevel() == null) return true;
        if (!blockEntity.getBlockState().is(KimiNetworkPlug.NETWORK_PLUG.get())) return false;
        return player.distanceToSqr(
                blockEntity.getBlockPos().getX() + 0.5,
                blockEntity.getBlockPos().getY() + 0.5,
                blockEntity.getBlockPos().getZ() + 0.5
        ) <= 64.0;
    }
}
