package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;
import net.neoforged.neoforge.network.PacketDistributor;

public final class WirelessChargerScreen extends AbstractContainerScreen<WirelessChargerMenu> {
    private static final int PANEL = 0xD9080A0D;
    private static final int INNER = 0xA60D1014;
    private static final int SILVER = 0xFFD0D4D8;
    private static final int TEXT = 0xFFF0F2F4;
    private static final int MUTED = 0xFF9DA5AD;
    private static final int GREEN = 0xFF66E394;
    private static final int CYAN = 0xFF55D7E8;

    private enum Tab { GENERAL, TARGETS, STATS }
    private Tab tab = Tab.GENERAL;

    private KimiUiButton generalTab;
    private KimiUiButton targetsTab;
    private KimiUiButton statsTab;
    private KimiUiButton applyButton;
    private KimiUiButton inventoryButton;
    private KimiUiButton armorButton;
    private KimiUiButton offhandButton;
    private KimiUiButton curiosButton;
    private EditBox networkBox;
    private EditBox rangeBox;
    private EditBox rateBox;
    private boolean inventory;
    private boolean armor;
    private boolean offhand;
    private boolean curios;

    public WirelessChargerScreen(WirelessChargerMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 188;
        imageHeight = 190;
        inventoryLabelY = 10_000;
        titleLabelY = 10_000;
    }

    @Override
    protected void init() {
        super.init();
        int x = leftPos;
        int y = topPos;
        inventory = menu.inventory();
        armor = menu.armor();
        offhand = menu.offhand();
        curios = menu.curios();

        generalTab = addRenderableWidget(new KimiUiButton(x + 12, y + 1, 34, 26, Component.literal("⌂"), true, b -> setTab(Tab.GENERAL)).accent(CYAN));
        targetsTab = addRenderableWidget(new KimiUiButton(x + 51, y + 1, 34, 26, Component.literal("◎"), true, b -> setTab(Tab.TARGETS)).accent(CYAN));
        statsTab = addRenderableWidget(new KimiUiButton(x + 90, y + 1, 34, 26, Component.literal("▥"), true, b -> setTab(Tab.STATS)).accent(CYAN));

        networkBox = new EditBox(font, x + 18, y + 77, 152, 18, Component.literal("Network"));
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);

        rangeBox = new EditBox(font, x + 18, y + 119, 54, 18, Component.literal("Range"));
        rangeBox.setFilter(value -> value.matches("\\d*"));
        rangeBox.setValue(Integer.toString(menu.getRange()));
        addRenderableWidget(rangeBox);

        rateBox = new EditBox(font, x + 78, y + 119, 92, 18, Component.literal("Rate"));
        rateBox.setFilter(value -> value.matches("\\d*"));
        rateBox.setMaxLength(14);
        rateBox.setValue(Long.toString(menu.getChargeRate()));
        addRenderableWidget(rateBox);

        applyButton = addRenderableWidget(new KimiUiButton(x + 118, y + 145, 52, 18, Component.literal("APPLY"), false, b -> apply()).accent(CYAN));

        inventoryButton = addRenderableWidget(new KimiUiButton(x + 18, y + 78, 152, 20, Component.empty(), false, b -> { inventory = !inventory; apply(); }).accent(CYAN));
        armorButton = addRenderableWidget(new KimiUiButton(x + 18, y + 103, 152, 20, Component.empty(), false, b -> { armor = !armor; apply(); }).accent(CYAN));
        offhandButton = addRenderableWidget(new KimiUiButton(x + 18, y + 128, 152, 20, Component.empty(), false, b -> { offhand = !offhand; apply(); }).accent(CYAN));
        curiosButton = addRenderableWidget(new KimiUiButton(x + 18, y + 153, 152, 20, Component.empty(), false, b -> { curios = !curios; apply(); }).accent(CYAN));

