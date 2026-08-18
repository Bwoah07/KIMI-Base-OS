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

public final class NetworkPlugScreen extends AbstractContainerScreen<NetworkPlugMenu> {
    private static final int PANEL = 0xD90A0D11;
    private static final int PANEL_INNER = 0xA811151A;
    private static final int FIELD = 0xD00A0D11;
    private static final int SILVER = 0xFFC9CED4;
    private static final int MUTED = 0xFF9DA5AD;
    private static final int TEXT = 0xFFF2F4F6;
    private static final int GREEN = 0xFF65E58E;
    private static final int ORANGE = 0xFFFF9E2E;
    private static final int CYAN = 0xFF50D1E0;

    private static final int NETWORK_ROWS = 4;
    private static final int LIST_X = 16;
    private static final int LIST_Y = 82;
    private static final int LIST_W = 151;
    private static final int ROW_H = 14;
    private static final int ROW_GAP = 2;
    private static final int SCROLL_X = 171;
    private static final int SCROLL_Y = 82;
    private static final int SCROLL_H = 62;

    private enum Tab { GENERAL, NETWORK, STATS, KIMI }
    private Tab tab = Tab.GENERAL;

    private KimiTabButton generalTab;
    private KimiTabButton networkTab;
    private KimiTabButton statsTab;
    private KimiTabButton kimiTab;

    private KimiUiButton offButton;
    private KimiUiButton inputButton;
    private KimiUiButton outputButton;
    private KimiUiButton createButton;
    private KimiUiButton setButton;
    private KimiUiButton maxButton;

    private final List<KimiUiButton> networkRows = new ArrayList<>();
    private EditBox limitBox;
    private EditBox newNetworkBox;
    private int networkScroll;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
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

        generalTab = addRenderableWidget(new KimiTabButton(x + 10, y + 18, 30, 24,
                Component.literal("Power Plug"), KimiTabButton.Icon.PLUG, b -> setTab(Tab.GENERAL)));
        networkTab = addRenderableWidget(new KimiTabButton(x + 44, y + 18, 30, 24,
                Component.literal("Network Selection"), KimiTabButton.Icon.NETWORK, b -> setTab(Tab.NETWORK)));
        statsTab = addRenderableWidget(new KimiTabButton(x + 78, y + 18, 30, 24,
                Component.literal("Power Statistics"), KimiTabButton.Icon.STATS, b -> setTab(Tab.STATS)));
        kimiTab = addRenderableWidget(new KimiTabButton(x + 112, y + 18, 30, 24,
                Component.literal("KIMI / ComputerCraft"), KimiTabButton.Icon.KIMI, b -> setTab(Tab.KIMI)));

        offButton = addRenderableWidget(new KimiUiButton(x + 16, y + 84, 48, 18,
                Component.literal("OFF"), false, b -> sendButton(0)));
        inputButton = addRenderableWidget(new KimiUiButton(x + 71, y + 84, 48, 18,
                Component.literal("INPUT"), false, b -> sendButton(1)).accent(GREEN));
        outputButton = addRenderableWidget(new KimiUiButton(x + 126, y + 84, 48, 18,
                Component.literal("OUTPUT"), false, b -> sendButton(2)).accent(ORANGE));

