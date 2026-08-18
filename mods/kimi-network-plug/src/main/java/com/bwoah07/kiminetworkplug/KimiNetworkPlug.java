package com.bwoah07.kiminetworkplug;

import com.mojang.logging.LogUtils;
import net.minecraft.core.registries.Registries;
import net.minecraft.world.flag.FeatureFlags;
import net.minecraft.world.inventory.MenuType;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModList;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.capabilities.Capabilities;
import net.neoforged.neoforge.capabilities.RegisterCapabilitiesEvent;
import net.neoforged.neoforge.event.BuildCreativeModeTabContentsEvent;
import net.neoforged.neoforge.registries.DeferredRegister;
import org.slf4j.Logger;

import java.util.function.Supplier;

@Mod(KimiNetworkPlug.MODID)
public final class KimiNetworkPlug {
    public static final String MODID = "kimi_network_plug";
    public static final Logger LOGGER = LogUtils.getLogger();

    public static final DeferredRegister.Blocks BLOCKS = DeferredRegister.createBlocks(MODID);
    public static final DeferredRegister.Items ITEMS = DeferredRegister.createItems(MODID);
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITY_TYPES = DeferredRegister.create(Registries.BLOCK_ENTITY_TYPE, MODID);
    public static final DeferredRegister<MenuType<?>> MENUS = DeferredRegister.create(Registries.MENU, MODID);

    public static final Supplier<NetworkPlugBlock> NETWORK_PLUG = BLOCKS.register("network_plug",
            () -> new NetworkPlugBlock(BlockBehaviour.Properties.of().mapColor(MapColor.METAL).strength(3.0F, 6.0F).requiresCorrectToolForDrops().noOcclusion()));
    public static final Supplier<BlockItem> NETWORK_PLUG_ITEM = ITEMS.registerSimpleBlockItem("network_plug", NETWORK_PLUG);

    public static final Supplier<ChunkLoaderBlock> CHUNK_LOADER = BLOCKS.register("chunk_loader",
            () -> new ChunkLoaderBlock(BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_PURPLE).strength(3.0F, 6.0F).requiresCorrectToolForDrops()));
    public static final Supplier<BlockItem> CHUNK_LOADER_ITEM = ITEMS.registerSimpleBlockItem("chunk_loader", CHUNK_LOADER);

    public static final Supplier<WirelessChargerBlock> WIRELESS_CHARGER = BLOCKS.register("wireless_charger",
            () -> new WirelessChargerBlock(BlockBehaviour.Properties.of().mapColor(MapColor.METAL).strength(3.0F, 6.0F).requiresCorrectToolForDrops().lightLevel(state -> 4)));
    public static final Supplier<BlockItem> WIRELESS_CHARGER_ITEM = ITEMS.registerSimpleBlockItem("wireless_charger", WIRELESS_CHARGER);

    public static final Supplier<BlockEntityType<NetworkPlugBlockEntity>> NETWORK_PLUG_BLOCK_ENTITY = BLOCK_ENTITY_TYPES.register(
            "network_plug", () -> BlockEntityType.Builder.of(NetworkPlugBlockEntity::new, NETWORK_PLUG.get()).build(null));
    public static final Supplier<BlockEntityType<WirelessChargerBlockEntity>> WIRELESS_CHARGER_BLOCK_ENTITY = BLOCK_ENTITY_TYPES.register(
            "wireless_charger", () -> BlockEntityType.Builder.of(WirelessChargerBlockEntity::new, WIRELESS_CHARGER.get()).build(null));

    public static final Supplier<MenuType<NetworkPlugMenu>> NETWORK_PLUG_MENU = MENUS.register(
            "network_plug", () -> new MenuType<>(NetworkPlugMenu::new, FeatureFlags.DEFAULT_FLAGS));
    public static final Supplier<MenuType<WirelessChargerMenu>> WIRELESS_CHARGER_MENU = MENUS.register(
            "wireless_charger", () -> new MenuType<>(WirelessChargerMenu::new, FeatureFlags.DEFAULT_FLAGS));

    public KimiNetworkPlug(IEventBus modEventBus) {
        BLOCKS.register(modEventBus);
        ITEMS.register(modEventBus);
        BLOCK_ENTITY_TYPES.register(modEventBus);
        MENUS.register(modEventBus);
        modEventBus.addListener(this::addCreativeTabContents);
        modEventBus.addListener(this::registerCapabilities);
        modEventBus.addListener(NetworkPlugNetworking::register);
    }

    private void registerCapabilities(RegisterCapabilitiesEvent event) {
        event.registerBlockEntity(Capabilities.EnergyStorage.BLOCK, NETWORK_PLUG_BLOCK_ENTITY.get(),
                (blockEntity, side) -> blockEntity.getEnergyCapability());
        if (ModList.get().isLoaded("computercraft")) KimiComputerCraftIntegration.registerCapabilities(event);
    }

    private void addCreativeTabContents(BuildCreativeModeTabContentsEvent event) {
        if (event.getTabKey() == CreativeModeTabs.REDSTONE_BLOCKS) {
            event.accept(NETWORK_PLUG_ITEM.get());
            event.accept(CHUNK_LOADER_ITEM.get());
            event.accept(WIRELESS_CHARGER_ITEM.get());
        }
    }
}
