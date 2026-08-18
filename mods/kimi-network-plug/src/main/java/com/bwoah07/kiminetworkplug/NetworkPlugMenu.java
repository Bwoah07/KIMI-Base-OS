package com.bwoah07.kiminetworkplug;

import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.inventory.SimpleContainerData;
import net.minecraft.world.item.ItemStack;

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

    private static final int DATA_COUNT = 14;
    private static final int NETWORK_NAME_START = 8;
    private static final int NETWORK_NAME_INTS = 6;

    private final NetworkPlugBlockEntity blockEntity;
    private final ContainerData data;

    public NetworkPlugMenu(int containerId, Inventory inventory) {
        this(containerId, inventory, null, new SimpleContainerData(DATA_COUNT));
    }

    public NetworkPlugMenu(int containerId, Inventory inventory, NetworkPlugBlockEntity blockEntity) {
        this(containerId, inventory, blockEntity, createData(blockEntity));
    }

    private NetworkPlugMenu(int containerId, Inventory inventory, NetworkPlugBlockEntity blockEntity, ContainerData data) {
        super(KimiNetworkPlug.NETWORK_PLUG_MENU.get(), containerId);
        this.blockEntity = blockEntity;
        this.data = data;
        checkContainerDataCount(data, DATA_COUNT);
        addDataSlots(data);
    }

    private static ContainerData createData(NetworkPlugBlockEntity blockEntity) {
        return new ContainerData() {
            @Override
            public int get(int index) {
                if (blockEntity == null) return 0;

                long gameTime = blockEntity.getLevel() == null ? 0L : blockEntity.getLevel().getGameTime();
                PowerNetworkSavedData network = blockEntity.getLevel() instanceof net.minecraft.server.level.ServerLevel serverLevel
                        ? PowerNetworkSavedData.get(serverLevel)
                        : null;

                return switch (index) {
                    case 0 -> blockEntity.getMode().ordinal();
                    case 1 -> blockEntity.getTransferLimit();
                    case 2 -> (int) Math.min(Integer.MAX_VALUE, blockEntity.getLastTransfer());
                    case 3 -> network == null ? 0 : (int) Math.min(Integer.MAX_VALUE, network.getEnergy(blockEntity.getNetworkName()));
                    case 4 -> (int) Math.min(Integer.MAX_VALUE, blockEntity.getLocalEnergy());
                    case 5 -> network == null ? 0 : (int) Math.min(Integer.MAX_VALUE, network.getInputRate(blockEntity.getNetworkName(), gameTime));
                    case 6 -> network == null ? 0 : (int) Math.min(Integer.MAX_VALUE, network.getOutputRate(blockEntity.getNetworkName(), gameTime));
                    case 7 -> network == null ? 0 : network.getPlugCount(blockEntity.getNetworkName());
                    default -> {
                        if (index >= NETWORK_NAME_START && index < NETWORK_NAME_START + NETWORK_NAME_INTS) {
                            yield packNetworkName(blockEntity.getNetworkName(), index - NETWORK_NAME_START);
                        }
                        yield 0;
                    }
                };
            }

            @Override
            public void set(int index, int value) {
            }

            @Override
            public int getCount() {
                return DATA_COUNT;
            }
        };
    }

    private static int packNetworkName(String name, int slot) {
        String normalized = PowerNetworkSavedData.normalizeNetworkName(name);
        int start = slot * 4;
        int packed = 0;
        for (int i = 0; i < 4; i++) {
            int charIndex = start + i;
            if (charIndex >= normalized.length()) break;
            packed |= (normalized.charAt(charIndex) & 0xFF) << (i * 8);
        }
        return packed;
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

    public int getNetworkEnergy() {
        return data.get(3);
    }

    public int getLocalEnergy() {
        return data.get(4);
    }

    public int getNetworkInput() {
        return data.get(5);
    }

    public int getNetworkOutput() {
        return data.get(6);
    }

    public int getPlugCount() {
        return data.get(7);
    }

    public String getNetworkName() {
        StringBuilder out = new StringBuilder();
        for (int slot = 0; slot < NETWORK_NAME_INTS; slot++) {
            int packed = data.get(NETWORK_NAME_START + slot);
            for (int i = 0; i < 4; i++) {
                int value = (packed >>> (i * 8)) & 0xFF;
                if (value == 0) return out.length() == 0 ? PowerNetworkSavedData.DEFAULT_NETWORK : out.toString();
                out.append((char) value);
            }
        }
        return out.length() == 0 ? PowerNetworkSavedData.DEFAULT_NETWORK : out.toString();
    }

    public NetworkPlugBlockEntity getBlockEntity() {
        return blockEntity;
    }

    @Override
    public boolean clickMenuButton(Player player, int id) {
        if (blockEntity == null) return false;

        if (id < 0) {
            long requested = -(long) id;
            blockEntity.setTransferLimit((int) Math.min(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT, requested));
            return true;
        }

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

        if (id == 20 || id == 21) {
            blockEntity.cycleNetwork(id == 20 ? -1 : 1);
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
    public ItemStack quickMoveStack(Player player, int index) {
        return ItemStack.EMPTY;
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
