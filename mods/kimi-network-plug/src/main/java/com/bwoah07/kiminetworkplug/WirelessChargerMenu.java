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

public final class WirelessChargerMenu extends AbstractContainerMenu {
    public static final int MAX_VISIBLE_NETWORKS = 32;
    private static final int NAME_INTS = 6;
    private static final int CURRENT_NAME_START = 15;
    private static final int NETWORK_COUNT_INDEX = CURRENT_NAME_START + NAME_INTS;
    private static final int NETWORK_LIST_START = NETWORK_COUNT_INDEX + 1;
    private static final int DATA_COUNT = NETWORK_LIST_START + (MAX_VISIBLE_NETWORKS * NAME_INTS);

    private final WirelessChargerBlockEntity blockEntity;
    private final ContainerData data;

    public WirelessChargerMenu(int containerId, Inventory inventory) {
        this(containerId, inventory, null, new SimpleContainerData(DATA_COUNT));
    }

    public WirelessChargerMenu(int containerId, Inventory inventory, WirelessChargerBlockEntity blockEntity) {
        this(containerId, inventory, blockEntity, createData(blockEntity));
    }

    private WirelessChargerMenu(int containerId, Inventory inventory, WirelessChargerBlockEntity blockEntity, ContainerData data) {
        super(KimiNetworkPlug.WIRELESS_CHARGER_MENU.get(), containerId);
        this.blockEntity = blockEntity;
        this.data = data;
        checkContainerDataCount(data, DATA_COUNT);
        addDataSlots(data);
    }

    private static ContainerData createData(WirelessChargerBlockEntity charger) {
        return new ContainerData() {
            @Override public int get(int index) {
                if (charger == null) return 0;
                PowerNetworkSavedData network = charger.getLevel() instanceof net.minecraft.server.level.ServerLevel serverLevel
                        ? PowerNetworkSavedData.get(serverLevel) : null;
                long networkEnergy = network == null ? 0L : network.getEnergy(charger.getNetworkName());

                if (index == 0) return charger.getRange();
                if (index == 1) return low(charger.getChargeRate());
                if (index == 2) return high(charger.getChargeRate());
                if (index == 3) return low(charger.getLastDraw());
                if (index == 4) return high(charger.getLastDraw());
                if (index == 5) return charger.getLastPlayers();
                if (index == 6) return charger.chargesInventory() ? 1 : 0;
                if (index == 7) return charger.chargesArmor() ? 1 : 0;
                if (index == 8) return charger.chargesOffhand() ? 1 : 0;
                if (index == 9) return charger.chargesCurios() ? 1 : 0;
                if (index == 10) return low(networkEnergy);
                if (index == 11) return high(networkEnergy);
                if (index == 12) return charger.getBlockPos().getX();
                if (index == 13) return charger.getBlockPos().getY();
                if (index == 14) return charger.getBlockPos().getZ();
                if (index >= CURRENT_NAME_START && index < CURRENT_NAME_START + NAME_INTS) {
                    return packName(charger.getNetworkName(), index - CURRENT_NAME_START);
                }
                if (index == NETWORK_COUNT_INDEX) {
                    return network == null ? 0 : Math.min(MAX_VISIBLE_NETWORKS, network.getNetworkNames().size());
                }
                if (index >= NETWORK_LIST_START) {
                    if (network == null) return 0;
                    int relative = index - NETWORK_LIST_START;
                    int networkIndex = relative / NAME_INTS;
                    int nameSlot = relative % NAME_INTS;
                    List<String> names = network.getNetworkNames();
                    if (networkIndex >= names.size() || networkIndex >= MAX_VISIBLE_NETWORKS) return 0;
                    return packName(names.get(networkIndex), nameSlot);
                }
                return 0;
            }
            @Override public void set(int index, int value) {}
            @Override public int getCount() { return DATA_COUNT; }
        };
    }

    private static int low(long value) { return (int) (value & 0xFFFFFFFFL); }
    private static int high(long value) { return (int) ((value >>> 32) & 0xFFFFFFFFL); }
    private long readLong(int lowIndex) { return Integer.toUnsignedLong(data.get(lowIndex)) | (Integer.toUnsignedLong(data.get(lowIndex + 1)) << 32); }

    private static int packName(String name, int slot) {
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

    private String unpackName(int start) {
        StringBuilder out = new StringBuilder();
        for (int slot = 0; slot < NAME_INTS; slot++) {
            int packed = data.get(start + slot);
            for (int i = 0; i < 4; i++) {
                int value = (packed >>> (i * 8)) & 0xFF;
                if (value == 0) return out.length() == 0 ? PowerNetworkSavedData.DEFAULT_NETWORK : out.toString();
                out.append((char) value);
            }
        }
        return out.length() == 0 ? PowerNetworkSavedData.DEFAULT_NETWORK : out.toString();
    }

    public int getRange() { return data.get(0); }
    public long getChargeRate() { return readLong(1); }
    public long getLastDraw() { return readLong(3); }
    public int getPlayers() { return data.get(5); }
    public boolean inventory() { return data.get(6) != 0; }
    public boolean armor() { return data.get(7) != 0; }
    public boolean offhand() { return data.get(8) != 0; }
    public boolean curios() { return data.get(9) != 0; }
    public long getNetworkEnergy() { return readLong(10); }
    public String getNetworkName() { return unpackName(CURRENT_NAME_START); }
    public BlockPos getBlockPos() { return new BlockPos(data.get(12), data.get(13), data.get(14)); }

    public List<String> getNetworkNames() {
        int count = Math.max(0, Math.min(MAX_VISIBLE_NETWORKS, data.get(NETWORK_COUNT_INDEX)));
        List<String> out = new ArrayList<>();
        for (int i = 0; i < count; i++) out.add(unpackName(NETWORK_LIST_START + i * NAME_INTS));
        return out;
    }

    @Override public ItemStack quickMoveStack(Player player, int index) { return ItemStack.EMPTY; }

    @Override
    public boolean stillValid(Player player) {
        if (blockEntity == null || blockEntity.getLevel() == null) return true;
        if (!blockEntity.getBlockState().is(KimiNetworkPlug.WIRELESS_CHARGER.get())) return false;
        return player.distanceToSqr(blockEntity.getBlockPos().getX() + 0.5, blockEntity.getBlockPos().getY() + 0.5,
                blockEntity.getBlockPos().getZ() + 0.5) <= 64.0;
    }
}
