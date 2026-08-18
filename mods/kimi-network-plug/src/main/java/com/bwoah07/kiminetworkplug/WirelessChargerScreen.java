package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;
import net.neoforged.neoforge.network.PacketDistributor;

public final class WirelessChargerScreen extends AbstractContainerScreen<WirelessChargerMenu> {
    private static final int BG = 0xE8050709;
    private static final int FIELD = 0xD9111418;
    private static final int BORDER = 0xFFD3D6DA;
    private static final int TEXT = 0xFFF2F3F4;
    private static final int MUTED = 0xFFA8ADB3;
    private static final int GREEN = 0xFF64E889;
    private static final int CYAN = 0xFF46C9D8;

    private enum Tab { GENERAL, TARGETS, STATS }
    private Tab tab = Tab.GENERAL;

    private Button tabGeneral, tabTargets, tabStats;
    private EditBox networkBox, rangeBox, rateBox;
    private Button applyButton, inventoryButton, armorButton, offhandButton, curiosButton;
    private boolean inventory, armor, offhand, curios;

    public WirelessChargerScreen(WirelessChargerMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 176;
        imageHeight = 178;
        inventoryLabelY = 10_000;
        titleLabelY = 10_000;
    }

    @Override
    protected void init() {
        super.init();
        int x = leftPos;
        int y = topPos;
        this.inventory = menu.inventory();
        this.armor = menu.armor();
        this.offhand = menu.offhand();
        this.curios = menu.curios();

        tabGeneral = addRenderableWidget(Button.builder(Component.literal("G"), b -> setTab(Tab.GENERAL)).bounds(x + 10, y + 7, 28, 20).build());
        tabTargets = addRenderableWidget(Button.builder(Component.literal("T"), b -> setTab(Tab.TARGETS)).bounds(x + 42, y + 7, 28, 20).build());
        tabStats = addRenderableWidget(Button.builder(Component.literal("S"), b -> setTab(Tab.STATS)).bounds(x + 74, y + 7, 28, 20).build());

        networkBox = new EditBox(font, x + 16, y + 70, 144, 18, Component.literal("Network"));
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);

        rangeBox = new EditBox(font, x + 16, y + 111, 52, 18, Component.literal("Range"));
        rangeBox.setFilter(value -> value.matches("\\d*"));
        rangeBox.setValue(Integer.toString(menu.getRange()));
        addRenderableWidget(rangeBox);

        rateBox = new EditBox(font, x + 74, y + 111, 86, 18, Component.literal("Rate"));
        rateBox.setFilter(value -> value.matches("\\d*"));
        rateBox.setMaxLength(14);
        rateBox.setValue(Long.toString(menu.getChargeRate()));
        addRenderableWidget(rateBox);

        applyButton = addRenderableWidget(Button.builder(Component.literal("APPLY"), b -> apply()).bounds(x + 108, y + 136, 52, 18).build());

        inventoryButton = addRenderableWidget(Button.builder(Component.empty(), b -> { inventory = !inventory; apply(); }).bounds(x + 16, y + 72, 144, 20).build());
        armorButton = addRenderableWidget(Button.builder(Component.empty(), b -> { armor = !armor; apply(); }).bounds(x + 16, y + 97, 144, 20).build());
        offhandButton = addRenderableWidget(Button.builder(Component.empty(), b -> { offhand = !offhand; apply(); }).bounds(x + 16, y + 122, 144, 20).build());
        curiosButton = addRenderableWidget(Button.builder(Component.empty(), b -> { curios = !curios; apply(); }).bounds(x + 16, y + 147, 144, 20).build());

