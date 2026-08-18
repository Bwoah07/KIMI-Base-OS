package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;
import net.neoforged.neoforge.network.PacketDistributor;

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
    private EditBox networkBox;
    private EditBox limitBox;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        this.imageWidth = 270;
        this.imageHeight = 232;
        this.inventoryLabelY = 10_000;
        this.titleLabelY = 10_000;
    }

    @Override
    protected void init() {
        super.init();

        int x = leftPos;
        int y = topPos;

        disabledButton = addRenderableWidget(Button.builder(Component.literal("DISABLED"), b -> sendButton(0))
                .bounds(x + 16, y + 42, 72, 20).build());
        inputButton = addRenderableWidget(Button.builder(Component.literal("INPUT"), b -> sendButton(1))
                .bounds(x + 99, y + 42, 72, 20).build());
        outputButton = addRenderableWidget(Button.builder(Component.literal("OUTPUT"), b -> sendButton(2))
                .bounds(x + 182, y + 42, 72, 20).build());

        addRenderableWidget(Button.builder(Component.literal("<"), b -> sendButton(20))
                .bounds(x + 16, y + 88, 22, 20).build());

        networkBox = new EditBox(font, x + 44, y + 88, 132, 20, Component.literal("Network"));
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);

        addRenderableWidget(Button.builder(Component.literal(">"), b -> sendButton(21))
                .bounds(x + 182, y + 88, 22, 20).build());

        addRenderableWidget(Button.builder(Component.literal("APPLY"), b -> applyNetwork())
                .bounds(x + 210, y + 88, 44, 20).build());

        addRenderableWidget(Button.builder(Component.literal("-"), b -> sendButton(10))
                .bounds(x + 16, y + 134, 22, 20).build());

        limitBox = new EditBox(font, x + 44, y + 134, 98, 20, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(10);
        limitBox.setValue(Integer.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);

        addRenderableWidget(Button.builder(Component.literal("SET"), b -> applyTypedLimit())
                .bounds(x + 148, y + 134, 40, 20).build());

        addRenderableWidget(Button.builder(Component.literal("+"), b -> sendButton(11))
                .bounds(x + 194, y + 134, 22, 20).build());

        addRenderableWidget(Button.builder(Component.literal("16M"), b -> setLimit(NetworkPlugBlockEntity.DEFAULT_TRANSFER_LIMIT))
                .bounds(x + 222, y + 134, 32, 20).build());

        syncButtonStates();
    }

    private void sendButton(int id) {
        if (minecraft != null && minecraft.gameMode != null) {
            minecraft.gameMode.handleInventoryButtonClick(menu.containerId, id);
        }
    }

    private void setLimit(int value) {
        if (limitBox != null) limitBox.setValue(Integer.toString(value));
        sendButton(-value);
    }

    private void applyTypedLimit() {
        if (limitBox == null) return;
        try {
            int value = Integer.parseInt(limitBox.getValue());
            value = Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT,
                    Math.min(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT, value));
            limitBox.setValue(Integer.toString(value));
            sendButton(-value);
        } catch (NumberFormatException ignored) {
            limitBox.setValue(Integer.toString(menu.getTransferLimit()));
        }
    }

    private void applyNetwork() {
        if (networkBox == null) return;
        String name = networkBox.getValue();
        if (name.isBlank()) name = PowerNetworkSavedData.DEFAULT_NETWORK;
        name = name.toUpperCase();
        networkBox.setValue(name);

        BlockPos pos = menu.getBlockPos();
        PacketDistributor.sendToServer(new NetworkPlugNetworking.NetworkNamePayload(
                pos.getX(), pos.getY(), pos.getZ(), name
        ));
    }

    private void syncButtonStates() {
        PlugMode mode = menu.getMode();
        if (disabledButton != null) disabledButton.active = mode != PlugMode.DISABLED;
        if (inputButton != null) inputButton.active = mode != PlugMode.INPUT;
        if (outputButton != null) outputButton.active = mode != PlugMode.OUTPUT;
    }

    @Override
    protected void containerTick() {
        super.containerTick();
        syncButtonStates();

        if (networkBox != null && !networkBox.isFocused()) {
            String synced = menu.getNetworkName();
            if (!networkBox.getValue().equals(synced)) networkBox.setValue(synced);
        }

        if (limitBox != null && !limitBox.isFocused()) {
            String synced = Integer.toString(menu.getTransferLimit());
            if (!limitBox.getValue().equals(synced)) limitBox.setValue(synced);
        }
    }

    @Override
    protected void renderBg(GuiGraphics graphics, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;

        // Main card and thin outline.
        graphics.fill(x, y, x + imageWidth, y + imageHeight, PANEL_BG);
        outline(graphics, x, y, imageWidth, imageHeight, BORDER);

        // Header.
        graphics.fill(x + 1, y + 1, x + imageWidth - 1, y + 29, HEADER_BG);

        // Three clean content bands. Widgets sit inside these rather than colliding with labels.
        graphics.fill(x + 10, y + 34, x + imageWidth - 10, y + 66, SECTION_BG);
        graphics.fill(x + 10, y + 74, x + imageWidth - 10, y + 112, SECTION_BG);
        graphics.fill(x + 10, y + 120, x + imageWidth - 10, y + 158, SECTION_BG);
        graphics.fill(x + 10, y + 166, x + imageWidth - 10, y + 222, SECTION_BG);

        drawBar(graphics, x + 16, y + 194, 112, 7,
                menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY,
                GREEN);
        drawBar(graphics, x + 142, y + 194, 112, 7,
                menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY,
                BLUE);
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

        graphics.drawString(font, "TRANSFER LIMIT", 16, 118, MUTED, false);
        graphics.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 176, 118, TEXT, false);

        int liveColor = switch (menu.getMode()) {
            case INPUT -> GREEN;
            case OUTPUT -> ORANGE;
            case DISABLED -> MUTED;
        };
        graphics.drawString(font, "LIVE", 16, 170, MUTED, false);
        graphics.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 48, 170, liveColor, false);

        String netFlow = "+" + formatFe(menu.getNetworkInput()) + " / -" + formatFe(menu.getNetworkOutput()) + " FE/t";
        graphics.drawString(font, netFlow, 142, 170, MUTED, false);

        graphics.drawString(font, "LOCAL BUFFER", 16, 182, MUTED, false);
        graphics.drawString(font, "NETWORK BUFFER", 142, 182, MUTED, false);

        graphics.drawString(font,
                formatFe(menu.getLocalEnergy()) + " / " + formatFe(NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY),
                16, 204, TEXT, false);
        graphics.drawString(font,
                formatFe(menu.getNetworkEnergy()) + " / " + formatFe(PowerNetworkSavedData.NETWORK_CAPACITY),
                142, 204, TEXT, false);

        BlockPos pos = menu.getBlockPos();
        graphics.drawString(font,
                "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(),
                16, 216, MUTED, false);
    }

    private static String formatFe(long value) {
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
