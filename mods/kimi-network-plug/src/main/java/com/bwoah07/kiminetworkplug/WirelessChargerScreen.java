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
    private static final int BG = 0xF20A0D11;
    private static final int HEADER = 0xFF151A20;
    private static final int BODY = 0xFF0C1015;
    private static final int CARD = 0xFF11171D;
    private static final int BORDER = 0xFF9AA1A8;
    private static final int TEXT = 0xFFE8EDF1;
    private static final int MUTED = 0xFF929CA5;
    private static final int GREEN = 0xFF62E58E;
    private static final int BLUE = 0xFF59AEEA;

    private enum Tab { HOME, TARGETS, STATS }
    private Tab tab = Tab.HOME;

    private Button homeTab;
    private Button targetsTab;
    private Button statsTab;
    private EditBox networkBox;
    private EditBox rangeBox;
    private EditBox rateBox;
    private Button applyButton;
    private Button inventoryButton;
    private Button armorButton;
    private Button offhandButton;
    private Button curiosButton;
    private boolean inventory;
    private boolean armor;
    private boolean offhand;
    private boolean curios;

    public WirelessChargerScreen(WirelessChargerMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 196;
        imageHeight = 174;
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

        homeTab = addRenderableWidget(Button.builder(Component.literal("HOME"), b -> setTab(Tab.HOME)).bounds(x + 10, y + 29, 54, 18).build());
        targetsTab = addRenderableWidget(Button.builder(Component.literal("TARGETS"), b -> setTab(Tab.TARGETS)).bounds(x + 69, y + 29, 66, 18).build());
        statsTab = addRenderableWidget(Button.builder(Component.literal("STATS"), b -> setTab(Tab.STATS)).bounds(x + 140, y + 29, 46, 18).build());

        networkBox = new EditBox(font, x + 12, y + 66, 172, 18, Component.literal("Network"));
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);

        rangeBox = new EditBox(font, x + 12, y + 105, 64, 18, Component.literal("Range"));
        rangeBox.setFilter(value -> value.matches("\\d*"));
        rangeBox.setValue(Integer.toString(menu.getRange()));
        addRenderableWidget(rangeBox);

        rateBox = new EditBox(font, x + 82, y + 105, 72, 18, Component.literal("Rate"));
        rateBox.setFilter(value -> value.matches("\\d*"));
        rateBox.setMaxLength(12);
        rateBox.setValue(Long.toString(menu.getChargeRate()));
        addRenderableWidget(rateBox);
        applyButton = addRenderableWidget(Button.builder(Component.literal("APPLY"), b -> apply()).bounds(x + 158, y + 105, 26, 18).build());

        inventoryButton = addRenderableWidget(Button.builder(Component.empty(), b -> { inventory = !inventory; apply(); }).bounds(x + 12, y + 68, 80, 20).build());
        armorButton = addRenderableWidget(Button.builder(Component.empty(), b -> { armor = !armor; apply(); }).bounds(x + 104, y + 68, 80, 20).build());
        offhandButton = addRenderableWidget(Button.builder(Component.empty(), b -> { offhand = !offhand; apply(); }).bounds(x + 12, y + 99, 80, 20).build());
        curiosButton = addRenderableWidget(Button.builder(Component.empty(), b -> { curios = !curios; apply(); }).bounds(x + 104, y + 99, 80, 20).build());

        syncButtons();
        updateVisibility();
    }

    private void setTab(Tab newTab) {
        tab = newTab;
        updateVisibility();
    }

    private void updateVisibility() {
        boolean home = tab == Tab.HOME;
        boolean targets = tab == Tab.TARGETS;
        networkBox.visible = home;
        rangeBox.visible = home;
        rateBox.visible = home;
        applyButton.visible = home;
        inventoryButton.visible = targets;
        armorButton.visible = targets;
        offhandButton.visible = targets;
        curiosButton.visible = targets;
    }

    private void syncButtons() {
        if (inventoryButton != null) inventoryButton.setMessage(Component.literal("INV  " + (inventory ? "ON" : "OFF")));
        if (armorButton != null) armorButton.setMessage(Component.literal("ARMOR  " + (armor ? "ON" : "OFF")));
        if (offhandButton != null) offhandButton.setMessage(Component.literal("OFFHAND " + (offhand ? "ON" : "OFF")));
        if (curiosButton != null) curiosButton.setMessage(Component.literal("CURIOS " + (curios ? "ON" : "OFF")));
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
        networkBox.setValue(network);
        rangeBox.setValue(Integer.toString(range));
        rateBox.setValue(Long.toString(rate));
        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.ChargerConfigPayload(
                pos.getX(), pos.getY(), pos.getZ(), network, range, rate, inventory, armor, offhand, curios));
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
        g.fill(x, y, x + imageWidth, y + imageHeight, BG);
        outline(g, x, y, imageWidth, imageHeight, BORDER);
        g.fill(x + 1, y + 1, x + imageWidth - 1, y + 25, HEADER);
        g.fill(x + 7, y + 52, x + imageWidth - 7, y + imageHeight - 8, BODY);

        if (tab == Tab.HOME) {
            g.fill(x + 10, y + 55, x + 186, y + 91, CARD);
            g.fill(x + 10, y + 96, x + 186, y + 130, CARD);
            g.fill(x + 10, y + 136, x + 186, y + 160, CARD);
        } else if (tab == Tab.TARGETS) {
            g.fill(x + 10, y + 55, x + 186, y + 132, CARD);
        } else {
            g.fill(x + 10, y + 55, x + 186, y + 158, CARD);
            drawBar(g, x + 18, y + 113, 160, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, BLUE);
        }
    }

    private static void outline(GuiGraphics g, int x, int y, int w, int h, int c) {
        g.fill(x, y, x + w, y + 1, c);
        g.fill(x, y + h - 1, x + w, y + h, c);
        g.fill(x, y, x + 1, y + h, c);
        g.fill(x + w - 1, y, x + w, y + h, c);
    }

    private static void drawBar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        g.fill(x, y, x + w, y + h, 0xFF263039);
        int filled = (int) Math.round(w * fraction);
        if (filled > 0) g.fill(x, y, x + filled, y + h, color);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        g.drawString(font, "KIMI CHARGER", 10, 9, TEXT, false);
        g.drawString(font, "●", 174, 9, GREEN, false);

        if (tab == Tab.HOME) {
            g.drawString(font, "NETWORK", 12, 56, MUTED, false);
            g.drawString(font, "RANGE", 12, 97, MUTED, false);
            g.drawString(font, "RATE", 82, 97, MUTED, false);
            g.drawString(font, "LIVE  " + formatFe(menu.getLastDraw()) + " FE/t", 12, 140, GREEN, false);
            g.drawString(font, menu.getPlayers() + " PLAYER" + (menu.getPlayers() == 1 ? "" : "S") + " IN RANGE", 12, 153, MUTED, false);
        } else if (tab == Tab.TARGETS) {
            g.drawString(font, "WIRELESS TARGETS", 12, 57, MUTED, false);
            g.drawString(font, "Charge only the slots you want.", 12, 128, MUTED, false);
        } else {
            g.drawString(font, "KIMI LINK", 16, 59, MUTED, false);
            g.drawString(font, "ONLINE", 141, 59, GREEN, false);
            g.drawString(font, "LIVE DRAW", 16, 77, MUTED, false);
            g.drawString(font, formatFe(menu.getLastDraw()) + " FE/t", 106, 77, GREEN, false);
            g.drawString(font, "PLAYERS", 16, 93, MUTED, false);
            g.drawString(font, Integer.toString(menu.getPlayers()), 141, 93, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 16, 105, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 16, 122, TEXT, false);
            g.drawString(font, "NETWORK  " + menu.getNetworkName(), 16, 139, MUTED, false);
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
