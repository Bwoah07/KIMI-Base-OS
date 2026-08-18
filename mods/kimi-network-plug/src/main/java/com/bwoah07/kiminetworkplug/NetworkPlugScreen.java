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
    private static final int PANEL_BG = 0xF20A0D11;
    private static final int HEADER_BG = 0xFF151A20;
    private static final int BODY_BG = 0xFF0C1015;
    private static final int CARD_BG = 0xFF11171D;
    private static final int BORDER = 0xFF9AA1A8;
    private static final int TEXT = 0xFFE8EDF1;
    private static final int MUTED = 0xFF929CA5;
    private static final int GREEN = 0xFF62E58E;
    private static final int ORANGE = 0xFFFFA13A;
    private static final int BLUE = 0xFF59AEEA;
    private static final int TAB_ACTIVE = 0xFF2A3139;

    private enum Tab { HOME, NETWORK, KIMI }
    private Tab tab = Tab.HOME;

    private Button homeTab;
    private Button networkTab;
    private Button kimiTab;
    private Button disabledButton;
    private Button inputButton;
    private Button outputButton;
    private Button networkSelector;
    private Button createButton;
    private Button minusButton;
    private Button setLimitButton;
    private Button plusButton;
    private Button maxButton;
    private final List<Button> networkOptions = new ArrayList<>();
    private EditBox newNetworkBox;
    private EditBox limitBox;
    private boolean networkDropdownOpen;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
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

        homeTab = addRenderableWidget(Button.builder(Component.literal("HOME"), b -> setTab(Tab.HOME)).bounds(x + 10, y + 29, 54, 18).build());
        networkTab = addRenderableWidget(Button.builder(Component.literal("NETWORK"), b -> setTab(Tab.NETWORK)).bounds(x + 69, y + 29, 66, 18).build());
        kimiTab = addRenderableWidget(Button.builder(Component.literal("KIMI"), b -> setTab(Tab.KIMI)).bounds(x + 140, y + 29, 46, 18).build());

        disabledButton = addRenderableWidget(Button.builder(Component.literal("OFF"), b -> sendButton(0)).bounds(x + 12, y + 61, 52, 18).build());
        inputButton = addRenderableWidget(Button.builder(Component.literal("INPUT"), b -> sendButton(1)).bounds(x + 72, y + 61, 52, 18).build());
        outputButton = addRenderableWidget(Button.builder(Component.literal("OUTPUT"), b -> sendButton(2)).bounds(x + 132, y + 61, 52, 18).build());

        minusButton = addRenderableWidget(Button.builder(Component.literal("-"), b -> sendButton(10)).bounds(x + 12, y + 104, 20, 18).build());
        limitBox = new EditBox(font, x + 37, y + 104, 82, 18, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(14);
        limitBox.setValue(Long.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);
        setLimitButton = addRenderableWidget(Button.builder(Component.literal("SET"), b -> applyTypedLimit()).bounds(x + 124, y + 104, 30, 18).build());
        plusButton = addRenderableWidget(Button.builder(Component.literal("+"), b -> sendButton(11)).bounds(x + 159, y + 104, 25, 18).build());
        maxButton = addRenderableWidget(Button.builder(Component.literal("MAX"), b -> sendButton(13)).bounds(x + 132, y + 128, 52, 18).build());

        networkSelector = addRenderableWidget(Button.builder(Component.literal(menu.getNetworkName() + "  v"), b -> toggleNetworkDropdown())
                .bounds(x + 12, y + 64, 172, 20).build());
        newNetworkBox = new EditBox(font, x + 12, y + 105, 118, 18, Component.literal("New network"));
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(Button.builder(Component.literal("CREATE"), b -> createNetwork()).bounds(x + 136, y + 105, 48, 18).build());

        for (int i = 0; i < NetworkPlugMenu.MAX_VISIBLE_NETWORKS; i++) {
            final int index = i;
            int col = i / 5;
            int row = i % 5;
            Button option = addRenderableWidget(Button.builder(Component.literal(""), b -> selectNetwork(index))
                    .bounds(x + 12 + col * 87, y + 86 + row * 17, 83, 16).build());
            option.visible = false;
            networkOptions.add(option);
        }

        syncWidgets();
        updateVisibility();
    }

    private void setTab(Tab newTab) {
        tab = newTab;
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
        if (disabledButton != null) disabledButton.active = mode != PlugMode.DISABLED;
        if (inputButton != null) inputButton.active = mode != PlugMode.INPUT;
        if (outputButton != null) outputButton.active = mode != PlugMode.OUTPUT;
        if (networkSelector != null) networkSelector.setMessage(Component.literal(menu.getNetworkName() + "  v"));
        syncDropdown();
    }

    private void updateVisibility() {
        boolean home = tab == Tab.HOME;
        boolean network = tab == Tab.NETWORK;
        disabledButton.visible = home;
        inputButton.visible = home;
        outputButton.visible = home;
        minusButton.visible = home;
        limitBox.visible = home;
        setLimitButton.visible = home;
        plusButton.visible = home;
        maxButton.visible = home;

        networkSelector.visible = network;
        newNetworkBox.visible = network && !networkDropdownOpen;
        createButton.visible = network && !networkDropdownOpen;
        syncDropdown();
    }

    private void syncDropdown() {
        List<String> names = menu.getNetworkNames();
        for (int i = 0; i < networkOptions.size(); i++) {
            Button button = networkOptions.get(i);
            button.visible = tab == Tab.NETWORK && networkDropdownOpen && i < names.size();
            if (i < names.size()) button.setMessage(Component.literal(names.get(i)));
        }
        if (newNetworkBox != null) newNetworkBox.visible = tab == Tab.NETWORK && !networkDropdownOpen;
        if (createButton != null) createButton.visible = tab == Tab.NETWORK && !networkDropdownOpen;
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        syncWidgets();
        if (limitBox != null && !limitBox.isFocused()) {
            String synced = Long.toString(menu.getTransferLimit());
            if (!limitBox.getValue().equals(synced)) limitBox.setValue(synced);
        }
    }

    @Override
    protected void renderBg(GuiGraphics g, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        g.fill(x, y, x + imageWidth, y + imageHeight, PANEL_BG);
        outline(g, x, y, imageWidth, imageHeight, BORDER);
        g.fill(x + 1, y + 1, x + imageWidth - 1, y + 25, HEADER_BG);
        g.fill(x + 7, y + 52, x + imageWidth - 7, y + imageHeight - 8, BODY_BG);
        drawTabAccent(g, x, y);

        if (tab == Tab.HOME) {
            g.fill(x + 10, y + 55, x + 186, y + 84, CARD_BG);
            g.fill(x + 10, y + 91, x + 186, y + 151, CARD_BG);
            drawBar(g, x + 12, y + 156, 172, 5,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY,
                    menu.getMode() == PlugMode.OUTPUT ? ORANGE : GREEN);
        } else if (tab == Tab.NETWORK) {
            g.fill(x + 10, y + 55, x + 186, y + 91, CARD_BG);
            if (!networkDropdownOpen) g.fill(x + 10, y + 97, x + 186, y + 133, CARD_BG);
            drawBar(g, x + 12, y + 151, 172, 5,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, BLUE);
        } else {
            g.fill(x + 10, y + 55, x + 186, y + 158, CARD_BG);
            drawBar(g, x + 18, y + 82, 160, 5,
                    menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, GREEN);
            drawBar(g, x + 18, y + 112, 160, 5,
                    menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, BLUE);
        }
    }

    private void drawTabAccent(GuiGraphics g, int x, int y) {
        int sx = switch (tab) { case HOME -> x + 10; case NETWORK -> x + 69; case KIMI -> x + 140; };
        int ex = switch (tab) { case HOME -> x + 64; case NETWORK -> x + 135; case KIMI -> x + 186; };
        g.fill(sx, y + 47, ex, y + 49, TAB_ACTIVE);
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
        g.drawString(font, "KIMI POWER PLUG", 10, 9, TEXT, false);
        g.drawString(font, "●", 174, 9, GREEN, false);

        if (tab == Tab.HOME) {
            int modeColor = switch (menu.getMode()) { case INPUT -> GREEN; case OUTPUT -> ORANGE; case DISABLED -> MUTED; };
            g.drawString(font, "MODE", 12, 53, MUTED, false);
            g.drawString(font, menu.getMode().name(), 140, 53, modeColor, false);
            g.drawString(font, "TRANSFER", 12, 91, MUTED, false);
            g.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 104, 91, TEXT, false);
            g.drawString(font, "LIVE  " + formatFe(menu.getLastTransfer()) + " FE/t", 12, 130, modeColor, false);
            g.drawString(font, "LOCAL  " + formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 12, 143, MUTED, false);
            g.drawString(font, "CHUNKLOAD ON", 12, 163, GREEN, false);
        } else if (tab == Tab.NETWORK) {
            g.drawString(font, "SELECT NETWORK", 12, 53, MUTED, false);
            if (!networkDropdownOpen) {
                g.drawString(font, "CREATE NEW", 12, 97, MUTED, false);
                g.drawString(font, "PLUGS  " + menu.getPlugCount(), 12, 137, MUTED, false);
                g.drawString(font, "BUFFER  " + formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 12, 160, TEXT, false);
            }
        } else {
            g.drawString(font, "KIMI LINK", 16, 59, MUTED, false);
            g.drawString(font, "ONLINE", 141, 59, GREEN, false);
            g.drawString(font, "LOCAL BUFFER", 16, 73, MUTED, false);
            g.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 16, 90, TEXT, false);
            g.drawString(font, "NETWORK BUFFER", 16, 103, MUTED, false);
            g.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 16, 120, TEXT, false);
            g.drawString(font, "+" + formatFe(menu.getNetworkInput()) + " / -" + formatFe(menu.getNetworkOutput()) + " FE/t", 16, 133, MUTED, false);
            BlockPos pos = menu.getBlockPos();
            g.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 147, MUTED, false);
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
