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
    private static final int HEADER_BG = 0xFF171D24;
    private static final int SECTION_BG = 0xFF10151B;
    private static final int BORDER = 0xFF68717A;
    private static final int TEXT = 0xFFE8EDF1;
    private static final int MUTED = 0xFF929CA5;
    private static final int GREEN = 0xFF65D98A;
    private static final int ORANGE = 0xFFFFA342;
    private static final int BLUE = 0xFF5AA9E6;

    private Button disabledButton;
    private Button inputButton;
    private Button outputButton;
    private Button networkSelector;
    private Button createButton;
    private final List<Button> networkOptions = new ArrayList<>();
    private EditBox newNetworkBox;
    private EditBox limitBox;
    private boolean networkDropdownOpen;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 270;
        imageHeight = 252;
        inventoryLabelY = 10_000;
        titleLabelY = 10_000;
    }

    @Override
    protected void init() {
        super.init();
        int x = leftPos;
        int y = topPos;

        disabledButton = addRenderableWidget(Button.builder(Component.literal("DISABLED"), b -> sendButton(0)).bounds(x + 16, y + 42, 72, 20).build());
        inputButton = addRenderableWidget(Button.builder(Component.literal("INPUT"), b -> sendButton(1)).bounds(x + 99, y + 42, 72, 20).build());
        outputButton = addRenderableWidget(Button.builder(Component.literal("OUTPUT"), b -> sendButton(2)).bounds(x + 182, y + 42, 72, 20).build());

        networkSelector = addRenderableWidget(Button.builder(Component.literal(menu.getNetworkName() + "  v"), b -> toggleNetworkDropdown())
                .bounds(x + 16, y + 86, 238, 20).build());

        newNetworkBox = new EditBox(font, x + 16, y + 111, 180, 18, Component.literal("New network"));
        newNetworkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        newNetworkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        newNetworkBox.setHint(Component.literal("NEW NETWORK NAME"));
        addRenderableWidget(newNetworkBox);
        createButton = addRenderableWidget(Button.builder(Component.literal("CREATE"), b -> createNetwork()).bounds(x + 202, y + 110, 52, 20).build());

        for (int i = 0; i < NetworkPlugMenu.MAX_VISIBLE_NETWORKS; i++) {
            final int index = i;
            int col = i / 6;
            int row = i % 6;
            Button option = addRenderableWidget(Button.builder(Component.literal(""), b -> selectNetwork(index))
                    .bounds(x + 16 + col * 120, y + 110 + row * 19, 116, 18).build());
            option.visible = false;
            networkOptions.add(option);
        }

        addRenderableWidget(Button.builder(Component.literal("-"), b -> sendButton(10)).bounds(x + 16, y + 157, 22, 20).build());
        limitBox = new EditBox(font, x + 44, y + 157, 112, 20, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(12);
        limitBox.setValue(Long.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);
        addRenderableWidget(Button.builder(Component.literal("SET"), b -> applyTypedLimit()).bounds(x + 162, y + 157, 40, 20).build());
        addRenderableWidget(Button.builder(Component.literal("+"), b -> sendButton(11)).bounds(x + 208, y + 157, 22, 20).build());
        addRenderableWidget(Button.builder(Component.literal("MAX"), b -> sendButton(13)).bounds(x + 234, y + 157, 28, 20).build());

        syncWidgets();
    }

    private void sendButton(int id) {
        if (minecraft != null && minecraft.gameMode != null) minecraft.gameMode.handleInventoryButtonClick(menu.containerId, id);
    }

    private void toggleNetworkDropdown() {
        networkDropdownOpen = !networkDropdownOpen;
        syncDropdown();
    }

    private void selectNetwork(int index) {
        sendButton(100 + index);
        networkDropdownOpen = false;
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

    private void syncDropdown() {
        List<String> names = menu.getNetworkNames();
        for (int i = 0; i < networkOptions.size(); i++) {
            Button button = networkOptions.get(i);
            button.visible = networkDropdownOpen && i < names.size();
            if (i < names.size()) button.setMessage(Component.literal(names.get(i)));
        }
        if (newNetworkBox != null) newNetworkBox.visible = !networkDropdownOpen;
        if (createButton != null) createButton.visible = !networkDropdownOpen;
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
    protected void renderBg(GuiGraphics graphics, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        graphics.fill(x, y, x + imageWidth, y + imageHeight, PANEL_BG);
        outline(graphics, x, y, imageWidth, imageHeight, BORDER);
        graphics.fill(x + 1, y + 1, x + imageWidth - 1, y + 29, HEADER_BG);
        graphics.fill(x + 10, y + 34, x + imageWidth - 10, y + 66, SECTION_BG);
        graphics.fill(x + 10, y + 74, x + imageWidth - 10, y + 136, SECTION_BG);
        graphics.fill(x + 10, y + 144, x + imageWidth - 10, y + 182, SECTION_BG);
        graphics.fill(x + 10, y + 190, x + imageWidth - 10, y + 242, SECTION_BG);

        drawBar(graphics, x + 16, y + 218, 112, 7, menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY, GREEN);
        drawBar(graphics, x + 142, y + 218, 112, 7, menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY, BLUE);
    }

    private static void outline(GuiGraphics graphics, int x, int y, int width, int height, int color) {
        graphics.fill(x, y, x + width, y + 1, color);
        graphics.fill(x, y + height - 1, x + width, y + height, color);
        graphics.fill(x, y, x + 1, y + height, color);
        graphics.fill(x + width - 1, y, x + width, y + height, color);
    }

    private static void drawBar(GuiGraphics graphics, int x, int y, int width, int height, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        graphics.fill(x, y, x + width, y + height, 0xFF273039);
        int filled = (int) Math.round(width * fraction);
        if (filled > 0) graphics.fill(x, y, x + filled, y + height, color);
    }

    @Override
    protected void renderLabels(GuiGraphics graphics, int mouseX, int mouseY) {
        graphics.drawString(font, "KIMI NETWORK PLUG", 14, 11, TEXT, false);
        graphics.drawString(font, "CHUNK LOADED", 190, 11, GREEN, false);
        graphics.drawString(font, "MODE", 16, 32, MUTED, false);
        graphics.drawString(font, "NETWORK", 16, 72, MUTED, false);
        graphics.drawString(font, "PLUGS " + menu.getPlugCount(), 208, 72, MUTED, false);
        if (!networkDropdownOpen) graphics.drawString(font, "Create a new network or pick one from the list", 16, 132, 0xFF6F7D88, false);

        graphics.drawString(font, "TRANSFER LIMIT", 16, 142, MUTED, false);
        graphics.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 166, 142, TEXT, false);

        int liveColor = switch (menu.getMode()) {
            case INPUT -> GREEN;
            case OUTPUT -> ORANGE;
            case DISABLED -> MUTED;
        };
        graphics.drawString(font, "LIVE", 16, 194, MUTED, false);
        graphics.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 48, 194, liveColor, false);
        String netFlow = "+" + formatFe(menu.getNetworkInput()) + " / -" + formatFe(menu.getNetworkOutput()) + " FE/t";
        graphics.drawString(font, netFlow, 142, 194, MUTED, false);

        graphics.drawString(font, "LOCAL BUFFER", 16, 206, MUTED, false);
        graphics.drawString(font, "NETWORK BUFFER", 142, 206, MUTED, false);
        graphics.drawString(font, formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY), 16, 229, TEXT, false);
        graphics.drawString(font, formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY), 142, 229, TEXT, false);
        BlockPos pos = menu.getBlockPos();
        graphics.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 241, MUTED, false);
    }

    private static String formatFe(long value) {
        if (value >= 1_000_000_000_000L) return String.format("%.2fT", value / 1_000_000_000_000.0);
        if (value >= 1_000_000_000L) return String.format("%.2fG", value / 1_000_000_000.0);
        if (value >= 1_000_000L) return String.format("%.2fM", value / 1_000_000.0);
        if (value >= 1_000L) return String.format("%.1fk", value / 1_000.0);
        return Long.toString(value);
    }

    @Override
    public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
        renderBackground(graphics, mouseX, mouseY, partialTick);
        super.render(graphics, mouseX, mouseY, partialTick);
        renderTooltip(graphics, mouseX, mouseY);
    }
}
