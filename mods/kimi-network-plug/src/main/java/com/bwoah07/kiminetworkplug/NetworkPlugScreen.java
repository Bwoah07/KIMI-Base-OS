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
    private static final int PANEL = 0xD9080A0D;
    private static final int PANEL_INNER = 0xA60D1014;
    private static final int SILVER = 0xFFD0D4D8;
    private static final int MUTED = 0xFF9DA5AD;
    private static final int TEXT = 0xFFF0F2F4;
    private static final int GREEN = 0xFF66E394;
    private static final int ORANGE = 0xFFFFA329;
    private static final int CYAN = 0xFF55D7E8;

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
    private KimiUiButton minusButton;
    private KimiUiButton setButton;
    private KimiUiButton plusButton;
    private KimiUiButton maxButton;
    private final List<KimiUiButton> networkOptions = new ArrayList<>();
    private EditBox limitBox;
    private EditBox newNetworkBox;
    private boolean dropdownOpen;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 204;
        imageHeight = 196;
        inventoryLabelY = 10_000;
        titleLabelY = 10_000;
    }

    @Override
    protected void init() {
        super.init();
        int x = leftPos;
        int y = topPos;

        generalTab = addRenderableWidget(new KimiUiButton(x + 12, y + 1, 34, 26, Component.literal("⌂"), true, b -> setTab(Tab.GENERAL)));
        networkTab = addRenderableWidget(new KimiUiButton(x + 51, y + 1, 34, 26, Component.literal("≡"), true, b -> setTab(Tab.NETWORK)));
        statsTab = addRenderableWidget(new KimiUiButton(x + 90, y + 1, 34, 26, Component.literal("▥"), true, b -> setTab(Tab.STATS)));
        kimiTab = addRenderableWidget(new KimiUiButton(x + 129, y + 1, 34, 26, Component.literal("K"), true, b -> setTab(Tab.KIMI)));

        offButton = addRenderableWidget(new KimiUiButton(x + 18, y + 75, 48, 18, Component.literal("OFF"), false, b -> sendButton(0)));
        inputButton = addRenderableWidget(new KimiUiButton(x + 78, y + 75, 48, 18, Component.literal("IN"), false, b -> sendButton(1)).accent(GREEN));
        outputButton = addRenderableWidget(new KimiUiButton(x + 138, y + 75, 48, 18, Component.literal("OUT"), false, b -> sendButton(2)).accent(ORANGE));

        minusButton = addRenderableWidget(new KimiUiButton(x + 18, y + 121, 22, 18, Component.literal("-"), false, b -> sendButton(10)));
        limitBox = new EditBox(font, x + 45, y + 121, 82, 18, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(14);
        limitBox.setValue(Long.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);
        setButton = addRenderableWidget(new KimiUiButton(x + 132, y + 121, 28, 18, Component.literal("SET"), false, b -> applyTypedLimit()));
        plusButton = addRenderableWidget(new KimiUiButton(x + 165, y + 121, 21, 18, Component.literal("+"), false, b -> sendButton(11)));
        maxButton = addRenderableWidget(new KimiUiButton(x + 138, y + 146, 48, 18, Component.literal("MAX"), false, b -> sendButton(13)).accent(ORANGE));

        networkSelector = addRenderableWidget(new KimiUiButton(x + 18, y + 76, 168, 20, Component.literal(menu.getNetworkName() + "  v"), false, b -> toggleDropdown()).accent(CYAN));
        newNetworkBox = new EditBox(font, x + 18, y + 119, 114, 18, Component.literal("New network"));
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(new KimiUiButton(x + 138, y + 119, 48, 18, Component.literal("CREATE"), false, b -> createNetwork()).accent(CYAN));

        for (int i = 0; i < NetworkPlugMenu.MAX_VISIBLE_NETWORKS; i++) {
            final int index = i;
            int col = i / 6;
            int row = i % 6;
            KimiUiButton option = addRenderableWidget(new KimiUiButton(x + 18 + col * 85, y + 101 + row * 17, 80, 16,
                    Component.empty(), false, b -> selectNetwork(index)).accent(CYAN));
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
        offButton.visible = general;
        inputButton.visible = general;
        outputButton.visible = general;
        minusButton.visible = general;
        limitBox.visible = general;
        setButton.visible = general;
        plusButton.visible = general;
        maxButton.visible = general;
        networkSelector.visible = network;
        newNetworkBox.visible = network && !dropdownOpen;
        createButton.visible = network && !dropdownOpen;
        syncDropdown();
    }

    private void syncDropdown() {
        List<String> names = menu.getNetworkNames();
        for (int i = 0; i < networkOptions.size(); i++) {
            KimiUiButton button = networkOptions.get(i);
            button.visible = tab == Tab.NETWORK && dropdownOpen && i < names.size();
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
        int accent = menu.getMode() == PlugMode.INPUT ? GREEN : menu.getMode() == PlugMode.OUTPUT ? ORANGE : SILVER;
        floatingPanel(g, x + 5, y + 21, imageWidth - 10, imageHeight - 26, accent);
        g.fill(x + 16, y + 49, x + imageWidth - 16, y + 50, 0x889AA1A8);
        if (tab == Tab.GENERAL) {
            drawBar(g, x + 18, y + 171, 168, 5, menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
        } else if (tab == Tab.NETWORK && !dropdownOpen) {
            drawBar(g, x + 18, y + 161, 168, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 18, y + 112, 168, 5, menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
            drawBar(g, x + 18, y + 143, 168, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, CYAN);
        }
    }

    private static void floatingPanel(GuiGraphics g, int x, int y, int w, int h, int border) {
        g.fill(x + 5, y, x + w - 5, y + h, PANEL);
        g.fill(x, y + 5, x + w, y + h - 5, PANEL);
        g.fill(x + 7, y + 7, x + w - 7, y + h - 7, PANEL_INNER);
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
        int modeColor = menu.getMode() == PlugMode.INPUT ? GREEN : menu.getMode() == PlugMode.OUTPUT ? ORANGE : MUTED;
        g.drawString(font, "KIMI POWER PLUG", 18, 34, TEXT, false);
        g.drawString(font, "•", 177, 34, modeColor, false);

        if (tab == Tab.GENERAL) {
            g.drawString(font, "MODE", 18, 59, MUTED, false);
            g.drawString(font, "TRANSFER LIMIT", 18, 104, MUTED, false);
            g.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 111, 104, TEXT, false);
            g.drawString(font, "LIVE", 18, 147, MUTED, false);
            g.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 55, 147, modeColor, false);
            g.drawString(font, "BUFFER  " + formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 18, 160, MUTED, false);
            g.drawString(font, "CHUNK LOADING", 18, 180, MUTED, false);
            g.drawString(font, "ON", 169, 180, GREEN, false);
        } else if (tab == Tab.NETWORK) {
            g.drawString(font, "NETWORK SELECTION", 18, 59, MUTED, false);
            if (!dropdownOpen) {
                g.drawString(font, "CREATE NETWORK", 18, 103, MUTED, false);
                g.drawString(font, "PLUGS", 18, 145, MUTED, false);
                g.drawString(font, Integer.toString(menu.getPlugCount()), 169, 145, TEXT, false);
                g.drawString(font, "BUFFER  " + formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 18, 171, MUTED, false);
            }
        } else if (tab == Tab.STATS) {
            g.drawString(font, "LIVE FLOW", 18, 60, MUTED, false);
            g.drawString(font, "+" + formatFe(menu.getNetworkInput()) + "  /  -" + formatFe(menu.getNetworkOutput()) + " FE/t", 18, 77, TEXT, false);
            g.drawString(font, "LOCAL BUFFER", 18, 99, MUTED, false);
            g.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 18, 119, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 18, 130, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 18, 150, TEXT, false);
            BlockPos pos = menu.getBlockPos();
            g.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 18, 173, MUTED, false);
        } else {
            g.drawString(font, "KIMI / COMPUTERCRAFT", 18, 61, MUTED, false);
            g.drawString(font, "Peripheral", 18, 84, MUTED, false);
            g.drawString(font, "kimi_network_plug", 18, 98, TEXT, false);
            g.drawString(font, "CC API", 18, 122, MUTED, false);
            g.drawString(font, "READY", 157, 122, GREEN, false);
            g.drawString(font, "PowerNet control", 18, 145, MUTED, false);
            g.drawString(font, "SERVER-WIDE", 118, 145, CYAN, false);
            g.drawString(font, "Network  " + menu.getNetworkName(), 18, 169, MUTED, false);
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
        // Intentionally do not call renderBackground(): the control card floats over the live world.
        super.render(g, mouseX, mouseY, partialTick);
        renderTooltip(g, mouseX, mouseY);
    }
}
