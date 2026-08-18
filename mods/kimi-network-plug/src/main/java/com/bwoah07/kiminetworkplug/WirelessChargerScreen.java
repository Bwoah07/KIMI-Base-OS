package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;
import net.neoforged.neoforge.network.PacketDistributor;

import java.util.Locale;

public final class WirelessChargerScreen extends AbstractContainerScreen<WirelessChargerMenu> {
    private static final int PANEL = 0xE00B0F13;
    private static final int PANEL_INNER = 0xB611161C;
    private static final int FIELD = 0xC90A0E12;
    private static final int SILVER = 0xFFC8CDD2;
    private static final int TEXT = 0xFFF1F3F5;
    private static final int MUTED = 0xFF9AA3AB;
    private static final int GREEN = 0xFF62E38D;
    private static final int CYAN = 0xFF54CBD8;

    private enum Tab { GENERAL, TARGETS, STATS }
    private Tab tab = Tab.GENERAL;

    private KimiTabButton generalTab;
    private KimiTabButton targetsTab;
    private KimiTabButton statsTab;
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
        imageWidth = 190;
        imageHeight = 204;
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

        generalTab = addRenderableWidget(new KimiTabButton(x + 10, y + 18, 28, 22,
                Component.literal("Wireless Charger"), KimiTabButton.Icon.CHARGER, b -> setTab(Tab.GENERAL)));
        targetsTab = addRenderableWidget(new KimiTabButton(x + 42, y + 18, 28, 22,
                Component.literal("Targets"), KimiTabButton.Icon.TARGETS, b -> setTab(Tab.TARGETS)));
        statsTab = addRenderableWidget(new KimiTabButton(x + 74, y + 18, 28, 22,
                Component.literal("Statistics"), KimiTabButton.Icon.STATS, b -> setTab(Tab.STATS)));

