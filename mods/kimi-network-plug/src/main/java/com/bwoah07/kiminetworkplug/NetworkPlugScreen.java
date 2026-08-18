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
    private Button disabledButton;
    private Button inputButton;
    private Button outputButton;
    private EditBox networkBox;
    private EditBox limitBox;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        this.imageWidth = 286;
        this.imageHeight = 224;
    }

    @Override
    protected void init() {
        super.init();

        int x = leftPos;
        int y = topPos;

        disabledButton = addRenderableWidget(Button.builder(Component.literal("DISABLED"), b -> sendButton(0))
                .bounds(x + 16, y + 39, 78, 20).build());
        inputButton = addRenderableWidget(Button.builder(Component.literal("INPUT"), b -> sendButton(1))
                .bounds(x + 104, y + 39, 78, 20).build());
        outputButton = addRenderableWidget(Button.builder(Component.literal("OUTPUT"), b -> sendButton(2))
                .bounds(x + 192, y + 39, 78, 20).build());

        addRenderableWidget(Button.builder(Component.literal("<"), b -> sendButton(20))
                .bounds(x + 16, y + 78, 24, 20).build());

        networkBox = new EditBox(font, x + 46, y + 78, 150, 20, Component.literal("Network"));
        networkBox.setFilter(value -> value.matches("[A-Za-z0-9_-]*"));
        networkBox.setMaxLength(PowerNetworkSavedData.MAX_NETWORK_NAME_LENGTH);
        networkBox.setValue(menu.getNetworkName());
        addRenderableWidget(networkBox);

        addRenderableWidget(Button.builder(Component.literal("SET / CREATE"), b -> applyNetwork())
                .bounds(x + 202, y + 78, 68, 20).build());

        addRenderableWidget(Button.builder(Component.literal(">"), b -> sendButton(21))
                .bounds(x + 246, y + 102, 24, 18).build());

        addRenderableWidget(Button.builder(Component.literal("-"), b -> sendButton(10))
                .bounds(x + 16, y + 122, 24, 20).build());

        limitBox = new EditBox(font, x + 46, y + 122, 105, 20, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(10);
        limitBox.setValue(Integer.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);

        addRenderableWidget(Button.builder(Component.literal("SET"), b -> applyTypedLimit())
                .bounds(x + 157, y + 122, 42, 20).build());

        addRenderableWidget(Button.builder(Component.literal("+"), b -> sendButton(11))
                .bounds(x + 205, y + 122, 24, 20).build());

        addRenderableWidget(Button.builder(Component.literal("16M"), b -> setLimit(NetworkPlugBlockEntity.DEFAULT_TRANSFER_LIMIT))
                .bounds(x + 235, y + 122, 35, 20).build());

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
        networkBox.setValue(name.toUpperCase());

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

        graphics.fill(x, y, x + imageWidth, y + imageHeight, 0xF20B1015);
        graphics.fill(x + 1, y + 1, x + imageWidth - 1, y + 30, 0xFF1A2530);
        graphics.fill(x + 10, y + 33, x + imageWidth - 10, y + 63, 0xFF111820);
        graphics.fill(x + 10, y + 67, x + imageWidth - 10, y + 103, 0xFF111820);
        graphics.fill(x + 10, y + 108, x + imageWidth - 10, y + 148, 0xFF111820);
        graphics.fill(x + 10, y + 154, x + imageWidth - 10, y + 214, 0xFF111820);

        drawBar(graphics, x + 17, y + 184, 116, 8,
                menu.getLocalEnergy() / (double) NetworkPlugBlockEntity.LOCAL_BUFFER_CAPACITY,
                0xFF55C987);
        drawBar(graphics, x + 151, y + 184, 118, 8,
                menu.getNetworkEnergy() / (double) PowerNetworkSavedData.NETWORK_CAPACITY,
                0xFF53A8E8);
    }

    private static void drawBar(GuiGraphics graphics, int x, int y, int width, int height, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        graphics.fill(x, y, x + width, y + height, 0xFF25313B);
        int filled = (int) Math.round(width * fraction);
        if (filled > 0) graphics.fill(x, y, x + filled, y + height, color);
    }

    @Override
    protected void renderLabels(GuiGraphics graphics, int mouseX, int mouseY) {
        graphics.drawString(font, "KIMI NETWORK PLUG", 14, 11, 0xFFEAF4FB, false);
        graphics.drawString(font, "● CHUNK LOADED", 184, 11, 0xFF61D78D, false);

        graphics.drawString(font, "MODE", 16, 30, 0xFF8EA2B2, false);
        graphics.drawString(font, "NETWORK", 16, 66, 0xFF8EA2B2, false);
        graphics.drawString(font, "< / > CYCLE EXISTING NETWORKS", 46, 103, 0xFF718696, false);
        graphics.drawString(font, "TRANSFER LIMIT", 16, 109, 0xFF8EA2B2, false);
        graphics.drawString(font, formatFe(menu.getTransferLimit()) + " FE/t", 167, 109, 0xFFE0E8EE, false);

        int liveColor = switch (menu.getMode()) {
            case INPUT -> 0xFF61D78D;
            case OUTPUT -> 0xFFFFA34D;
            case DISABLED -> 0xFF8A98A3;
        };
        graphics.drawString(font, "LIVE", 16, 158, 0xFF8EA2B2, false);
        graphics.drawString(font, formatFe(menu.getLastTransfer()) + " FE/t", 51, 158, liveColor, false);
        graphics.drawString(font, "PLUGS  " + menu.getPlugCount(), 194, 158, 0xFFD8E2E9, false);

        graphics.drawString(font, "LOCAL BUFFER", 16, 171, 0xFF8EA2B2, false);
        graphics.drawString(font, formatFe(menu.getLocalEnergy()) + " / 64M", 16, 195, 0xFFD8E2E9, false);

        graphics.drawString(font, "NETWORK BUFFER", 150, 171, 0xFF8EA2B2, false);
        graphics.drawString(font, formatFe(menu.getNetworkEnergy()) + " / 64M", 150, 195, 0xFFD8E2E9, false);

        String flow = "+" + formatFe(menu.getNetworkInput()) + "  /  -" + formatFe(menu.getNetworkOutput());
        graphics.drawString(font, flow + " FE/t", 150, 207, 0xFF9FB3C2, false);

        BlockPos pos = menu.getBlockPos();
        graphics.drawString(font, "X " + pos.getX() + "  Y " + pos.getY() + "  Z " + pos.getZ(), 16, 207, 0xFF718696, false);
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