        limitBox = new EditBox(font, x + 18, y + 131, 91, 16, Component.literal("Transfer limit"));
        limitBox.setBordered(false);
        limitBox.setFilter(value -> value.matches("[0-9kKmMgGtT. ]*"));
        limitBox.setMaxLength(12);
        limitBox.setValue(formatEditable(menu.getTransferLimit()));
        addRenderableWidget(limitBox);
        setButton = addRenderableWidget(new KimiUiButton(x + 113, y + 129, 32, 20,
                Component.literal("SET"), false, b -> applyTypedLimit()));
        maxButton = addRenderableWidget(new KimiUiButton(x + 149, y + 129, 25, 20,
                Component.literal("MAX"), false, b -> sendButton(13)).accent(ORANGE));

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
            ).accent(CYAN));
            networkRows.add(button);
        }

        newNetworkBox = new EditBox(font, x + 18, y + 164, 105, 16, Component.literal("New network"));
        newNetworkBox.setBordered(false);
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(new KimiUiButton(x + 128, y + 162, 46, 20,
                Component.literal("CREATE"), false, b -> createNetwork()).accent(CYAN));

        syncWidgets();
        updateVisibility();
    }

    private void setTab(Tab newTab) {
        tab = newTab;
        updateVisibility();
        syncWidgets();
    }

    private void sendButton(int id) {
        if (minecraft != null && minecraft.gameMode != null) {
            minecraft.gameMode.handleInventoryButtonClick(menu.containerId, id);
        }
    }

    private void selectNetwork(int visibleSlot) {
        List<String> names = menu.getNetworkNames();
        clampNetworkScroll(names.size());
        int index = networkScroll + visibleSlot;
        if (index < 0 || index >= names.size()) return;
        sendButton(100 + index);
    }

    private void createNetwork() {
        if (newNetworkBox == null || newNetworkBox.getValue().isBlank()) return;
        String name = PowerNetworkSavedData.normalizeNetworkName(newNetworkBox.getValue());
        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.NetworkNamePayload(
                pos.getX(), pos.getY(), pos.getZ(), name));
        newNetworkBox.setValue("");
    }

    private void applyTypedLimit() {
        if (limitBox == null) return;
        try {
            long value = parseFeValue(limitBox.getValue());
            value = Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT,
                    Math.min(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT, value));
            BlockPos pos = menu.getBlockPos();
            PacketDistributor.sendToServer(new NetworkPlugNetworking.TransferLimitPayload(
                    pos.getX(), pos.getY(), pos.getZ(), value));
            limitBox.setValue(formatEditable(value));
        } catch (NumberFormatException ignored) {
            limitBox.setValue(formatEditable(menu.getTransferLimit()));
        }
    }

    private void syncWidgets() {
        PlugMode mode = menu.getMode();
        if (offButton != null) offButton.setSelected(mode == PlugMode.DISABLED);
        if (inputButton != null) inputButton.setSelected(mode == PlugMode.INPUT);
        if (outputButton != null) outputButton.setSelected(mode == PlugMode.OUTPUT);
        if (generalTab != null) generalTab.setSelected(tab == Tab.GENERAL);
        if (networkTab != null) networkTab.setSelected(tab == Tab.NETWORK);
        if (statsTab != null) statsTab.setSelected(tab == Tab.STATS);
        if (kimiTab != null) kimiTab.setSelected(tab == Tab.KIMI);
        syncNetworkRows();
    }

    private void updateVisibility() {
        boolean general = tab == Tab.GENERAL;
        boolean network = tab == Tab.NETWORK;

        offButton.visible = general;
        inputButton.visible = general;
        outputButton.visible = general;
        limitBox.visible = general;
        setButton.visible = general;
        maxButton.visible = general;

        for (KimiUiButton row : networkRows) row.visible = network;
        newNetworkBox.visible = network;
        createButton.visible = network;
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

    @Override
    protected void containerTick() {
        super.containerTick();
        syncWidgets();
        if (limitBox != null && !limitBox.isFocused()) {
            String value = formatEditable(menu.getTransferLimit());
            if (!limitBox.getValue().equals(value)) limitBox.setValue(value);
        }
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        int accent = modeColor();

        floatingPanel(g, x + 5, y + 44, 180, 166, SILVER);
        g.fill(x + 17, y + 47, x + 55, y + 49, accent);

        if (tab == Tab.GENERAL) {
            drawField(g, x + 16, y + 128, 94, 22, SILVER);
            drawBar(g, x + 16, y + 184, 158, 4,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
            drawToggle(g, x + 147, y + 195, true, GREEN);
        } else if (tab == Tab.NETWORK) {
            drawListPanel(g, x + LIST_X - 2, y + LIST_Y - 2, LIST_W + 10, 66);
            drawScrollbar(g, x, y, menu.getNetworkNames().size());
            drawField(g, x + 16, y + 161, 109, 22, SILVER);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 16, y + 115, 158, 4,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
            drawBar(g, x + 16, y + 155, 158, 4,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        } else {
            drawToggle(g, x + 147, y + 102, true, GREEN);
            drawToggle(g, x + 147, y + 130, true, CYAN);
        }
    }

    private int modeColor() {
        return menu.getMode() == PlugMode.INPUT ? GREEN : menu.getMode() == PlugMode.OUTPUT ? ORANGE : MUTED;
    }

    private static void floatingPanel(GuiGraphics g, int x, int y, int w, int h, int border) {
        g.fill(x + 6, y, x + w - 6, y + h, PANEL);
        g.fill(x, y + 6, x + w, y + h - 6, PANEL);
        g.fill(x + 3, y + 3, x + w - 3, y + h - 3, PANEL_INNER);
        g.fill(x + 6, y, x + w - 6, y + 1, border);
        g.fill(x + 6, y + h - 1, x + w - 6, y + h, border);
        g.fill(x, y + 6, x + 1, y + h - 6, border);
        g.fill(x + w - 1, y + 6, x + w, y + h - 6, border);
        g.fill(x + 1, y + 2, x + 6, y + 3, border);
        g.fill(x + w - 6, y + 2, x + w - 1, y + 3, border);
        g.fill(x + 1, y + h - 3, x + 6, y + h - 2, border);
        g.fill(x + w - 6, y + h - 3, x + w - 1, y + h - 2, border);
    }

    private static void drawField(GuiGraphics g, int x, int y, int w, int h, int border) {
        g.fill(x + 2, y, x + w - 2, y + h, FIELD);
        g.fill(x, y + 2, x + w, y + h - 2, FIELD);
        g.fill(x + 2, y, x + w - 2, y + 1, border);
        g.fill(x + 2, y + h - 1, x + w - 2, y + h, border);
        g.fill(x, y + 2, x + 1, y + h - 2, border);
        g.fill(x + w - 1, y + 2, x + w, y + h - 2, border);
    }

    private static void drawListPanel(GuiGraphics g, int x, int y, int w, int h) {
        g.fill(x + 2, y, x + w - 2, y + h, 0xA90A0D11);
        g.fill(x, y + 2, x + w, y + h - 2, 0xA90A0D11);
        g.fill(x + 2, y, x + w - 2, y + 1, 0xFF747C85);
        g.fill(x + 2, y + h - 1, x + w - 2, y + h, 0xFF747C85);
        g.fill(x, y + 2, x + 1, y + h - 2, 0xFF747C85);
        g.fill(x + w - 1, y + 2, x + w, y + h - 2, 0xFF747C85);
    }

    private void drawScrollbar(GuiGraphics g, int x, int y, int total) {
        int trackX = x + SCROLL_X;
        int trackY = y + SCROLL_Y;
        int maxScroll = Math.max(0, total - NETWORK_ROWS);
        g.fill(trackX, trackY, trackX + 4, trackY + SCROLL_H, 0xCC1B2025);
        if (total <= NETWORK_ROWS) {
            g.fill(trackX, trackY, trackX + 4, trackY + SCROLL_H, 0xFF707880);
            return;
        }
        int thumbH = Math.max(12, (SCROLL_H * NETWORK_ROWS) / total);
        int travel = SCROLL_H - thumbH;
        int thumbY = trackY + (int) Math.round(travel * (networkScroll / (double) maxScroll));
        g.fill(trackX, thumbY, trackX + 4, thumbY + thumbH, CYAN);
    }

    private static void drawToggle(GuiGraphics g, int x, int y, boolean enabled, int accent) {
        int knob = enabled ? accent : 0xFF666C72;
        g.fill(x + 2, y, x + 23, y + 10, 0xD0161A1E);
        g.fill(x, y + 2, x + 25, y + 8, 0xD0161A1E);
        g.fill(x + 2, y, x + 23, y + 1, 0xFF9299A0);
        g.fill(x + 2, y + 9, x + 23, y + 10, 0xFF9299A0);
        g.fill(x, y + 2, x + 1, y + 8, 0xFF9299A0);
        g.fill(x + 24, y + 2, x + 25, y + 8, 0xFF9299A0);
        int knobX = enabled ? x + 15 : x + 2;
        g.fill(knobX, y + 2, knobX + 8, y + 8, knob);
    }

    private static void drawBar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        g.fill(x, y, x + w, y + h, 0xAA333940);
        int filled = (int) Math.round(w * fraction);
        if (filled > 0) g.fill(x, y, x + filled, y + h, color);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        int accent = modeColor();
        String pageTitle = switch (tab) {
            case GENERAL -> "Power Plug";
            case NETWORK -> "Network Selection";
            case STATS -> "Power Statistics";
            case KIMI -> "KIMI / ComputerCraft";
        };
        g.drawString(font, pageTitle, 8, 3, TEXT, false);
        g.drawString(font, "KIMI POWER PLUG", 16, 52, TEXT, false);
        g.drawString(font, "•", 166, 52, accent, false);

        if (tab == Tab.GENERAL) {
            g.drawString(font, "MODE", 16, 74, MUTED, false);
            g.drawString(font, "TRANSFER LIMIT", 16, 116, MUTED, false);
            drawRight(g, formatFe(menu.getTransferLimit()) + " FE/t", 174, 116, TEXT);
            g.drawString(font, "LIVE", 16, 158, MUTED, false);
            g.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 50, 158, accent, false);
            g.drawString(font, "LOCAL BUFFER", 16, 172, MUTED, false);
            drawRight(g, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 174, 172, TEXT);
            g.drawString(font, "CHUNK LOADING", 16, 195, MUTED, false);
        } else if (tab == Tab.NETWORK) {
            g.drawString(font, "NETWORKS", 16, 71, MUTED, false);
            g.drawString(font, "CREATE NETWORK", 16, 151, MUTED, false);
            g.drawString(font, "PLUGS", 16, 188, MUTED, false);
            drawRight(g, Integer.toString(menu.getPlugCount()), 174, 188, TEXT);
            g.drawString(font, "BUFFER", 16, 201, MUTED, false);
            drawRight(g, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 174, 201, TEXT);
        } else if (tab == Tab.STATS) {
            g.drawString(font, "LIVE FLOW", 16, 73, MUTED, false);
            g.drawString(font, "+" + formatFe(menu.getNetworkInput()) + " / -" + formatFe(menu.getNetworkOutput()) + " FE/t", 16, 87, TEXT, false);
            g.drawString(font, "LOCAL BUFFER", 16, 103, MUTED, false);
            g.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 16, 121, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 16, 143, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 16, 161, TEXT, false);
            g.drawString(font, "NETWORK  " + menu.getNetworkName(), 16, 181, CYAN, false);
            BlockPos pos = menu.getBlockPos();
            g.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 196, MUTED, false);
        } else {
            g.drawString(font, "PERIPHERAL", 16, 75, MUTED, false);
            g.drawString(font, "kimi_network_plug", 16, 89, TEXT, false);
            g.drawString(font, "CC:TWEAKED API", 16, 103, MUTED, false);
            drawRight(g, "READY", 174, 103, GREEN);
            g.drawString(font, "SERVER REGISTRY", 16, 131, MUTED, false);
            drawRight(g, "ACTIVE", 174, 131, CYAN);
            g.drawString(font, "NETWORK", 16, 157, MUTED, false);
            drawRight(g, menu.getNetworkName(), 174, 157, CYAN);
            g.drawString(font, "ONE ATTACHED PLUG", 16, 181, TEXT, false);
            g.drawString(font, "LISTS + CONTROLS ALL PLUGS", 16, 195, MUTED, false);
        }
    }

    private void drawRight(GuiGraphics g, String text, int rightX, int y, int color) {
        g.drawString(font, text, rightX - font.width(text), y, color, false);
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
        String value = raw.trim().toUpperCase(Locale.ROOT)
                .replace("FE/T", "")
                .replace("FE", "")
                .replace(" ", "");
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
