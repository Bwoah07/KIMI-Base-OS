package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;

public final class NetworkPlugScreen extends AbstractContainerScreen<NetworkPlugMenu> {
    private Button disabledButton;
    private Button inputButton;
    private Button outputButton;
    private EditBox limitBox;

    public NetworkPlugScreen(NetworkPlugMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        this.imageWidth = 240;
        this.imageHeight = 164;
    }

    @Override
    protected void init() {
        super.init();

        int x = leftPos;
        int y = topPos;

        disabledButton = addRenderableWidget(Button.builder(Component.literal("DISABLED"), b -> sendButton(0))
                .bounds(x + 16, y + 40, 64, 20).build());
        inputButton = addRenderableWidget(Button.builder(Component.literal("INPUT"), b -> sendButton(1))
                .bounds(x + 88, y + 40, 64, 20).build());
        outputButton = addRenderableWidget(Button.builder(Component.literal("OUTPUT"), b -> sendButton(2))
                .bounds(x + 160, y + 40, 64, 20).build());

        addRenderableWidget(Button.builder(Component.literal("-"), b -> sendButton(10))
                .bounds(x + 16, y + 91, 24, 20).build());

        limitBox = new EditBox(font, x + 46, y + 91, 118, 20, Component.literal("Transfer limit"));
        limitBox.setFilter(value -> value.matches("\\d*"));
        limitBox.setMaxLength(10);
        limitBox.setValue(Integer.toString(Math.max(NetworkPlugBlockEntity.MIN_TRANSFER_LIMIT, menu.getTransferLimit())));
        addRenderableWidget(limitBox);

        addRenderableWidget(Button.builder(Component.literal("SET"), b -> applyTypedLimit())
                .bounds(x + 170, y + 91, 54, 20).build());

        addRenderableWidget(Button.builder(Component.literal("+"), b -> sendButton(11))
                .bounds(x + 16, y + 116, 24, 20).build());

        addRenderableWidget(Button.builder(Component.literal("MAX 2G"), b -> setLimit(NetworkPlugBlockEntity.MAX_TRANSFER_LIMIT))
                .bounds(x + 46, y + 116, 84, 20).build());

        addRenderableWidget(Button.builder(Component.literal("DEFAULT 16M"), b -> setLimit(NetworkPlugBlockEntity.DEFAULT_TRANSFER_LIMIT))
                .bounds(x + 136, y + 116, 88, 20).build());

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
        if (limitBox != null && !limitBox.isFocused()) {
            String synced = Integer.toString(menu.getTransferLimit());
            if (!limitBox.getValue().equals(synced)) limitBox.setValue(synced);
        }
    }

    @Override
    protected void renderBg(GuiGraphics graphics, float partialTick, int mouseX, int mouseY) {
        int x = leftPos;
        int y = topPos;
        graphics.fill(x, y, x + imageWidth, y + imageHeight, 0xEE10151B);
        graphics.fill(x + 6, y + 6, x + imageWidth - 6, y + 31, 0xFF1D2731);
        graphics.fill(x + 10, y + 68, x + imageWidth - 10, y + 146, 0xFF182028);
        graphics.fill(x + 12, y + 150, x + imageWidth - 12, y + 154, 0xFF273746);
    }

    @Override
    protected void renderLabels(GuiGraphics graphics, int mouseX, int mouseY) {
        graphics.drawString(font, "KIMI NETWORK PLUG", 14, 14, 0xFFE8F1F8, false);
        graphics.drawString(font, "MODE", 16, 31, 0xFF9DB0BF, false);
        graphics.drawString(font, "TRANSFER LIMIT  FE/t", 16, 72, 0xFF9DB0BF, false);

        String live = "LIVE  " + formatFe(menu.getLastTransfer()) + " FE/t";
        String buffer = "NETWORK BUFFER  " + String.format("%.1f%%", menu.getNetworkPermille() / 10.0);
        graphics.drawString(font, live, 16, 141, 0xFF8FD3A8, false);
        graphics.drawString(font, buffer, 130, 141, 0xFF9DB0BF, false);
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