        syncButtons();
        updateVisibility();
    }

    private void setTab(Tab next) {
        tab = next;
        updateVisibility();
        syncButtons();
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
        if (generalTab != null) generalTab.setSelected(tab == Tab.GENERAL);
        if (targetsTab != null) targetsTab.setSelected(tab == Tab.TARGETS);
        if (statsTab != null) statsTab.setSelected(tab == Tab.STATS);
        if (inventoryButton != null) inventoryButton.setMessage(Component.literal("INVENTORY            " + (inventory ? "ON" : "OFF")));
        if (armorButton != null) armorButton.setMessage(Component.literal("ARMOR                " + (armor ? "ON" : "OFF")));
        if (offhandButton != null) offhandButton.setMessage(Component.literal("OFFHAND              " + (offhand ? "ON" : "OFF")));
        if (curiosButton != null) curiosButton.setMessage(Component.literal("CURIOS               " + (curios ? "ON" : "OFF")));
        if (inventoryButton != null) inventoryButton.setSelected(inventory);
        if (armorButton != null) armorButton.setSelected(armor);
        if (offhandButton != null) offhandButton.setSelected(offhand);
        if (curiosButton != null) curiosButton.setSelected(curios);
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
        floatingPanel(g, x + 5, y + 21, imageWidth - 10, imageHeight - 26, CYAN);
        g.fill(x + 16, y + 49, x + imageWidth - 16, y + 50, 0x889AA1A8);
        if (tab == Tab.STATS) {
            drawBar(g, x + 18, y + 137, 152, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        }
    }

    private static void floatingPanel(GuiGraphics g, int x, int y, int w, int h, int border) {
        g.fill(x + 5, y, x + w - 5, y + h, PANEL);
        g.fill(x, y + 5, x + w, y + h - 5, PANEL);
        g.fill(x + 7, y + 7, x + w - 7, y + h - 7, INNER);
        g.fill(x + 5, y, x + w - 5, y + 2, border);
        g.fill(x + 5, y + h - 2, x + w - 5, y + h, border);
        g.fill(x, y + 5, x + 2, y + h - 5, border);
        g.fill(x + w - 2, y + 5, x + w, y + h - 5, border);
        g.fill(x + 2, y + 2, x + 5, y + 5, border);
        g.fill(x + w - 5, y + 2, x + w - 2, y + 5, border);
        g.fill(x + 2, y + h - 5, x + 5, y + h - 2, border);
        g.fill(x + w - 5, y + h - 5, x + w - 2, y + h - 2, border);
    }

    private static void drawBar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        g.fill(x, y, x + w, y + h, 0xAA343A40);
        int filled = (int) Math.round(w * fraction);
        if (filled > 0) g.fill(x, y, x + filled, y + h, color);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        g.drawString(font, "KIMI WIRELESS CHARGER", 18, 34, TEXT, false);
        g.drawString(font, "•", 161, 34, GREEN, false);
        if (tab == Tab.GENERAL) {
            g.drawString(font, "NETWORK", 18, 61, MUTED, false);
            g.drawString(font, "RANGE", 18, 103, MUTED, false);
            g.drawString(font, "RATE", 78, 103, MUTED, false);
            g.drawString(font, "LIVE  " + formatFe(menu.getLastDraw()) + " FE/t", 18, 151, GREEN, false);
            g.drawString(font, menu.getPlayers() + " PLAYER" + (menu.getPlayers() == 1 ? "" : "S") + " IN RANGE", 18, 168, MUTED, false);
        } else if (tab == Tab.TARGETS) {
            g.drawString(font, "WIRELESS TARGETS", 18, 61, MUTED, false);
            g.drawString(font, "Toggle exactly what KIMI may charge.", 18, 178, MUTED, false);
        } else {
            g.drawString(font, "COMPUTERCRAFT", 18, 61, MUTED, false);
            g.drawString(font, "kimi_wireless_charger", 18, 76, TEXT, false);
            g.drawString(font, "LIVE DRAW", 18, 100, MUTED, false);
            g.drawString(font, formatFe(menu.getLastDraw()) + " FE/t", 100, 100, GREEN, false);
            g.drawString(font, "PLAYERS", 18, 117, MUTED, false);
            g.drawString(font, Integer.toString(menu.getPlayers()), 151, 117, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 18, 129, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 18, 147, TEXT, false);
            g.drawString(font, "NETWORK  " + menu.getNetworkName(), 18, 165, MUTED, false);
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
        super.render(g, mouseX, mouseY, partialTick);
        renderTooltip(g, mouseX, mouseY);
    }
}
