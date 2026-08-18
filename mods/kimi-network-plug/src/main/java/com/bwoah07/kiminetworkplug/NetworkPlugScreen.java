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

public final class NetworkPlugScreen extends AbstractContainerScreen<NetworkPlugMenu> {
    private static final int PANEL = 0xD9050709;
    private static final int PANEL_INNER = 0xA4080B0E;
    private static final int FIELD = 0xC8080B0F;
    private static final int SILVER = 0xFFD0D4D8;
    private static final int MUTED = 0xFFA1A7AE;
    private static final int TEXT = 0xFFF1F3F5;
    private static final int GREEN = 0xFF64E58F;
    private static final int ORANGE = 0xFFFF9F2F;
    private static final int CYAN = 0xFF50D1E0;

    private enum Tab { GENERAL, NETWORK, STATS, KIMI }
    private Tab tab = Tab.GENERAL;

    private KimiUiButton generalTab;
    private KimiUiButton networkTab;
    private KimiUiButton statsTab;
    private KimiUiButton kimiTab;
    private KimiUiButton offButton;
    private KimiUiButton inputButton;
    private KimiUiButton outputButton;
    private KimiUiButton networkSelector;
    private KimiUiButton createButton;
    private KimiUiButton setButton;
    private KimiUiButton maxButton;
    private final List<KimiUiButton> networkOptions = new ArrayList<>();
    private EditBox limitBox;
    private EditBox newNetworkBox;
    private boolean dropdownOpen;

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

        generalTab = addRenderableWidget(new KimiUiButton(x + 10, y + 18, 30, 24, Component.literal("⌂"), true, b -> setTab(Tab.GENERAL)));
        networkTab = addRenderableWidget(new KimiUiButton(x + 44, y + 18, 30, 24, Component.literal("≡"), true, b -> setTab(Tab.NETWORK)));
        statsTab = addRenderableWidget(new KimiUiButton(x + 78, y + 18, 30, 24, Component.literal("▥"), true, b -> setTab(Tab.STATS)));
        kimiTab = addRenderableWidget(new KimiUiButton(x + 112, y + 18, 30, 24, Component.literal("K"), true, b -> setTab(Tab.KIMI)));

        networkSelector = addRenderableWidget(new KimiUiButton(x + 16, y + 64, 158, 20,
                Component.literal(menu.getNetworkName() + "  v"), false, b -> toggleDropdown()).accent(CYAN));

        offButton = addRenderableWidget(new KimiUiButton(x + 16, y + 94, 48, 18, Component.literal("OFF"), false, b -> sendButton(0)));
        inputButton = addRenderableWidget(new KimiUiButton(x + 71, y + 94, 48, 18, Component.literal("INPUT"), false, b -> sendButton(1)).accent(GREEN));
        outputButton = addRenderableWidget(new KimiUiButton(x + 126, y + 94, 48, 18, Component.literal("OUTPUT"), false, b -> sendButton(2)).accent(ORANGE));

        limitBox = new EditBox(font, x + 18, y + 134, 91, 16, Component.literal("Transfer limit"));
        limitBox.setBordered(false);
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(14);
        limitBox.setValue(Long.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);
        setButton = addRenderableWidget(new KimiUiButton(x + 113, y + 132, 32, 20, Component.literal("SET"), false, b -> applyTypedLimit()));
        maxButton = addRenderableWidget(new KimiUiButton(x + 149, y + 132, 25, 20, Component.literal("MAX"), false, b -> sendButton(13)).accent(ORANGE));

        newNetworkBox = new EditBox(font, x + 18, y + 108, 105, 16, Component.literal("New network"));
        newNetworkBox.setBordered(false);
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(new KimiUiButton(x + 128, y + 106, 46, 20,
                Component.literal("CREATE"), false, b -> createNetwork()).accent(CYAN));

        for (int i = 0; i < NetworkPlugMenu.MAX_VISIBLE_NETWORKS; i++) {
            final int index = i;
            int col = i / 6;
            int row = i % 6;
            KimiUiButton option = addRenderableWidget(new KimiUiButton(
                    x + 16 + col * 80,
                    y + 88 + row * 18,
                    76,
                    17,
                    Component.empty(),
                    false,
                    b -> selectNetwork(index)
            ).accent(CYAN));
            option.visible = false;
            networkOptions.add(option);
        }