        networkBox = new EditBox(font, x + 18, y + 83, 152, 14, Component.literal("Network"));
        networkBox.setBordered(false);
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);

        rangeBox = new EditBox(font, x + 18, y + 120, 54, 14, Component.literal("Range"));
        rangeBox.setBordered(false);
        rangeBox.setFilter(value -> value.matches("\\d*"));
        rangeBox.setValue(Integer.toString(menu.getRange()));
        addRenderableWidget(rangeBox);

        rateBox = new EditBox(font, x + 82, y + 120, 88, 14, Component.literal("Rate"));
        rateBox.setBordered(false);
        rateBox.setFilter(value -> value.matches("[0-9kKmMgGtT. ]*"));
        rateBox.setMaxLength(12);
        rateBox.setValue(formatEditable(menu.getChargeRate()));
        addRenderableWidget(rateBox);

        applyButton = addRenderableWidget(new KimiUiButton(x + 118, y + 146, 52, 18,
                Component.literal("APPLY"), false, b -> apply()).accent(CYAN));

        inventoryButton = addRenderableWidget(new KimiUiButton(x + 18, y + 82, 152, 18, Component.empty(), false,
                b -> { inventory = !inventory; apply(); }).accent(CYAN));
        armorButton = addRenderableWidget(new KimiUiButton(x + 18, y + 106, 152, 18, Component.empty(), false,
                b -> { armor = !armor; apply(); }).accent(CYAN));
        offhandButton = addRenderableWidget(new KimiUiButton(x + 18, y + 130, 152, 18, Component.empty(), false,
                b -> { offhand = !offhand; apply(); }).accent(CYAN));
        curiosButton = addRenderableWidget(new KimiUiButton(x + 18, y + 154, 152, 18, Component.empty(), false,
                b -> { curios = !curios; apply(); }).accent(CYAN));

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
        if (inventoryButton != null) inventoryButton.setMessage(Component.literal("INVENTORY        " + (inventory ? "ON" : "OFF")));
        if (armorButton != null) armorButton.setMessage(Component.literal("ARMOR            " + (armor ? "ON" : "OFF")));
        if (offhandButton != null) offhandButton.setMessage(Component.literal("OFFHAND          " + (offhand ? "ON" : "OFF")));
        if (curiosButton != null) curiosButton.setMessage(Component.literal("CURIOS           " + (curios ? "ON" : "OFF")));
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
        try { rate = parseFeValue(rateBox.getValue()); } catch (NumberFormatException e) { rate = menu.getChargeRate(); }
        range = Math.max(WirelessChargerBlockEntity.MIN_RANGE, Math.min(WirelessChargerBlockEntity.MAX_RANGE, range));
        rate = Math.max(WirelessChargerBlockEntity.MIN_RATE, Math.min(WirelessChargerBlockEntity.MAX_RATE, rate));
        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.ChargerConfigPayload(
                pos.getX(), pos.getY(), pos.getZ(), network, range, rate, inventory, armor, offhand, curios));
        networkBox.setValue(network);
        rangeBox.setValue(Integer.toString(range));
        rateBox.setValue(formatEditable(rate));
        syncButtons();
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        if (networkBox != null && !networkBox.isFocused()) networkBox.setValue(menu.getNetworkName());
        if (rangeBox != null && !rangeBox.isFocused()) rangeBox.setValue(Integer.toString(menu.getRange()));
        if (rateBox != null && !rateBox.isFocused()) rateBox.setValue(formatEditable(menu.getChargeRate()));
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        floatingPanel(g, x + 5, y + 44, 180, 154);
        g.fill(x + 17, y + 47, x + 55, y + 49, CYAN);

        if (tab == Tab.GENERAL) {
            drawField(g, x + 16, y + 80, 158, 20);
            drawField(g, x + 16, y + 117, 58, 20);
            drawField(g, x + 80, y + 117, 94, 20);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 16, y + 150, 158, 3,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        }
    }

    private static void floatingPanel(GuiGraphics g, int x, int y, int w, int h) {
        g.fill(x + 7, y, x + w - 7, y + h, PANEL);
        g.fill(x + 2, y + 3, x + w - 2, y + h - 3, PANEL);
        g.fill(x, y + 7, x + w, y + h - 7, PANEL);
        g.fill(x + 4, y + 4, x + w - 4, y + h - 4, PANEL_INNER);
        g.fill(x + 7, y, x + w - 7, y + 1, SILVER);
        g.fill(x + 7, y + h - 1, x + w - 7, y + h, SILVER);
        g.fill(x, y + 7, x + 1, y + h - 7, SILVER);
        g.fill(x + w - 1, y + 7, x + w, y + h - 7, SILVER);
    }

    private static void drawField(GuiGraphics g, int x, int y, int w, int h) {
        g.fill(x, y, x + w, y + h, FIELD);
        g.fill(x, y, x + w, y + 1, 0xFF7E8790);
        g.fill(x, y + h - 1, x + w, y + h, 0xFF7E8790);
    }

    private static void drawBar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        g.fill(x, y, x + w, y + h, 0xAA343A40);
        int filled = (int) Math.round(w * fraction);
        if (filled > 0) g.fill(x, y, x + filled, y + h, color);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        String pageTitle = switch (tab) {
            case GENERAL -> "Wireless Charger";
            case TARGETS -> "Charge Targets";
            case STATS -> "Charger Statistics";
        };
        g.drawString(font, pageTitle, 8, 3, TEXT, false);
        g.drawString(font, "KIMI WIRELESS CHARGER", 16, 52, TEXT, false);
        g.drawString(font, "•", 166, 52, GREEN, false);

        if (tab == Tab.GENERAL) {
            g.drawString(font, "NETWORK", 16, 70, MUTED, false);
            g.drawString(font, "RANGE", 16, 107, MUTED, false);
            g.drawString(font, "RATE", 80, 107, MUTED, false);
            g.drawString(font, "LIVE", 16, 151, MUTED, false);
            drawRight(g, formatFe(menu.getLastDraw()) + " FE/t", 174, 151, GREEN);
            g.drawString(font, "PLAYERS IN RANGE", 16, 170, MUTED, false);
            drawRight(g, Integer.toString(menu.getPlayers()), 174, 170, TEXT);
        } else if (tab == Tab.TARGETS) {
            g.drawString(font, "WIRELESS TARGETS", 16, 70, MUTED, false);
            g.drawString(font, "Click a row to toggle charging.", 16, 180, MUTED, false);
        } else {
            g.drawString(font, "PERIPHERAL", 16, 74, MUTED, false);
            g.drawString(font, "kimi_wireless_charger", 16, 87, TEXT, false);
            g.drawString(font, "LIVE DRAW", 16, 108, MUTED, false);
            drawRight(g, formatFe(menu.getLastDraw()) + " FE/t", 174, 108, GREEN);
            g.drawString(font, "PLAYERS", 16, 124, MUTED, false);
            drawRight(g, Integer.toString(menu.getPlayers()), 174, 124, TEXT);
            g.drawString(font, "NETWORK BUFFER", 16, 140, MUTED, false);
            drawRight(g, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 174, 157, TEXT);
            g.drawString(font, "NETWORK", 16, 176, MUTED, false);
            drawRight(g, menu.getNetworkName(), 174, 176, CYAN);
        }
    }

    private void drawRight(GuiGraphics g, String text, int right, int y, int color) {
        g.drawString(font, text, right - font.width(text), y, color, false);
    }

    private static long parseFeValue(String raw) throws NumberFormatException {
        String value = raw.trim().toUpperCase(Locale.ROOT).replace("FE/T", "").replace("FE", "").replace(" ", "");
        if (value.isBlank()) throw new NumberFormatException("empty");
        long multiplier = 1L;
        char suffix = value.charAt(value.length() - 1);
        if (suffix == 'K' || suffix == 'M' || suffix == 'G' || suffix == 'T') {
            value = value.substring(0, value.length() - 1);
            multiplier = switch (suffix) {
                case 'K' -> 1_000L;
                case 'M' -> 1_000_000L;
                case 'G' -> 1_000_000_000L;
                case 'T' -> 1_000_000_000_000L;
                default -> 1L;
            };
        }
        double numeric = Double.parseDouble(value);
        if (!Double.isFinite(numeric) || numeric < 0.0) throw new NumberFormatException("invalid");
        double result = numeric * multiplier;
        if (result > Long.MAX_VALUE) return Long.MAX_VALUE;
        return Math.round(result);
    }

    private static String formatEditable(long value) {
        if (value % 1_000_000_000L == 0 && value >= 1_000_000_000L) return (value / 1_000_000_000L) + "G";
        if (value % 1_000_000L == 0 && value >= 1_000_000L) return (value / 1_000_000L) + "M";
        if (value % 1_000L == 0 && value >= 1_000L) return (value / 1_000L) + "k";
        return Long.toString(value);
    }

    private static String formatFe(long value) {
        if (value >= 1_000_000_000_000L) return compact(value / 1_000_000_000_000.0) + "T";
        if (value >= 1_000_000_000L) return compact(value / 1_000_000_000.0) + "G";
        if (value >= 1_000_000L) return compact(value / 1_000_000.0) + "M";
        if (value >= 1_000L) return compact(value / 1_000.0) + "k";
        return Long.toString(value);
    }

    private static String compact(double value) {
        String out = String.format(Locale.ROOT, "%.2f", value);
        while (out.endsWith("0")) out = out.substring(0, out.length() - 1);
        if (out.endsWith(".")) out = out.substring(0, out.length() - 1);
        return out;
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        super.render(g, mouseX, mouseY, partialTick);
        renderTooltip(g, mouseX, mouseY);
    }
}
