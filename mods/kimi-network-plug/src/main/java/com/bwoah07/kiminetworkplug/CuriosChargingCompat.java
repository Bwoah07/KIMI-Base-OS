package com.bwoah07.kiminetworkplug;

import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.neoforged.neoforge.items.IItemHandlerModifiable;
import top.theillusivec4.curios.api.CuriosApi;

import java.util.function.ToLongFunction;

final class CuriosChargingCompat {
    private CuriosChargingCompat() {}

    static long charge(ServerPlayer player, long budget, ToLongFunction<ItemStack> charger) {
        if (budget <= 0) return 0L;
        var optional = CuriosApi.getCuriosInventory(player);
        if (optional.isEmpty()) return 0L;
        IItemHandlerModifiable equipped = optional.get().getEquippedCurios();
        long used = 0L;
        for (int i = 0; i < equipped.getSlots() && used < budget; i++) {
            ItemStack stack = equipped.getStackInSlot(i);
            if (stack.isEmpty()) continue;
            used += Math.min(budget - used, Math.max(0L, charger.applyAsLong(stack)));
        }
        return used;
    }
}
