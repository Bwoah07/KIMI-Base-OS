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
    private static final int HEADER = 0xFF171D24;
    private static final int SECTION = 0xFF10151B;
    private static final int BORDER = 0xFF68717A;
    private static final int TEXT = 0xFFE8EDF1;
    private static final int MUTED = 0xFF929CA5;
    private static final int GREEN = 0xFF65D98A;

    private EditBox networkBox;
    private EditBox rangeBox;
    private EditBox rateBox;
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
        imageWidth = 270;
        imageHeight = 230;
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

        networkBox = new EditBox(font, x + 16, y + 50, 182, 20, Component.literal("Network"));
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);
        addRenderableWidget(Button.builder(Component.literal("APPLY"), b -> apply()).bounds(x + 204, y + 50, 50, 20).build());

        rangeBox = new EditBox(font, x + 16, y + 94, 78, 20, Component.literal("Range"));
        rangeBox.setFilter(value -> value.matches("\\d*"));
        rangeBox.setValue(Integer.toString(menu.getRange()));
        addRenderableWidget(rangeBox);

        rateBox = new EditBox(font, x + 106, y + 94, 92, 20, Component.literal("Rate"));
        rateBox.setFilter(value -> value.matches("\\d*"));
        rateBox.setMaxLength(10);
        rateBox.setValue(Long.toString(menu.getChargeRate()));
        addRenderableWidget(rateBox);
        addRenderableWidget(Button.builder(Component.literal("SET"), b -> apply()).bounds(x + 204, y + 94, 50, 20).build());

        inventoryButton = addRenderableWidget(Button.builder(Component.empty(), b -> { inventory = !inventory; apply(); }).bounds(x + 16, y + 144, 112, 20).build());
        armorButton = addRenderableWidget(Button.builder(Component.empty(), b -> { armor = !armor; apply(); }).bounds(x + 142, y + 144, 112, 20).build());
        offhandButton = addRenderableWidget(Button.builder(Component.empty(), b -> { offhand = !offhand; apply(); }).bounds(x + 16, y + 169, 112, 20).build());
        curiosButton = addRenderableWidget(Button.builder(Component.empty(), b -> { curios = !curios; apply(); }).bounds(x + 142, y + 169, 112, 20).build());
        syncButtons();
    }

    private void syncButtons() {
        if (inventoryButton != null) inventoryButton.setMessage(Component.literal("INVENTORY  " + (inventory ? "ON" : "OFF")));
        if (armorButton != null) armorButton.setMessage(Component.literal("ARMOR  " + (armor ? "ON" : "OFF")));
        if (offhandButton != null) offhandButton.setMessage(Component.literal("OFFHAND  " + (offhand ? "ON" : "OFF")));
        if (curiosButton != null) curiosButton.setMessage(Component.literal("CURIOS  " + (curios ? "ON" : "OFF")));
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
        g.fill(x + 1, y + 1, x + imageWidth - 1, y + 29, HEADER);
        g.fill(x + 10, y + 36, x + imageWidth - 10, y + 76, SECTION);
        g.fill(x + 10, y + 82, x + imageWidth - 10, y + 120, SECTION);
        g.fill(x + 10, y + 128, x + imageWidth - 10, y + 195, SECTION);
        g.fill(x + 10, y + 201, x + imageWidth - 10, y + 220, SECTION);
    }

    private static void outline(GuiGraphics g, int x, int y, int w, int h, int c) {
        g.fill(x, y, x + w, y + 1, c); g.fill(x, y + h - 1, x + w, y + h, c);
        g.fill(x, y, x + 1, y + h, c); g.fill(x + w - 1, y, x + w, y + h, c);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        g.drawString(font, "KIMI WIRELESS CHARGER", 14, 11, TEXT, false);
        g.drawString(font, menu.getPlayers() + " PLAYER" + (menu.getPlayers() == 1 ? "" : "S") + " IN RANGE", 172, 11, GREEN, false);
        g.drawString(font, "NETWORK", 16, 34, MUTED, false);
        g.drawString(font, "RANGE", 16, 80, MUTED, false);
        g.drawString(font, "CHARGE RATE", 106, 80, MUTED, false);
        g.drawString(font, "TARGETS", 16, 126, MUTED, false);
        g.drawString(font, "LIVE DRAW  " + formatFe(menu.getLastDraw()) + " FE/t", 16, 204, GREEN, false);
        g.drawString(font, "NETWORK  " + formatFe(menu.getNetworkEnergy()) + " FE", 142, 204, MUTED, false);
    }

    private static String formatFe(long value) {
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
