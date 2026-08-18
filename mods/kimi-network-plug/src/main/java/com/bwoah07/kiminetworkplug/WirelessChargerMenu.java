package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.inventory.SimpleContainerData;
import net.minecraft.world.item.ItemStack;

public final class WirelessChargerMenu extends AbstractContainerMenu {
    private static final int NAME_START = 15;
    private static final int NAME_INTS = 6;
    private static final int DATA_COUNT = 21;

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
                long networkEnergy = charger.getLevel() instanceof net.minecraft.server.level.ServerLevel serverLevel
                        ? PowerNetworkSavedData.get(serverLevel).getEnergy(charger.getNetworkName()) : 0L;
                return switch (index) {
                    case 0 -> charger.getRange();
                    case 1 -> low(charger.getChargeRate());
                    case 2 -> high(charger.getChargeRate());
                    case 3 -> low(charger.getLastDraw());
                    case 4 -> high(charger.getLastDraw());
                    case 5 -> charger.getLastPlayers();
                    case 6 -> charger.chargesInventory() ? 1 : 0;
                    case 7 -> charger.chargesArmor() ? 1 : 0;
                    case 8 -> charger.chargesOffhand() ? 1 : 0;
                    case 9 -> charger.chargesCurios() ? 1 : 0;
                    case 10 -> low(networkEnergy);
                    case 11 -> high(networkEnergy);
                    case 12 -> charger.getBlockPos().getX();
                    case 13 -> charger.getBlockPos().getY();
                    case 14 -> charger.getBlockPos().getZ();
                    default -> index >= NAME_START && index < NAME_START + NAME_INTS ? packName(charger.getNetworkName(), index - NAME_START) : 0;
                };
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

    private String unpackName() {
        StringBuilder out = new StringBuilder();
        for (int slot = 0; slot < NAME_INTS; slot++) {
            int packed = data.get(NAME_START + slot);
            for (int i = 0; i < 4; i++) {
                int value = (packed >>> (i * 8)) & 0xFF;
                if (value == 0) return out.length() == 0 ? PowerNetworkSavedData.DEFAULT_NETWORK : out.toString();
                out.append((char) value);
            }
        }
        return out.toString();
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
    public String getNetworkName() { return unpackName(); }
    public BlockPos getBlockPos() { return new BlockPos(data.get(12), data.get(13), data.get(14)); }

    @Override public ItemStack quickMoveStack(Player player, int index) { return ItemStack.EMPTY; }

    @Override
    public boolean stillValid(Player player) {
        if (blockEntity == null || blockEntity.getLevel() == null) return true;
        if (!blockEntity.getBlockState().is(KimiNetworkPlug.WIRELESS_CHARGER.get())) return false;
        return player.distanceToSqr(blockEntity.getBlockPos().getX() + 0.5, blockEntity.getBlockPos().getY() + 0.5,
                blockEntity.getBlockPos().getZ() + 0.5) <= 64.0;
    }
}
