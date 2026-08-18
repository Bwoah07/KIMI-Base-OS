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
    private static final int PANEL = 0xE00B0F13;
    private static final int PANEL_INNER = 0xB611161C;
    private static final int FIELD = 0xC90A0E12;
    private static final int SILVER = 0xFFC8CDD2;
    private static final int MUTED = 0xFF9AA3AB;
    private static final int TEXT = 0xFFF1F3F5;
    private static final int GREEN = 0xFF62E38D;
    private static final int ORANGE = 0xFFFFA33C;
    private static final int CYAN = 0xFF54CBD8;
    private static final int WARN = 0xFFFFC15C;

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

        generalTab = addRenderableWidget(new KimiTabButton(x + 10, y + 18, 28, 22,
                Component.literal("Power Plug"), KimiTabButton.Icon.PLUG, b -> setTab(Tab.GENERAL)));
        networkTab = addRenderableWidget(new KimiTabButton(x + 42, y + 18, 28, 22,
                Component.literal("Networks"), KimiTabButton.Icon.NETWORK, b -> setTab(Tab.NETWORK)));
        statsTab = addRenderableWidget(new KimiTabButton(x + 74, y + 18, 28, 22,
                Component.literal("Statistics"), KimiTabButton.Icon.STATS, b -> setTab(Tab.STATS)));
        kimiTab = addRenderableWidget(new KimiTabButton(x + 106, y + 18, 28, 22,
                Component.literal("KIMI / ComputerCraft"), KimiTabButton.Icon.KIMI, b -> setTab(Tab.KIMI)));

        offButton = addRenderableWidget(new KimiUiButton(x + 16, y + 82, 48, 16,
                Component.literal("OFF"), false, b -> sendButton(0)));
        inputButton = addRenderableWidget(new KimiUiButton(x + 71, y + 82, 48, 16,
                Component.literal("INPUT"), false, b -> sendButton(1)).accent(GREEN));
        outputButton = addRenderableWidget(new KimiUiButton(x + 126, y + 82, 48, 16,
                Component.literal("OUTPUT"), false, b -> sendButton(2)).accent(ORANGE));

        limitBox = new EditBox(font, x + 18, y + 120, 91, 14, Component.literal("Transfer limit"));
        limitBox.setBordered(false);
        limitBox.setFilter(value -> value.matches("[0-9kKmMgGtT. ]*"));
        limitBox.setMaxLength(12);
        limitBox.setValue(formatEditable(menu.getTransferLimit()));
        addRenderableWidget(limitBox);
        setButton = addRenderableWidget(new KimiUiButton(x + 113, y + 118, 32, 18,
                Component.literal("SET"), false, b -> applyTypedLimit()));
        maxButton = addRenderableWidget(new KimiUiButton(x + 149, y + 118, 25, 18,
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

        newNetworkBox = new EditBox(font, x + 18, y + 164, 105, 14, Component.literal("New network"));
        newNetworkBox.setBordered(false);
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(new KimiUiButton(x + 128, y + 162, 46, 18,
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
        if (minecraft != null && minecraft.gameMode != null) minecraft.gameMode.handleInventoryButtonClick(menu.containerId, id);
    }

    private void selectNetwork(int visibleSlot) {
        List<String> names = menu.getNetworkNames();
        clampNetworkScroll(names.size());
        int index = networkScroll + visibleSlot;
        if (index >= 0 && index < names.size()) sendButton(100 + index);
    }

    private void createNetwork() {
        if (newNetworkBox == null || newNetworkBox.getValue().isBlank()) return;
        String name = PowerNetworkSavedData.normalizeNetworkName(newNetworkBox.getValue());
        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.NetworkNamePayload(pos.getX(), pos.getY(), pos.getZ(), name));
        newNetworkBox.setValue("");
    }

    private void applyTypedLimit() {
        if (limitBox == null) return;
        try {
            long value = parseFeValue(limitBox.getValue());
            value = Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, Math.min(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT, value));
            BlockPos pos = menu.getBlockPos();
            PacketDistributor.sendToServer(new NetworkPlugNetworking.TransferLimitPayload(pos.getX(), pos.getY(), pos.getZ(), value));
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
        floatingPanel(g, x + 5, y + 44, 180, 166);
        g.fill(x + 17, y + 47, x + 55, y + 49, modeColor());

        if (tab == Tab.GENERAL) {
            drawField(g, x + 16, y + 117, 94, 20);
            drawBar(g, x + 16, y + 188, 158, 3,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, modeColor());
            drawToggle(g, x + 147, y + 196, true, GREEN);
        } else if (tab == Tab.NETWORK) {
            drawListPanel(g, x + LIST_X - 2, y + LIST_Y - 2, LIST_W + 10, 66);
            drawScrollbar(g, x, y, menu.getNetworkNames().size());
            drawField(g, x + 16, y + 161, 109, 20);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 16, y + 167, 158, 3,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, modeColor());
            drawBar(g, x + 16, y + 190, 158, 3,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        } else {
            drawToggle(g, x + 147, y + 100, true, GREEN);
            drawToggle(g, x + 147, y + 126, true, CYAN);
        }
    }

    private int modeColor() {
        return menu.getMode() == PlugMode.INPUT ? GREEN : menu.getMode() == PlugMode.OUTPUT ? ORANGE : MUTED;
    }

    private int bottleneckColor() {
        return menu.getBottleneck() == PowerBottleneck.NONE ? GREEN : WARN;
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

    private static void drawListPanel(GuiGraphics g, int x, int y, int w, int h) {
        g.fill(x, y, x + w, y + h, 0x8F090D11);
        g.fill(x, y, x + w, y + 1, 0xFF68717A);
        g.fill(x, y + h - 1, x + w, y + h, 0xFF68717A);
    }

    private void drawScrollbar(GuiGraphics g, int x, int y, int total) {
        int trackX = x + SCROLL_X;
        int trackY = y + SCROLL_Y;
        int maxScroll = Math.max(0, total - NETWORK_ROWS);
        g.fill(trackX, trackY, trackX + 3, trackY + SCROLL_H, 0xCC1B2025);
        if (total <= NETWORK_ROWS) {
            g.fill(trackX, trackY, trackX + 3, trackY + SCROLL_H, 0xFF6F7780);
            return;
        }
        int thumbH = Math.max(12, (SCROLL_H * NETWORK_ROWS) / total);
        int travel = SCROLL_H - thumbH;
        int thumbY = trackY + (int) Math.round(travel * (networkScroll / (double) maxScroll));
        g.fill(trackX, thumbY, trackX + 3, thumbY + thumbH, CYAN);
    }

    private static void drawToggle(GuiGraphics g, int x, int y, boolean enabled, int accent) {
        g.fill(x, y + 2, x + 25, y + 8, 0xDD151A1F);
        g.fill(x + 2, y, x + 23, y + 10, 0xDD151A1F);
        int knobX = enabled ? x + 15 : x + 2;
        g.fill(knobX, y + 2, knobX + 8, y + 8, enabled ? accent : 0xFF646B72);
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
            case GENERAL -> "Power Plug";
            case NETWORK -> "Networks";
            case STATS -> "Power Path";
            case KIMI -> "KIMI / ComputerCraft";
        };
        g.drawString(font, pageTitle, 8, 3, TEXT, false);
        g.drawString(font, "KIMI POWER PLUG", 16, 52, TEXT, false);
        g.drawString(font, "•", 166, 52, modeColor(), false);

        if (tab == Tab.GENERAL) {
            g.drawString(font, "MODE", 16, 72, MUTED, false);
            g.drawString(font, "TRANSFER LIMIT", 16, 104, MUTED, false);
            drawRight(g, formatFe(menu.getTransferLimit()) + " FE/t", 174, 104, TEXT);

            g.drawString(font, "STATUS", 16, 140, MUTED, false);
            String relation = menu.getMode() == PlugMode.INPUT ? "FROM  " : menu.getMode() == PlugMode.OUTPUT ? "TO    " : "BLOCK ";
            g.drawString(font, relation + trim(menu.getAttachedBlockName(), 22), 16, 152, TEXT, false);
            String flow = menu.getMode() == PlugMode.INPUT
                    ? formatFe(menu.getAttachedTransfer()) + " -> NET " + formatFe(menu.getNetworkTransfer())
                    : menu.getMode() == PlugMode.OUTPUT
                    ? "NET " + formatFe(menu.getNetworkTransfer()) + " -> " + formatFe(menu.getAttachedTransfer())
                    : "IDLE";
            g.drawString(font, flow + " FE/t", 16, 164, modeColor(), false);

            g.drawString(font, "LOCAL BUFFER", 16, 178, MUTED, false);
            drawRight(g, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 174, 178, TEXT);
            g.drawString(font, "CHUNK LOADING", 16, 197, MUTED, false);
        } else if (tab == Tab.NETWORK) {
            g.drawString(font, "NETWORKS", 16, 71, MUTED, false);
            g.drawString(font, "CREATE NETWORK", 16, 151, MUTED, false);
            g.drawString(font, "PLUGS  " + menu.getPlugCount(), 16, 188, MUTED, false);
            drawRight(g, "BUFFER  " + formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 174, 188, TEXT);
        } else if (tab == Tab.STATS) {
            String direction = menu.getMode() == PlugMode.INPUT ? "RECEIVING FROM" : menu.getMode() == PlugMode.OUTPUT ? "SENDING TO" : "ATTACHED BLOCK";
            g.drawString(font, direction, 16, 72, MUTED, false);
            g.drawString(font, trim(menu.getAttachedBlockName(), 28), 16, 85, TEXT, false);

            g.drawString(font, "ATTACHED BLOCK", 16, 105, MUTED, false);
            drawRight(g, formatFe(menu.getAttachedTransfer()) + " FE/t", 174, 105, modeColor());
            g.drawString(font, "POWERNET", 16, 120, MUTED, false);
            drawRight(g, formatFe(menu.getNetworkTransfer()) + " FE/t", 174, 120, CYAN);
            g.drawString(font, "LIMITED BY", 16, 138, MUTED, false);
            drawRight(g, bottleneckText(menu.getBottleneck()), 174, 138, bottleneckColor());

            g.drawString(font, "LOCAL", 16, 156, MUTED, false);
            drawRight(g, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 174, 156, TEXT);
            g.drawString(font, "NETWORK", 16, 179, MUTED, false);
            drawRight(g, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 174, 179, TEXT);
            BlockPos pos = menu.getBlockPos();
            g.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 199, MUTED, false);
        } else {
            g.drawString(font, "PERIPHERAL", 16, 75, MUTED, false);
            g.drawString(font, "kimi_network_plug", 16, 88, TEXT, false);
            g.drawString(font, "CC:TWEAKED API", 16, 101, MUTED, false);
            drawRight(g, "READY", 174, 101, GREEN);
            g.drawString(font, "SERVER REGISTRY", 16, 127, MUTED, false);
            drawRight(g, "ACTIVE", 174, 127, CYAN);
            g.drawString(font, "NETWORK", 16, 151, MUTED, false);
            drawRight(g, menu.getNetworkName(), 174, 151, CYAN);
            g.drawString(font, "ONE ATTACHED PLUG", 16, 177, TEXT, false);
            g.drawString(font, "CAN LIST + CONTROL ALL POWERNET PLUGS", 16, 190, MUTED, false);
        }
    }

    private void drawRight(GuiGraphics g, String text, int right, int y, int color) {
        g.drawString(font, text, right - font.width(text), y, color, false);
    }

    private static String bottleneckText(PowerBottleneck bottleneck) {
        return switch (bottleneck) {
            case NONE -> "NONE";
            case SOURCE -> "SOURCE";
            case NETWORK -> "NETWORK";
            case TARGET -> "TARGET";
            case NO_BLOCK -> "NO BLOCK";
        };
    }

    private static String trim(String value, int max) {
        if (value == null || value.isBlank()) return "No block";
        return value.length() <= max ? value : value.substring(0, Math.max(1, max - 1)) + "…";
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