        syncWidgets();
        updateVisibility();
    }

    private void setTab(Tab newTab) {
        tab = newTab;
        dropdownOpen = false;
        updateVisibility();
        syncWidgets();
    }

    private void sendButton(int id) {
        if (minecraft != null && minecraft.gameMode != null) minecraft.gameMode.handleInventoryButtonClick(menu.containerId, id);
    }

    private void toggleDropdown() {
        dropdownOpen = !dropdownOpen;
        updateVisibility();
        syncDropdown();
    }

    private void selectNetwork(int index) {
        sendButton(100 + index);
        dropdownOpen = false;
        updateVisibility();
        syncDropdown();
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
            long value = Long.parseLong(limitBox.getValue());
            value = Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, Math.min(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT, value));
            limitBox.setValue(Long.toString(value));
            BlockPos pos = menu.getBlockPos();
            PacketDistributor.sendToServer(new NetworkPlugNetworking.TransferLimitPayload(pos.getX(), pos.getY(), pos.getZ(), value));
        } catch (NumberFormatException ignored) {
            limitBox.setValue(Long.toString(menu.getTransferLimit()));
        }
    }

    private void syncWidgets() {
        PlugMode mode = menu.getMode();
        if (offButton != null) offButton.setSelected(mode == PlugMode.DISABLED);
        if (inputButton != null) inputButton.setSelected(mode == PlugMode.INPUT);
        if (outputButton != null) outputButton.setSelected(mode == PlugMode.OUTPUT);
        if (networkSelector != null) networkSelector.setMessage(Component.literal(menu.getNetworkName() + "  v"));
        if (generalTab != null) generalTab.setSelected(tab == Tab.GENERAL);
        if (networkTab != null) networkTab.setSelected(tab == Tab.NETWORK);
        if (statsTab != null) statsTab.setSelected(tab == Tab.STATS);
        if (kimiTab != null) kimiTab.setSelected(tab == Tab.KIMI);
        syncDropdown();
    }

    private void updateVisibility() {
        boolean general = tab == Tab.GENERAL;
        boolean network = tab == Tab.NETWORK;
        boolean selectorPage = general || network;

        networkSelector.visible = selectorPage;
        offButton.visible = general && !dropdownOpen;
        inputButton.visible = general && !dropdownOpen;
        outputButton.visible = general && !dropdownOpen;
        limitBox.visible = general && !dropdownOpen;
        setButton.visible = general && !dropdownOpen;
        maxButton.visible = general && !dropdownOpen;

        newNetworkBox.visible = network && !dropdownOpen;
        createButton.visible = network && !dropdownOpen;
        syncDropdown();
    }

    private void syncDropdown() {
        List<String> names = menu.getNetworkNames();
        boolean show = dropdownOpen && (tab == Tab.GENERAL || tab == Tab.NETWORK);
        for (int i = 0; i < networkOptions.size(); i++) {
            KimiUiButton button = networkOptions.get(i);
            button.visible = show && i < names.size();
            if (i < names.size()) button.setMessage(Component.literal(names.get(i)));
        }
        if (newNetworkBox != null) newNetworkBox.visible = tab == Tab.NETWORK && !dropdownOpen;
        if (createButton != null) createButton.visible = tab == Tab.NETWORK && !dropdownOpen;
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        syncWidgets();
        if (limitBox != null && !limitBox.isFocused()) {
            String value = Long.toString(menu.getTransferLimit());
            if (!limitBox.getValue().equals(value)) limitBox.setValue(value);
        }
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        int accent = modeColor();

        floatingPanel(g, x + 5, y + 46, 180, 163, accent);

        if (dropdownOpen && (tab == Tab.GENERAL || tab == Tab.NETWORK)) return;

        if (tab == Tab.GENERAL) {
            drawField(g, x + 16, y + 131, 94, 22, SILVER);
            drawBar(g, x + 16, y + 181, 158, 4,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
            drawToggle(g, x + 147, y + 193, true, GREEN);
        } else if (tab == Tab.NETWORK) {
            drawField(g, x + 16, y + 105, 109, 22, SILVER);
            drawBar(g, x + 16, y + 163, 158, 4,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 16, y + 104, 158, 4,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
            drawBar(g, x + 16, y + 141, 158, 4,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        } else {
            drawToggle(g, x + 147, y + 99, true, GREEN);
            drawToggle(g, x + 147, y + 127, true, CYAN);
        }
    }

    private int modeColor() {
        return menu.getMode() == PlugMode.INPUT ? GREEN : menu.getMode() == PlugMode.OUTPUT ? ORANGE : SILVER;
    }

    private static void floatingPanel(GuiGraphics g, int x, int y, int w, int h, int border) {
        g.fill(x + 6, y, x + w - 6, y + h, PANEL);
        g.fill(x, y + 6, x + w, y + h - 6, PANEL);
        g.fill(x + 3, y + 3, x + w - 3, y + h - 3, PANEL_INNER);
        g.fill(x + 6, y, x + w - 6, y + 2, border);
        g.fill(x + 6, y + h - 2, x + w - 6, y + h, border);
        g.fill(x, y + 6, x + 2, y + h - 6, border);
        g.fill(x + w - 2, y + 6, x + w, y + h - 6, border);
        g.fill(x + 2, y + 2, x + 6, y + 4, border);
        g.fill(x + w - 6, y + 2, x + w - 2, y + 4, border);
        g.fill(x + 2, y + h - 4, x + 6, y + h - 2, border);
        g.fill(x + w - 6, y + h - 4, x + w - 2, y + h - 2, border);
    }

    private static void drawField(GuiGraphics g, int x, int y, int w, int h, int border) {
        g.fill(x + 2, y, x + w - 2, y + h, FIELD);
        g.fill(x, y + 2, x + w, y + h - 2, FIELD);
        g.fill(x + 2, y, x + w - 2, y + 1, border);
        g.fill(x + 2, y + h - 1, x + w - 2, y + h, border);
        g.fill(x, y + 2, x + 1, y + h - 2, border);
        g.fill(x + w - 1, y + 2, x + w, y + h - 2, border);
    }

    private static void drawToggle(GuiGraphics g, int x, int y, boolean enabled, int accent) {
        int knob = enabled ? accent : 0xFF666C72;
        g.fill(x + 2, y, x + 23, y + 10, 0xD0161A1E);
        g.fill(x, y + 2, x + 25, y + 8, 0xD0161A1E);
        g.fill(x + 2, y, x + 23, y + 1, 0xFFA8AEB4);
        g.fill(x + 2, y + 9, x + 23, y + 10, 0xFFA8AEB4);
        g.fill(x, y + 2, x + 1, y + 8, 0xFFA8AEB4);
        g.fill(x + 24, y + 2, x + 25, y + 8, 0xFFA8AEB4);
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
        g.drawString(font, "KIMI POWER PLUG", 16, 53, TEXT, false);
        g.drawString(font, "•", 166, 53, accent, false);

        if (dropdownOpen && (tab == Tab.GENERAL || tab == Tab.NETWORK)) return;

        if (tab == Tab.GENERAL) {
            g.drawString(font, "MODE", 16, 86, MUTED, false);
            g.drawString(font, "TRANSFER LIMIT", 16, 117, MUTED, false);
            g.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 98, 117, TEXT, false);
            g.drawString(font, "LIVE", 16, 158, MUTED, false);
            g.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 50, 158, accent, false);
            g.drawString(font, "BUFFER", 16, 171, MUTED, false);
            g.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 62, 171, TEXT, false);
            g.drawString(font, "CHUNK LOADING", 16, 193, MUTED, false);
        } else if (tab == Tab.NETWORK) {
            g.drawString(font, "CREATE NETWORK", 16, 96, MUTED, false);
            g.drawString(font, "PLUGS", 16, 137, MUTED, false);
            g.drawString(font, Integer.toString(menu.getPlugCount()), 164, 137, TEXT, false);
            g.drawString(font, "BUFFER", 16, 150, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 62, 150, TEXT, false);
            g.drawString(font, "SERVER-WIDE NETWORK", 16, 180, CYAN, false);
        } else if (tab == Tab.STATS) {
            g.drawString(font, "LIVE FLOW", 16, 72, MUTED, false);
            g.drawString(font, "+" + formatFe(menu.getNetworkInput()) + " / -" + formatFe(menu.getNetworkOutput()) + " FE/t", 16, 85, TEXT, false);
            g.drawString(font, "LOCAL BUFFER", 16, 95, MUTED, false);
            g.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 16, 111, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 16, 132, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 16, 149, TEXT, false);
            BlockPos pos = menu.getBlockPos();
            g.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 178, MUTED, false);
        } else {
            g.drawString(font, "PERIPHERAL", 16, 77, MUTED, false);
            g.drawString(font, "kimi_network_plug", 16, 90, TEXT, false);
            g.drawString(font, "CC:TWEAKED API", 16, 101, MUTED, false);
            g.drawString(font, "SERVER-WIDE REGISTRY", 16, 129, MUTED, false);
            g.drawString(font, "NETWORK", 16, 153, MUTED, false);
            g.drawString(font, menu.getNetworkName(), 74, 153, CYAN, false);
            g.drawString(font, "ONE PLUG = FULL POWERNET", 16, 178, TEXT, false);
            g.drawString(font, "LIST + CONTROL ALL REGISTERED PLUGS", 16, 191, MUTED, false);
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
        // No renderBackground(): the PowerNet card floats over the live world.
        super.render(g, mouseX, mouseY, partialTick);
        renderTooltip(g, mouseX, mouseY);
    }
}
