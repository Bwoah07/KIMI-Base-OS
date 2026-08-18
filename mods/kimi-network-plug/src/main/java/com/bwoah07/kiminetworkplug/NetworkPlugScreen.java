package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;
import net.neoforged.neoforge.network.PacketDistributor;

import java.util.ArrayList;
import java.util.List;

public final class NetworkPlugScreen extends AbstractContainerScreen<NetworkPlugMenu> {
    private static final int BG = 0xE8050709;
    private static final int FIELD = 0xD9111418;
    private static final int BORDER = 0xFFD3D6DA;
    private static final int MUTED = 0xFFA8ADB3;
    private static final int TEXT = 0xFFF2F3F4;
    private static final int GREEN = 0xFF64E889;
    private static final int ORANGE = 0xFFFFA323;
    private static final int RED = 0xFFD84A4A;
    private static final int BLUE = 0xFF58AEE8;

    private enum Tab { GENERAL, NETWORK, STATS, KIMI }
    private Tab tab = Tab.GENERAL;

    private Button tabGeneral, tabNetwork, tabStats, tabKimi;
    private Button disabledButton, inputButton, outputButton;
    private Button networkSelector, createButton;
    private Button minusButton, setLimitButton, plusButton, maxButton;
    private EditBox newNetworkBox, limitBox;
    private final List<Button> networkOptions = new ArrayList<>();
    private boolean networkDropdownOpen;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 176;
        imageHeight = 184;
        inventoryLabelY = 10_000;
        titleLabelY = 10_000;
    }

    @Override
    protected void init() {
        super.init();
        int x = leftPos;
        int y = topPos;

        tabGeneral = addRenderableWidget(Button.builder(Component.literal("G"), b -> setTab(Tab.GENERAL)).bounds(x + 10, y + 7, 28, 20).build());
        tabNetwork = addRenderableWidget(Button.builder(Component.literal("N"), b -> setTab(Tab.NETWORK)).bounds(x + 42, y + 7, 28, 20).build());
        tabStats = addRenderableWidget(Button.builder(Component.literal("S"), b -> setTab(Tab.STATS)).bounds(x + 74, y + 7, 28, 20).build());
        tabKimi = addRenderableWidget(Button.builder(Component.literal("K"), b -> setTab(Tab.KIMI)).bounds(x + 106, y + 7, 28, 20).build());

        disabledButton = addRenderableWidget(Button.builder(Component.literal("OFF"), b -> sendButton(0)).bounds(x + 16, y + 70, 42, 18).build());
        inputButton = addRenderableWidget(Button.builder(Component.literal("IN"), b -> sendButton(1)).bounds(x + 67, y + 70, 42, 18).build());
        outputButton = addRenderableWidget(Button.builder(Component.literal("OUT"), b -> sendButton(2)).bounds(x + 118, y + 70, 42, 18).build());

        minusButton = addRenderableWidget(Button.builder(Component.literal("-"), b -> sendButton(10)).bounds(x + 16, y + 112, 20, 18).build());
        limitBox = new EditBox(font, x + 40, y + 112, 78, 18, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(14);
        limitBox.setValue(Long.toString(menu.getTransferLimit()));
        addRenderableWidget(limitBox);
        setLimitButton = addRenderableWidget(Button.builder(Component.literal("SET"), b -> applyTypedLimit()).bounds(x + 122, y + 112, 38, 18).build());
        plusButton = addRenderableWidget(Button.builder(Component.literal("+"), b -> sendButton(11)).bounds(x + 16, y + 136, 20, 18).build());
        maxButton = addRenderableWidget(Button.builder(Component.literal("MAX"), b -> sendButton(13)).bounds(x + 122, y + 136, 38, 18).build());

        networkSelector = addRenderableWidget(Button.builder(Component.literal(menu.getNetworkName() + "  v"), b -> toggleNetworkDropdown())
                .bounds(x + 16, y + 68, 144, 20).build());
        newNetworkBox = new EditBox(font, x + 16, y + 111, 94, 18, Component.literal("New network"));
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(Button.builder(Component.literal("ADD"), b -> createNetwork()).bounds(x + 116, y + 111, 44, 18).build());

        for (int i = 0; i < NetworkPlugMenu.MAX_VISIBLE_NETWORKS; i++) {
            final int index = i;
            int col = i / 6;
            int row = i % 6;
            Button option = addRenderableWidget(Button.builder(Component.literal(""), b -> selectNetwork(index))
                    .bounds(x + 16 + col * 74, y + 91 + row * 17, 70, 16).build());
            option.visible = false;
            networkOptions.add(option);
        }

        updateVisibility();
        syncWidgets();
    }

    private void setTab(Tab next) {
        tab = next;
        networkDropdownOpen = false;
        updateVisibility();
        syncWidgets();
    }

    private void sendButton(int id) {
        if (minecraft != null && minecraft.gameMode != null) minecraft.gameMode.handleInventoryButtonClick(menu.containerId, id);
    }

    private void toggleNetworkDropdown() {
        networkDropdownOpen = !networkDropdownOpen;
        updateVisibility();
        syncDropdown();
    }

    private void selectNetwork(int index) {
        sendButton(100 + index);
        networkDropdownOpen = false;
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
            BlockPos pos = menu.getBlockPos();
            PacketDistributor.sendToServer(new NetworkPlugNetworking.TransferLimitPayload(pos.getX(), pos.getY(), pos.getZ(), value));
            limitBox.setValue(Long.toString(value));
        } catch (NumberFormatException ignored) {
            limitBox.setValue(Long.toString(menu.getTransferLimit()));
        }
    }

    private void updateVisibility() {
        boolean general = tab == Tab.GENERAL;
        boolean network = tab == Tab.NETWORK;
        disabledButton.visible = general;
        inputButton.visible = general;
        outputButton.visible = general;
        minusButton.visible = general;
        limitBox.visible = general;
        setLimitButton.visible = general;
        plusButton.visible = general;
        maxButton.visible = general;
        networkSelector.visible = network;
        newNetworkBox.visible = network && !networkDropdownOpen;
        createButton.visible = network && !networkDropdownOpen;
        syncDropdown();
    }

    private void syncWidgets() {
        PlugMode mode = menu.getMode();
        disabledButton.active = mode != PlugMode.DISABLED;
        inputButton.active = mode != PlugMode.INPUT;
        outputButton.active = mode != PlugMode.OUTPUT;
        networkSelector.setMessage(Component.literal(menu.getNetworkName() + "  v"));
        tabGeneral.active = tab != Tab.GENERAL;
        tabNetwork.active = tab != Tab.NETWORK;
        tabStats.active = tab != Tab.STATS;
        tabKimi.active = tab != Tab.KIMI;
        syncDropdown();
    }

    private void syncDropdown() {
        List<String> names = menu.getNetworkNames();
        for (int i = 0; i < networkOptions.size(); i++) {
            Button button = networkOptions.get(i);
            button.visible = tab == Tab.NETWORK && networkDropdownOpen && i < names.size();
            if (i < names.size()) button.setMessage(Component.literal(names.get(i)));
        }
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        syncWidgets();
        if (limitBox != null && !limitBox.isFocused()) limitBox.setValue(Long.toString(menu.getTransferLimit()));
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        int accent = switch (menu.getMode()) { case INPUT -> GREEN; case OUTPUT -> ORANGE; case DISABLED -> RED; };

        g.fill(x + 4, y + 31, x + imageWidth - 4, y + imageHeight - 4, BG);
        outline(g, x + 4, y + 31, imageWidth - 8, imageHeight - 35, accent);
        g.fill(x + 12, y + 40, x + imageWidth - 12, y + 60, FIELD);
        g.fill(x + 12, y + 63, x + imageWidth - 12, y + imageHeight - 12, 0xB006090C);

        if (tab == Tab.GENERAL) {
            outline(g, x + 15, y + 67, 146, 24, BORDER);
            outline(g, x + 15, y + 108, 146, 24, BORDER);
            drawBar(g, x + 16, y + 163, 144, 5, menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
        } else if (tab == Tab.NETWORK) {
            outline(g, x + 15, y + 65, 146, 26, BORDER);
            if (!networkDropdownOpen) outline(g, x + 15, y + 108, 146, 24, BORDER);
            drawBar(g, x + 16, y + 163, 144, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, BLUE);
        } else if (tab == Tab.STATS) {
            drawBar(g, x + 18, y + 95, 140, 5, menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, accent);
            drawBar(g, x + 18, y + 128, 140, 5, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, BLUE);
        }
    }

    private static void outline(GuiGraphics g, int x, int y, int w, int h, int c) {
        g.fill(x, y, x + w, y + 1, c); g.fill(x, y + h - 1, x + w, y + h, c);
        g.fill(x, y, x + 1, y + h, c); g.fill(x + w - 1, y, x + w, y + h, c);
    }

    private static void drawBar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        g.fill(x, y, x + w, y + h, 0xFF252B31);
        int filled = (int)Math.round(w * fraction);
        if (filled > 0) g.fill(x, y, x + filled, y + h, color);
    }

    @Override
    protected void renderLabels(GuiGraphics g, int mouseX, int mouseY) {
        int accent = switch (menu.getMode()) { case INPUT -> GREEN; case OUTPUT -> ORANGE; case DISABLED -> RED; };
        g.drawString(font, "KIMI POWER PLUG", 16, 46, TEXT, false);
        g.drawString(font, "●", 149, 46, accent, false);

        if (tab == Tab.GENERAL) {
            g.drawString(font, "MODE", 16, 62, MUTED, false);
            g.drawString(font, "TRANSFER LIMIT", 16, 102, MUTED, false);
            g.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 76, 139, TEXT, false);
            g.drawString(font, "LIVE", 16, 139, MUTED, false);
            g.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 16, 151, accent, false);
            g.drawString(font, "BUFFER " + formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 16, 171, MUTED, false);
        } else if (tab == Tab.NETWORK) {
            g.drawString(font, "NETWORK", 16, 62, MUTED, false);
            if (!networkDropdownOpen) {
                g.drawString(font, "CREATE", 16, 104, MUTED, false);
                g.drawString(font, "PLUGS " + menu.getPlugCount(), 16, 143, MUTED, false);
                g.drawString(font, "BUFFER " + formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 16, 171, TEXT, false);
            }
        } else if (tab == Tab.STATS) {
            g.drawString(font, "LOCAL BUFFER", 18, 72, MUTED, false);
            g.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 18, 84, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 18, 105, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 18, 117, TEXT, false);
            g.drawString(font, "+" + formatFe(menu.getNetworkInput()) + " / -" + formatFe(menu.getNetworkOutput()) + " FE/t", 18, 140, MUTED, false);
            BlockPos p = menu.getBlockPos();
            g.drawString(font, "X " + p.getX() + "  Y " + p.getY() + "  Z " + p.getZ(), 18, 154, MUTED, false);
        } else {
            g.drawString(font, "KIMI LINK", 18, 72, MUTED, false);
            g.drawString(font, "ONLINE", 120, 72, GREEN, false);
            g.drawString(font, "PERIPHERAL", 18, 94, MUTED, false);
            g.drawString(font, "kimi_network_plug", 18, 108, TEXT, false);
            g.drawString(font, "NETWORK", 18, 132, MUTED, false);
            g.drawString(font, menu.getNetworkName(), 18, 146, TEXT, false);
            g.drawString(font, "CHUNK LOADED", 18, 164, GREEN, false);
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
