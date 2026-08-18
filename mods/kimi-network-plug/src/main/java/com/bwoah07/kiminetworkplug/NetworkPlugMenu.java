package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.inventory.SimpleContainerData;
import net.minecraft.world.item.ItemStack;

import java.util.ArrayList;
import java.util.List;

public final class NetworkPlugMenu extends AbstractContainerMenu {
    public static final int MAX_VISIBLE_NETWORKS = 32;
    private static final int NAME_INTS = 6;
    private static final int CURRENT_NAME_START = 18;
    private static final int NETWORK_LIST_START = 24;
    private static final int NETWORK_LIST_END = NETWORK_LIST_START + (MAX_VISIBLE_NETWORKS * NAME_INTS);
    private static final int ATTACHED_TRANSFER_START = NETWORK_LIST_END;
    private static final int NETWORK_TRANSFER_START = ATTACHED_TRANSFER_START + 2;
    private static final int BOTTLENECK_INDEX = NETWORK_TRANSFER_START + 2;
    private static final int ATTACHED_NAME_START = BOTTLENECK_INDEX + 1;
    private static final int ATTACHED_NAME_INTS = 8;
    private static final int DATA_COUNT = ATTACHED_NAME_START + ATTACHED_NAME_INTS;

    private static final long[] LIMIT_PRESETS = {
            1_000_000L,
            16_000_000L,
            64_000_000L,
            256_000_000L,
            512_000_000L,
            1_000_000_000L,
            2_000_000_000L,
            4_000_000_000L,
            8_000_000_000L,
            16_000_000_000L,
            32_000_000_000L,
            64_000_000_000L
    };

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
                        ? PowerNetworkSavedData.get(serverLevel) : null;

