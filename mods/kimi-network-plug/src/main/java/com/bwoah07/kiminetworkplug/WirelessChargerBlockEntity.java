package com.bwoah07.kiminetworkplug;

import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.neoforged.fml.ModList;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.energy.IEnergyStorage;

import java.util.List;

public final class WirelessChargerBlockEntity extends BlockEntity {
    public static final int MIN_RANGE = 4;
    public static final int MAX_RANGE = 96;
    public static final int DEFAULT_RANGE = 32;
    public static final long MIN_RATE = 100_000L;
    public static final long MAX_RATE = 8_000_000_000L;
    public static final long DEFAULT_RATE = 512_000_000L;

    private String networkName = PowerNetworkSavedData.DEFAULT_NETWORK;
    private int range = DEFAULT_RANGE;
    private long chargeRate = DEFAULT_RATE;
    private boolean inventory = true;
    private boolean armor = true;
    private boolean offhand = true;
    private boolean curios = true;
    private long lastDraw;
    private int lastPlayers;

    public WirelessChargerBlockEntity(BlockPos pos, BlockState state) {
        super(KimiNetworkPlug.WIRELESS_CHARGER_BLOCK_ENTITY.get(), pos, state);
    }

    public String getNetworkName() { return networkName; }
    public int getRange() { return range; }
    public long getChargeRate() { return chargeRate; }
    public boolean chargesInventory() { return inventory; }
    public boolean chargesArmor() { return armor; }
    public boolean chargesOffhand() { return offhand; }
    public boolean chargesCurios() { return curios; }
    public long getLastDraw() { return lastDraw; }
    public int getLastPlayers() { return lastPlayers; }

    public void applyClientConfig(String network, int range, long rate, boolean inventory, boolean armor, boolean offhand, boolean curios) {
        this.networkName = PowerNetworkSavedData.normalizeNetworkName(network);
        this.range = Math.max(MIN_RANGE, Math.min(MAX_RANGE, range));
        this.chargeRate = Math.max(MIN_RATE, Math.min(MAX_RATE, rate));
        this.inventory = inventory;
        this.armor = armor;
        this.offhand = offhand;
        this.curios = curios;
        if (level instanceof ServerLevel serverLevel) PowerNetworkSavedData.get(serverLevel).createNetwork(this.networkName);
        setChanged();
        if (level != null) level.sendBlockUpdated(worldPosition, getBlockState(), getBlockState(), 3);
    }

    @Override
    protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        tag.putString("Network", networkName);
        tag.putInt("Range", range);
        tag.putLong("ChargeRate", chargeRate);
        tag.putBoolean("Inventory", inventory);
        tag.putBoolean("Armor", armor);
        tag.putBoolean("Offhand", offhand);
        tag.putBoolean("Curios", curios);
    }

    @Override
    protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        networkName = tag.contains("Network") ? PowerNetworkSavedData.normalizeNetworkName(tag.getString("Network")) : PowerNetworkSavedData.DEFAULT_NETWORK;
        range = tag.contains("Range") ? Math.max(MIN_RANGE, Math.min(MAX_RANGE, tag.getInt("Range"))) : DEFAULT_RANGE;
        chargeRate = tag.contains("ChargeRate") ? Math.max(MIN_RATE, Math.min(MAX_RATE, tag.getLong("ChargeRate"))) : DEFAULT_RATE;
        inventory = !tag.contains("Inventory") || tag.getBoolean("Inventory");
        armor = !tag.contains("Armor") || tag.getBoolean("Armor");
        offhand = !tag.contains("Offhand") || tag.getBoolean("Offhand");
        curios = !tag.contains("Curios") || tag.getBoolean("Curios");
    }

    public static void serverTick(Level level, BlockPos pos, BlockState state, WirelessChargerBlockEntity charger) {
        if (!(level instanceof ServerLevel serverLevel)) return;
        PowerNetworkSavedData networks = PowerNetworkSavedData.get(serverLevel);
        networks.createNetwork(charger.networkName);

        double r = charger.range;
        AABB box = new AABB(pos.getX() + 0.5 - r, pos.getY() + 0.5 - r, pos.getZ() + 0.5 - r,
                pos.getX() + 0.5 + r, pos.getY() + 0.5 + r, pos.getZ() + 0.5 + r);
        List<ServerPlayer> players = serverLevel.getEntitiesOfClass(ServerPlayer.class, box, player -> !player.isSpectator());
        charger.lastPlayers = players.size();

        long budget = Math.min(charger.chargeRate, networks.getEnergy(charger.networkName));
        long used = 0L;
        for (ServerPlayer player : players) {
            if (used >= budget) break;
            used += charger.chargePlayer(serverLevel, networks, player, budget - used);
        }
        charger.lastDraw = used;
    }

    private long chargePlayer(ServerLevel level, PowerNetworkSavedData networks, ServerPlayer player, long budget) {
        long used = 0L;
        if (inventory) used += chargeList(level, networks, player.getInventory().items, budget - used);
        if (armor && used < budget) used += chargeList(level, networks, player.getInventory().armor, budget - used);
        if (offhand && used < budget) used += chargeList(level, networks, player.getInventory().offhand, budget - used);
        if (curios && used < budget && ModList.get().isLoaded("curios")) {
            long remaining = budget - used;
            used += CuriosChargingCompat.charge(player, remaining, stack -> chargeStack(level, networks, stack, remaining));
        }
        return used;
    }

    private long chargeList(ServerLevel level, PowerNetworkSavedData networks, Iterable<ItemStack> stacks, long budget) {
        long used = 0L;
        for (ItemStack stack : stacks) {
            if (used >= budget) break;
            used += chargeStack(level, networks, stack, budget - used);
        }
        return used;
    }

    private long chargeStack(ServerLevel level, PowerNetworkSavedData networks, ItemStack stack, long budget) {
        if (stack == null || stack.isEmpty() || budget <= 0) return 0L;
        IEnergyStorage energy = stack.getCapability(Capabilities.EnergyStorage.ITEM);
        if (energy == null || !energy.canReceive()) return 0L;

        long total = 0L;
        while (budget > 0) {
            long available = networks.getEnergy(networkName);
            if (available <= 0) break;
            int offered = (int) Math.min(Math.min(budget, available), (long) Integer.MAX_VALUE);
            if (offered <= 0) break;
            int simulated = energy.receiveEnergy(offered, true);
            if (simulated <= 0) break;
            long removed = networks.removeEnergy(networkName, simulated, level.getGameTime());
            if (removed <= 0) break;
            int accepted = energy.receiveEnergy((int) removed, false);
            if (accepted < removed) networks.addEnergy(networkName, removed - accepted, level.getGameTime());
            total += accepted;
            budget -= accepted;
            if (accepted <= 0 || accepted < simulated) break;
        }
        return total;
    }
}
