package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;
import net.neoforged.neoforge.network.PacketDistributor;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class WirelessChargerScreen extends AbstractContainerScreen<WirelessChargerMenu> {
    private static final int NETWORK_ROWS = 4;
    private static final int LIST_X = 16;
    private static final int LIST_Y = 82;
    private static final int LIST_W = 151;
    private static final int ROW_H = 14;
    private static final int ROW_GAP = 2;
    private static final int SCROLL_X = 171;
    private static final int SCROLL_Y = 82;
    private static final int SCROLL_H = 62;

    private enum Tab { GENERAL, NETWORK, TARGETS, STATS }
    private Tab tab = Tab.GENERAL;

    private KimiTabButton generalTab;
    private KimiTabButton networkTab;
    private KimiTabButton targetsTab;
    private KimiTabButton statsTab;
    private KimiUiButton applyButton;
    private final List<KimiUiButton> networkRows = new ArrayList<>();
    private KimiToggleButton inventoryButton;
    private KimiToggleButton armorButton;
    private KimiToggleButton offhandButton;
    private KimiToggleButton curiosButton;
    private EditBox rangeBox;
    private EditBox rateBox;
    private int networkScroll;
    private boolean inventory;
    private boolean armor;
    private boolean offhand;
    private boolean curios;

    public WirelessChargerScreen(WirelessChargerMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 190;
        imageHeight = 214;
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
        networkTab = addRenderableWidget(new KimiTabButton(x + 42, y + 18, 28, 22,
                Component.literal("Networks"), KimiTabButton.Icon.NETWORK, b -> setTab(Tab.NETWORK)));
        targetsTab = addRenderableWidget(new KimiTabButton(x + 74, y + 18, 28, 22,
                Component.literal("Charge Targets"), KimiTabButton.Icon.TARGETS, b -> setTab(Tab.TARGETS)));
        statsTab = addRenderableWidget(new KimiTabButton(x + 106, y + 18, 28, 22,
                Component.literal("Statistics"), KimiTabButton.Icon.STATS, b -> setTab(Tab.STATS)));

        rangeBox = new EditBox(font, x + 18, y + 87, 56, 14, Component.literal("Range"));
        rangeBox.setBordered(false);
        rangeBox.setFilter(value -> value.matches("\\d*"));
        rangeBox.setValue(Integer.toString(menu.getRange()));
        addRenderableWidget(rangeBox);

        rateBox = new EditBox(font, x + 92, y + 87, 78, 14, Component.literal("Rate"));
        rateBox.setBordered(false);
        rateBox.setFilter(value -> value.matches("[0-9kKmMgGtT. ]*"));
        rateBox.setMaxLength(12);
        rateBox.setValue(formatEditable(menu.getChargeRate()));
        addRenderableWidget(rateBox);

        applyButton = addRenderableWidget(new KimiUiButton(x + 122, y + 115, 48, 18,
                Component.literal("APPLY"), false, b -> apply()).accent(KimiUiTheme.CYAN));

        for (int row = 0; row < NETWORK_ROWS; row++) {
            final int slot = row;
            KimiUiButton button = addRenderableWidget(new KimiUiButton(
                    x + LIST_X,
                    y + LIST_Y + row * (ROW_H + ROW_GAP),
                    LIST_W,
                    ROW_H,
                    Component.empty(),
                    false,
                    b -> selectNetwork(slot)
            ).accent(KimiUiTheme.CYAN));
            networkRows.add(button);
        }

        inventoryButton = addRenderableWidget(new KimiToggleButton(x + 16, y + 82, 158, 22,
                Component.literal("Inventory"), b -> { inventory = !inventory; applyTargets(); }).accent(KimiUiTheme.CYAN));
        armorButton = addRenderableWidget(new KimiToggleButton(x + 16, y + 109, 158, 22,
                Component.literal("Armor"), b -> { armor = !armor; applyTargets(); }).accent(KimiUiTheme.CYAN));
        offhandButton = addRenderableWidget(new KimiToggleButton(x + 16, y + 136, 158, 22,
                Component.literal("Offhand"), b -> { offhand = !offhand; applyTargets(); }).accent(KimiUiTheme.CYAN));
        curiosButton = addRenderableWidget(new KimiToggleButton(x + 16, y + 163, 158, 22,
                Component.literal("Curios"), b -> { curios = !curios; applyTargets(); }).accent(KimiUiTheme.CYAN));

        syncWidgets();
        updateVisibility();
    }

    private void setTab(Tab next) {
        tab = next;
        updateVisibility();
        syncWidgets();
    }

    private void updateVisibility() {
        boolean general = tab == Tab.GENERAL;
        boolean network = tab == Tab.NETWORK;
        boolean targets = tab == Tab.TARGETS;
        rangeBox.visible = general;
        rateBox.visible = general;
        applyButton.visible = general;
        for (KimiUiButton row : networkRows) row.visible = network;
        inventoryButton.visible = targets;
        armorButton.visible = targets;
        offhandButton.visible = targets;
        curiosButton.visible = targets;
        syncNetworkRows();
    }

    private void syncWidgets() {
        if (generalTab != null) generalTab.setSelected(tab == Tab.GENERAL);
        if (networkTab != null) networkTab.setSelected(tab == Tab.NETWORK);
        if (targetsTab != null) targetsTab.setSelected(tab == Tab.TARGETS);
        if (statsTab != null) statsTab.setSelected(tab == Tab.STATS);
        if (inventoryButton != null) inventoryButton.setSelected(inventory);
        if (armorButton != null) armorButton.setSelected(armor);
        if (offhandButton != null) offhandButton.setSelected(offhand);
        if (curiosButton != null) curiosButton.setSelected(curios);
        syncNetworkRows();
    }

    private void syncNetworkRows() {
        List<String> names = menu.getNetworkNames();
        clampNetworkScroll(names.size());
        String selected = menu.getNetworkName();
        for (int slot = 0; slot < networkRows.size(); slot++) {
            int index = networkScroll + slot;
            KimiUiButton button = networkRows.get(slot);
            boolean exists = tab == Tab.NETWORK && index < names.size();
            button.visible = exists;
            if (!exists) continue;
            String name = names.get(index);
            button.setMessage(Component.literal(name));
            button.setSelected(name.equalsIgnoreCase(selected));
        }
    }

    private void clampNetworkScroll(int total) {
        int max = Math.max(0, total - NETWORK_ROWS);
        networkScroll = Math.max(0, Math.min(max, networkScroll));
    }

    private void selectNetwork(int visibleSlot) {
        List<String> names = menu.getNetworkNames();
        clampNetworkScroll(names.size());
        int index = networkScroll + visibleSlot;
        if (index < 0 || index >= names.size()) return;
        sendConfig(names.get(index), menu.getRange(), menu.getChargeRate());
    }

    private void apply() {
        int range;
        long rate;
        try { range = Integer.parseInt(rangeBox.getValue()); } catch (NumberFormatException e) { range = menu.getRange(); }
        try { rate = parseFeValue(rateBox.getValue()); } catch (NumberFormatException e) { rate = menu.getChargeRate(); }
        range = Math.max(WirelessChargerBlockEntity.MIN_RANGE, Math.min(WirelessChargerBlockEntity.MAX_RANGE, range));
        rate = Math.max(WirelessChargerBlockEntity.MIN_RATE, Math.min(WirelessChargerBlockEntity.MAX_RATE, rate));
        sendConfig(menu.getNetworkName(), range, rate);
        rangeBox.setValue(Integer.toString(range));
        rateBox.setValue(formatEditable(rate));
    }

    private void applyTargets() {
        sendConfig(menu.getNetworkName(), menu.getRange(), menu.getChargeRate());
        syncWidgets();
    }

    private void sendConfig(String network, int range, long rate) {
        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.ChargerConfigPayload(
                pos.getX(), pos.getY(), pos.getZ(), PowerNetworkSavedData.normalizeNetworkName(network),
                range, rate, inventory, armor, offhand, curios));
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        syncWidgets();
        if (rangeBox != null && !rangeBox.isFocused()) rangeBox.setValue(Integer.toString(menu.getRange()));
        if (rateBox != null && !rateBox.isFocused()) rateBox.setValue(formatEditable(menu.getChargeRate()));
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        KimiUiTheme.panel(g, x + 5, y + 44, 180, 166);
        KimiUiTheme.roundedRect(g, x + 17, y + 47, 38, 3, 2, KimiUiTheme.CYAN);

        if (tab == Tab.GENERAL) {
            KimiUiTheme.field(g, x + 16, y + 84, 60, 21);
            KimiUiTheme.field(g, x + 90, y + 84, 84, 21);
        } else if (tab == Tab.NETWORK) {
            KimiUiTheme.listPanel(g, x + LIST_X - 2, y + LIST_Y - 2, LIST_W + 10, 66);
            drawScrollbar(g, x, y, menu.getNetworkNames().size());
        } else if (tab == Tab.STATS) {
            KimiUiTheme.bar(g, x + 16, y + 151, 158, 5,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, KimiUiTheme.CYAN);
        }
    }

    private void drawScrollbar(GuiGraphics g, int x, int y, int total) {
        int trackX = x + SCROLL_X;
        int trackY = y + SCROLL_Y;
        int maxScroll = Math.max(0, total - NETWORK_ROWS);
        KimiUiTheme.roundedRect(g, trackX, trackY, 3, SCROLL_H, 2, 0xCC1B2025);
        if (total <= NETWORK_ROWS) {
            KimiUiTheme.roundedRect(g, trackX, trackY, 3, SCROLL_H, 2, 0xFF6F7780);
            return;
        }
        int thumbH = Math.max(12, (SCROLL_H * NETWORK_ROWS) / total);
        int travel = SCROLL_H - thumbH;
        int thumbY = trackY + (int) Math.round(travel * (networkScroll / (double) maxScroll));
        KimiUiTheme.roundedRect(g, trackX, thumbY, 3, thumbH, 2, KimiUiTheme.CYAN);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        String pageTitle = switch (tab) {
            case GENERAL -> "Wireless Charger";
            case NETWORK -> "Networks";
            case TARGETS -> "Charge Targets";
            case STATS -> "Charger Statistics";
        };
        KimiUiTheme.text(g, font, pageTitle, 8, 3, KimiUiTheme.TEXT, 0.88f);
        KimiUiTheme.text(g, font, "KIMI WIRELESS CHARGER", 16, 53, KimiUiTheme.TEXT, 0.88f);
        KimiUiTheme.roundedRect(g, 166, 54, 3, 3, 2, KimiUiTheme.GREEN);

        if (tab == Tab.GENERAL) {
            KimiUiTheme.text(g, font, "RANGE", 16, 72, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "RATE", 90, 72, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "LIVE DRAW", 16, 145, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getLastDraw()) + " FE/t", 174, 145, KimiUiTheme.GREEN, 0.78f);
            KimiUiTheme.text(g, font, "PLAYERS IN RANGE", 16, 166, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, Integer.toString(menu.getPlayers()), 174, 166, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.text(g, font, "NETWORK", 16, 188, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, menu.getNetworkName(), 174, 188, KimiUiTheme.CYAN, 0.78f);
        } else if (tab == Tab.NETWORK) {
            KimiUiTheme.text(g, font, "SELECT NETWORK", 16, 71, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "CURRENT", 16, 157, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, menu.getNetworkName(), 174, 157, KimiUiTheme.CYAN, 0.78f);
            KimiUiTheme.text(g, font, "BUFFER", 16, 178, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font,
                    formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY),
                    174, 178, KimiUiTheme.TEXT, 0.78f);
        } else if (tab == Tab.TARGETS) {
            KimiUiTheme.text(g, font, "CHARGE THESE SLOTS", 16, 70, KimiUiTheme.MUTED, 0.78f);
        } else {
            KimiUiTheme.text(g, font, "LIVE DRAW", 16, 78, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getLastDraw()) + " FE/t", 174, 78, KimiUiTheme.GREEN, 0.78f);
            KimiUiTheme.text(g, font, "PLAYERS", 16, 99, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, Integer.toString(menu.getPlayers()), 174, 99, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.text(g, font, "NETWORK BUFFER", 16, 123, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font,
                    formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY),
                    174, 139, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.text(g, font, "PERIPHERAL", 16, 169, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, "kimi_wireless_charger", 174, 169, KimiUiTheme.CYAN, 0.72f);
            KimiUiTheme.text(g, font, "NETWORK", 16, 190, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, menu.getNetworkName(), 174, 190, KimiUiTheme.CYAN, 0.78f);
        }
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double scrollX, double scrollY) {
        if (tab == Tab.NETWORK && insideNetworkList(mouseX, mouseY)) {
            List<String> names = menu.getNetworkNames();
            int max = Math.max(0, names.size() - NETWORK_ROWS);
            if (max > 0) {
                networkScroll += scrollY < 0 ? 1 : -1;
                networkScroll = Math.max(0, Math.min(max, networkScroll));
                syncNetworkRows();
            }
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, scrollX, scrollY);
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (super.mouseClicked(mouseX, mouseY, button)) return true;
        if (tab == Tab.NETWORK && button == 0) {
            int x = leftPos + SCROLL_X;
            int y = topPos + SCROLL_Y;
            if (mouseX >= x - 2 && mouseX <= x + 6 && mouseY >= y && mouseY <= y + SCROLL_H) {
                List<String> names = menu.getNetworkNames();
                int max = Math.max(0, names.size() - NETWORK_ROWS);
                if (max > 0) {
                    double ratio = Math.max(0.0, Math.min(1.0, (mouseY - y) / SCROLL_H));
                    networkScroll = (int) Math.round(ratio * max);
                    syncNetworkRows();
                }
                return true;
            }
        }
        return false;
    }

    private boolean insideNetworkList(double mouseX, double mouseY) {
        int x = leftPos + LIST_X - 2;
        int y = topPos + LIST_Y - 2;
        return mouseX >= x && mouseX <= x + LIST_W + 12 && mouseY >= y && mouseY <= y + 66;
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