                if (index == 0) return blockEntity.getMode().ordinal();
                if (index == 1) return low(blockEntity.getTransferLimit());
                if (index == 2) return high(blockEntity.getTransferLimit());
                if (index == 3) return low(blockEntity.getLastTransfer());
                if (index == 4) return high(blockEntity.getLastTransfer());
                if (index == 5) return low(network == null ? 0L : network.getEnergy(blockEntity.getNetworkName()));
                if (index == 6) return high(network == null ? 0L : network.getEnergy(blockEntity.getNetworkName()));
                if (index == 7) return low(blockEntity.getLocalEnergy());
                if (index == 8) return high(blockEntity.getLocalEnergy());
                if (index == 9) return low(network == null ? 0L : network.getInputRate(blockEntity.getNetworkName(), gameTime));
                if (index == 10) return high(network == null ? 0L : network.getInputRate(blockEntity.getNetworkName(), gameTime));
                if (index == 11) return low(network == null ? 0L : network.getOutputRate(blockEntity.getNetworkName(), gameTime));
                if (index == 12) return high(network == null ? 0L : network.getOutputRate(blockEntity.getNetworkName(), gameTime));
                if (index == 13) return network == null ? 0 : network.getPlugCount(blockEntity.getNetworkName());
                if (index == 14) return blockEntity.getBlockPos().getX();
                if (index == 15) return blockEntity.getBlockPos().getY();
                if (index == 16) return blockEntity.getBlockPos().getZ();
                if (index == 17) return network == null ? 0 : Math.min(MAX_VISIBLE_NETWORKS, network.getNetworkNames().size());
                if (index >= CURRENT_NAME_START && index < CURRENT_NAME_START + NAME_INTS) {
                    return packNetworkName(blockEntity.getNetworkName(), index - CURRENT_NAME_START);
                }
                if (index >= NETWORK_LIST_START && index < NETWORK_LIST_END) {
                    int relative = index - NETWORK_LIST_START;
                    int networkIndex = relative / NAME_INTS;
                    int nameSlot = relative % NAME_INTS;
                    if (network == null) return 0;
                    List<String> names = network.getNetworkNames();
                    if (networkIndex >= names.size() || networkIndex >= MAX_VISIBLE_NETWORKS) return 0;
                    return packNetworkName(names.get(networkIndex), nameSlot);
                }
                if (index == ATTACHED_TRANSFER_START) return low(blockEntity.getLastAttachedTransfer());
                if (index == ATTACHED_TRANSFER_START + 1) return high(blockEntity.getLastAttachedTransfer());
                if (index == NETWORK_TRANSFER_START) return low(blockEntity.getLastNetworkTransfer());
                if (index == NETWORK_TRANSFER_START + 1) return high(blockEntity.getLastNetworkTransfer());
                if (index == BOTTLENECK_INDEX) return blockEntity.getBottleneck().ordinal();
                if (index >= ATTACHED_NAME_START && index < ATTACHED_NAME_START + ATTACHED_NAME_INTS) {
                    return packText(blockEntity.getAttachedBlockName(), index - ATTACHED_NAME_START);
                }
                return 0;
            }

            @Override public void set(int index, int value) {}
            @Override public int getCount() { return DATA_COUNT; }
        };
    }

    private static int low(long value) { return (int) (value & 0xFFFFFFFFL); }
    private static int high(long value) { return (int) ((value >>> 32) & 0xFFFFFFFFL); }
    private long readLong(int lowIndex) {
        return Integer.toUnsignedLong(data.get(lowIndex)) | (Integer.toUnsignedLong(data.get(lowIndex + 1)) << 32);
    }

    private static int packNetworkName(String name, int slot) {
        return packText(PowerNetworkSavedData.normalizeNetworkName(name), slot);
    }

    private static int packText(String value, int slot) {
        String text = value == null ? "" : value;
        int start = slot * 4;
        int packed = 0;
        for (int i = 0; i < 4; i++) {
            int charIndex = start + i;
            if (charIndex >= text.length()) break;
            char c = text.charAt(charIndex);
            packed |= ((c <= 255 ? c : '?') & 0xFF) << (i * 8);
        }
        return packed;
    }

    private String unpackNetworkName(int start) {
        String text = unpackText(start, NAME_INTS);
        return text.isBlank() ? PowerNetworkSavedData.DEFAULT_NETWORK : text;
    }

    private String unpackText(int start, int slots) {
        StringBuilder out = new StringBuilder();
        for (int slot = 0; slot < slots; slot++) {
            int packed = data.get(start + slot);
            for (int i = 0; i < 4; i++) {
                int value = (packed >>> (i * 8)) & 0xFF;
                if (value == 0) return out.toString();
                out.append((char) value);
            }
        }
        return out.toString();
    }

    public PlugMode getMode() { return PlugMode.values()[Math.max(0, Math.min(PlugMode.values().length - 1, data.get(0)))]; }
    public long getTransferLimit() { return readLong(1); }
    public long getLastTransfer() { return readLong(3); }
    public long getNetworkEnergy() { return readLong(5); }
    public long getLocalEnergy() { return readLong(7); }
    public long getNetworkInput() { return readLong(9); }
    public long getNetworkOutput() { return readLong(11); }
    public int getPlugCount() { return data.get(13); }
    public String getNetworkName() { return unpackNetworkName(CURRENT_NAME_START); }
    public BlockPos getBlockPos() { return new BlockPos(data.get(14), data.get(15), data.get(16)); }
    public long getAttachedTransfer() { return readLong(ATTACHED_TRANSFER_START); }
    public long getNetworkTransfer() { return readLong(NETWORK_TRANSFER_START); }
    public PowerBottleneck getBottleneck() {
        int ordinal = Math.max(0, Math.min(PowerBottleneck.values().length - 1, data.get(BOTTLENECK_INDEX)));
        return PowerBottleneck.values()[ordinal];
    }
    public String getAttachedBlockName() {
        String name = unpackText(ATTACHED_NAME_START, ATTACHED_NAME_INTS);
        return name.isBlank() ? "No block" : name;
    }

    public List<String> getNetworkNames() {
        int count = Math.max(0, Math.min(MAX_VISIBLE_NETWORKS, data.get(17)));
        List<String> out = new ArrayList<>();
        for (int i = 0; i < count; i++) out.add(unpackNetworkName(NETWORK_LIST_START + i * NAME_INTS));
        return out;
    }

    public NetworkPlugBlockEntity getBlockEntity() { return blockEntity; }

    @Override
    public boolean clickMenuButton(Player player, int id) {
        if (blockEntity == null) return false;
        if (id >= 0 && id <= 2) {
            blockEntity.setMode(PlugMode.values()[id]);
            return true;
        }
        if (id == 10 || id == 11) {
            long current = blockEntity.getTransferLimit();
            int index = nearestPresetIndex(current) + (id == 10 ? -1 : 1);
            index = Math.max(0, Math.min(LIMIT_PRESETS.length - 1, index));
            blockEntity.setTransferLimit(LIMIT_PRESETS[index]);
            return true;
        }
        if (id == 12) { blockEntity.setTransferLimit(NetworkPlugBlockEntity.DEFAULT_TRANSFER_LIMIT); return true; }
        if (id == 13) { blockEntity.setTransferLimit(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT); return true; }
        if (id >= 100 && id < 100 + MAX_VISIBLE_NETWORKS) {
            if (!(blockEntity.getLevel() instanceof net.minecraft.server.level.ServerLevel serverLevel)) return false;
            List<String> names = PowerNetworkSavedData.get(serverLevel).getNetworkNames();
            int index = id - 100;
            if (index >= 0 && index < names.size()) blockEntity.setNetworkName(names.get(index));
            return true;
        }
        return false;
    }

    private static int nearestPresetIndex(long value) {
        int bestIndex = 0;
        long bestDistance = Long.MAX_VALUE;
        for (int i = 0; i < LIMIT_PRESETS.length; i++) {
            long distance = Math.abs(LIMIT_PRESETS[i] - value);
            if (distance < bestDistance) { bestDistance = distance; bestIndex = i; }
        }
        return bestIndex;
    }

    @Override public ItemStack quickMoveStack(Player player, int index) { return ItemStack.EMPTY; }

    @Override
    public boolean stillValid(Player player) {
        if (blockEntity == null || blockEntity.getLevel() == null) return true;
        if (!blockEntity.getBlockState().is(KimiNetworkPlug.NETWORK_PLUG.get())) return false;
        return player.distanceToSqr(blockEntity.getBlockPos().getX() + 0.5, blockEntity.getBlockPos().getY() + 0.5,
                blockEntity.getBlockPos().getZ() + 0.5) <= 64.0;
    }
}
