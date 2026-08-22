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
                Component.literal("Power Path"), KimiTabButton.Icon.STATS, b -> setTab(Tab.STATS)));
        kimiTab = addRenderableWidget(new KimiTabButton(x + 106, y + 18, 28, 22,
                Component.literal("KIMI / ComputerCraft"), KimiTabButton.Icon.KIMI, b -> setTab(Tab.KIMI)));

        offButton = addRenderableWidget(new KimiUiButton(x + 16, y + 82, 48, 16,
                Component.literal("OFF"), false, b -> sendButton(0)));
        inputButton = addRenderableWidget(new KimiUiButton(x + 71, y + 82, 48, 16,
                Component.literal("INPUT"), false, b -> sendButton(1)).accent(KimiUiTheme.GREEN));
        outputButton = addRenderableWidget(new KimiUiButton(x + 126, y + 82, 48, 16,
                Component.literal("OUTPUT"), false, b -> sendButton(2)).accent(KimiUiTheme.ORANGE));

        limitBox = new EditBox(font, x + 18, y + 120, 91, 14, Component.literal("Transfer limit"));
        limitBox.setBordered(false);
        limitBox.setFilter(value -> value.matches("[0-9kKmMgGtT. ]*"));
        limitBox.setMaxLength(12);
        limitBox.setValue(formatEditable(menu.getTransferLimit()));
        addRenderableWidget(limitBox);
        setButton = addRenderableWidget(new KimiUiButton(x + 113, y + 118, 32, 18,
                Component.literal("SET"), false, b -> applyTypedLimit()));
        maxButton = addRenderableWidget(new KimiUiButton(x + 149, y + 118, 25, 18,
                Component.literal("MAX"), false, b -> sendButton(13)).accent(KimiUiTheme.ORANGE));

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

        newNetworkBox = new EditBox(font, x + 18, y + 164, 105, 14, Component.literal("New network"));
        newNetworkBox.setBordered(false);
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(new KimiUiButton(x + 128, y + 162, 46, 18,
                Component.literal("CREATE"), false, b -> createNetwork()).accent(KimiUiTheme.CYAN));

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
        KimiUiTheme.panel(g, x + 5, y + 44, 180, 166);
        KimiUiTheme.roundedRect(g, x + 17, y + 47, 38, 3, 2, modeColor());

        if (tab == Tab.GENERAL) {
            KimiUiTheme.field(g, x + 16, y + 117, 94, 20);
            KimiUiTheme.bar(g, x + 16, y + 188, 158, 4,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, modeColor());
            KimiUiTheme.toggle(g, x + 147, y + 195, true, KimiUiTheme.GREEN);
        } else if (tab == Tab.NETWORK) {
            KimiUiTheme.listPanel(g, x + LIST_X - 2, y + LIST_Y - 2, LIST_W + 10, 66);
            drawScrollbar(g, x, y, menu.getNetworkNames().size());
            KimiUiTheme.field(g, x + 16, y + 161, 109, 20);
        } else if (tab == Tab.STATS) {
            KimiUiTheme.bar(g, x + 16, y + 167, 158, 4,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, modeColor());
            KimiUiTheme.bar(g, x + 16, y + 190, 158, 4,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, KimiUiTheme.CYAN);
        } else {
            KimiUiTheme.toggle(g, x + 147, y + 100, true, KimiUiTheme.GREEN);
            KimiUiTheme.toggle(g, x + 147, y + 126, true, KimiUiTheme.CYAN);
        }
    }

    private int modeColor() {
        return menu.getMode() == PlugMode.INPUT ? KimiUiTheme.GREEN : menu.getMode() == PlugMode.OUTPUT ? KimiUiTheme.ORANGE : KimiUiTheme.MUTED;
    }

    private int bottleneckColor() {
        return menu.getBottleneck() == PowerBottleneck.NONE ? KimiUiTheme.GREEN : KimiUiTheme.WARN;
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
            case GENERAL -> "Power Plug";
            case NETWORK -> "Networks";
            case STATS -> "Power Path";
            case KIMI -> "KIMI / ComputerCraft";
        };
        KimiUiTheme.text(g, font, pageTitle, 8, 3, KimiUiTheme.TEXT, 0.88f);
        KimiUiTheme.text(g, font, "KIMI POWER PLUG", 16, 53, KimiUiTheme.TEXT, 0.88f);
        KimiUiTheme.roundedRect(g, 166, 54, 3, 3, 2, modeColor());

        if (tab == Tab.GENERAL) {
            KimiUiTheme.text(g, font, "MODE", 16, 72, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "TRANSFER LIMIT", 16, 104, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getTransferLimit()) + " FE/t", 174, 104, KimiUiTheme.TEXT, 0.78f);

            String direction = menu.getMode() == PlugMode.INPUT ? "RECEIVING FROM" : menu.getMode() == PlugMode.OUTPUT ? "SENDING TO" : "ATTACHED BLOCK";
            KimiUiTheme.text(g, font, direction, 16, 140, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, KimiUiTheme.fit(font, menu.getAttachedBlockName(), 158, 0.82f), 16, 152, KimiUiTheme.TEXT, 0.82f);
            String flow = menu.getMode() == PlugMode.INPUT
                    ? "BLOCK " + formatFe(menu.getAttachedTransfer()) + "  |  NET " + formatFe(menu.getNetworkTransfer())
                    : menu.getMode() == PlugMode.OUTPUT
                    ? "NET " + formatFe(menu.getNetworkTransfer()) + "  |  BLOCK " + formatFe(menu.getAttachedTransfer())
                    : "IDLE";
            KimiUiTheme.text(g, font, flow + " FE/t", 16, 164, modeColor(), 0.72f);

            KimiUiTheme.text(g, font, "LOCAL BUFFER", 16, 178, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 174, 178, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.text(g, font, "CHUNK LOADING", 16, 197, KimiUiTheme.MUTED, 0.78f);
        } else if (tab == Tab.NETWORK) {
            KimiUiTheme.text(g, font, "NETWORKS", 16, 71, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "CREATE NETWORK", 16, 151, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "PLUGS", 16, 188, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, Integer.toString(menu.getPlugCount()), 49, 188, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 174, 188, KimiUiTheme.TEXT, 0.78f);
        } else if (tab == Tab.STATS) {
            String direction = menu.getMode() == PlugMode.INPUT ? "RECEIVING FROM" : menu.getMode() == PlugMode.OUTPUT ? "SENDING TO" : "ATTACHED BLOCK";
            KimiUiTheme.text(g, font, direction, 16, 72, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, KimiUiTheme.fit(font, menu.getAttachedBlockName(), 158, 0.84f), 16, 85, KimiUiTheme.TEXT, 0.84f);

            KimiUiTheme.text(g, font, "ATTACHED BLOCK", 16, 108, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getAttachedTransfer()) + " FE/t", 174, 108, modeColor(), 0.78f);
            KimiUiTheme.text(g, font, "POWERNET", 16, 123, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getNetworkTransfer()) + " FE/t", 174, 123, KimiUiTheme.CYAN, 0.78f);
            KimiUiTheme.text(g, font, "LIMITED BY", 16, 141, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, bottleneckText(menu.getBottleneck()), 174, 141, bottleneckColor(), 0.78f);

            KimiUiTheme.text(g, font, "LOCAL", 16, 157, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 174, 157, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.text(g, font, "NETWORK", 16, 180, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 174, 180, KimiUiTheme.TEXT, 0.78f);
            BlockPos pos = menu.getBlockPos();
            KimiUiTheme.text(g, font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 199, KimiUiTheme.MUTED, 0.72f);
        } else {
            KimiUiTheme.text(g, font, "PERIPHERAL", 16, 75, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.text(g, font, "kimi_network_plug", 16, 89, KimiUiTheme.TEXT, 0.78f);
            KimiUiTheme.text(g, font, "CC:TWEAKED", 16, 103, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, "READY", 174, 103, KimiUiTheme.GREEN, 0.78f);
            KimiUiTheme.text(g, font, "SERVER REGISTRY", 16, 129, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, "ACTIVE", 174, 129, KimiUiTheme.CYAN, 0.78f);
            KimiUiTheme.text(g, font, "NETWORK", 16, 153, KimiUiTheme.MUTED, 0.78f);
            KimiUiTheme.rightText(g, font, menu.getNetworkName(), 174, 153, KimiUiTheme.CYAN, 0.78f);
            KimiUiTheme.text(g, font, "ONE ATTACHED PLUG CAN", 16, 179, KimiUiTheme.TEXT, 0.74f);
            KimiUiTheme.text(g, font, "LIST + CONTROL ALL POWERNET PLUGS", 16, 191, KimiUiTheme.MUTED, 0.70f);
        }
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