        syncButtons();
        updateVisibility();
    }

    private void setTab(Tab next) {
        tab = next;
        updateVisibility();
        tabGeneral.active = tab != Tab.GENERAL;
        tabTargets.active = tab != Tab.TARGETS;
        tabStats.active = tab != Tab.STATS;
    }

    private void updateVisibility() {
        boolean general = tab == Tab.GENERAL;
        boolean targets = tab == Tab.TARGETS;
        networkBox.visible = general;
        rangeBox.visible = general;
        rateBox.visible = general;
        applyButton.visible = general;
        inventoryButton.visible = targets;
        armorButton.visible = targets;
        offhandButton.visible = targets;
        curiosButton.visible = targets;
    }

    private void syncButtons() {
        if (inventoryButton != null) inventoryButton.setMessage(Component.literal("INVENTORY        " + (inventory ? "ON" : "OFF")));
        if (armorButton != null) armorButton.setMessage(Component.literal("ARMOR            " + (armor ? "ON" : "OFF")));
        if (offhandButton != null) offhandButton.setMessage(Component.literal("OFFHAND          " + (offhand ? "ON" : "OFF")));
        if (curiosButton != null) curiosButton.setMessage(Component.literal("CURIOS           " + (curios ? "ON" : "OFF")));
    }

    private void apply() {
        if (networkBox == null || rangeBox == null || rateBox == null) return;
        String network = PowerNetworkSavedData.normalizeNetworkName(networkBox.getValue());
        int range;
        long rate;
        try { range = Integer.parseInt(rangeBox.getValue()); } catch (NumberFormatException e) { range = menu.getRange(); }
        try { rate = Long.parseLong(rateBox.getValue()); } catch (NumberFormatException e) { rate = menu.getChargeRate(); }
        range = Math.max(WirelessChargerBlockEntity.MIN_RANGE, Math.min(WirelessChargerBlockEntity.MAX_RANGE, range));
        rate = Math.max(WirelessChargerBlockEntity.MIN_RATE, Math.min(WirelessChargerBlockEntity.MAX_RATE, rate));
        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.ChargerConfigPayload(
                pos.getX(), pos.getY(), pos.getZ(), network, range, rate, inventory, armor, offhand, curios));
        networkBox.setValue(network);
        rangeBox.setValue(Integer.toString(range));
        rateBox.setValue(Long.toString(rate));
        syncButtons();
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        if (networkBox != null && !networkBox.isFocused()) networkBox.setValue(menu.getNetworkName());
        if (rangeBox != null && !rangeBox.isFocused()) rangeBox.setValue(Integer.toString(menu.getRange()));
        if (rateBox != null && !rateBox.isFocused()) rateBox.setValue(Long.toString(menu.getChargeRate()));
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        g.fill(x + 4, y + 31, x + imageWidth - 4, y + imageHeight - 4, BG);
        outline(g, x + 4, y + 31, imageWidth - 8, imageHeight - 35, CYAN);
        g.fill(x + 12, y + 40, x + imageWidth - 12, y + 60, FIELD);
        g.fill(x + 12, y + 63, x + imageWidth - 12, y + imageHeight - 12, 0xB006090C);

        if (tab == Tab.GENERAL) {
            outline(g, x + 15, y + 67, 146, 24, BORDER);
            outline(g, x + 15, y + 108, 146, 24, BORDER);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 18, y + 128, 140, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        }
    }

    private static void outline(GuiGraphics g, int x, int y, int w, int h, int c) {
        g.fill(x, y, x + w, y + 1, c); g.fill(x, y + h - 1, x + w, y + h, c);
        g.fill(x, y, x + 1, y + h, c); g.fill(x + w - 1, y, x + w, y + h, c);
    }

    private static void drawBar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        g.fill(x, y, x + w, y + h, 0xFF252B31);
        int filled = (int)Math.round(w * fraction);
        if (filled > 0) g.fill(x, y, x + filled, y + h, color);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        g.drawString(font, "KIMI WIRELESS", 16, 46, TEXT, false);
        g.drawString(font, "●", 149, 46, GREEN, false);

        if (tab == Tab.GENERAL) {
            g.drawString(font, "NETWORK", 16, 62, MUTED, false);
            g.drawString(font, "RANGE", 16, 103, MUTED, false);
            g.drawString(font, "RATE", 74, 103, MUTED, false);
            g.drawString(font, "LIVE " + formatFe(menu.getLastDraw()) + " FE/t", 16, 141, GREEN, false);
            g.drawString(font, menu.getPlayers() + " PLAYER" + (menu.getPlayers() == 1 ? "" : "S") + " IN RANGE", 16, 157, MUTED, false);
        } else if (tab == Tab.TARGETS) {
            g.drawString(font, "WIRELESS TARGETS", 16, 62, MUTED, false);
        } else {
            g.drawString(font, "KIMI LINK", 18, 72, MUTED, false);
            g.drawString(font, "ONLINE", 120, 72, GREEN, false);
            g.drawString(font, "LIVE DRAW", 18, 91, MUTED, false);
            g.drawString(font, formatFe(menu.getLastDraw()) + " FE/t", 98, 91, GREEN, false);
            g.drawString(font, "PLAYERS", 18, 108, MUTED, false);
            g.drawString(font, Integer.toString(menu.getPlayers()), 120, 108, TEXT, false);
            g.drawString(font, "BUFFER", 18, 122, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 18, 139, TEXT, false);
            g.drawString(font, "NETWORK " + menu.getNetworkName(), 18, 155, MUTED, false);
        }
    }

    private static String formatFe(long value) {
        if (value >= 1_000_000_000_000L) return String.format("%.2fT", value / 1_000_000_000_000.0);
        if (value >= 1_000_000_000L) return String.format("%.2fG", value / 1_000_000_000.0);
        if (value >= 1_000_000L) return String.format("%.2fM", value / 1_000_000.0);
        if (value >= 1_000L) return String.format("%.1fk", value / 1_000.0);
        return Long.toString(value);
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        renderBackground(g, mouseX, mouseY, partialTick);
        super.render(g, mouseX, mouseY, partialTick);
        renderTooltip(g, mouseX, mouseY);
    }
}
