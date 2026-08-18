package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

public final class KimiUiButton extends AbstractButton {
    @FunctionalInterface
    public interface OnPress { void onPress(KimiUiButton button); }

    private final OnPress onPress;
    private final boolean tab;
    private int accent = 0xFFB9C0C8;
    private boolean selected;

    public KimiUiButton(int x, int y, int width, int height, Component message, boolean tab, OnPress onPress) {
        super(x, y, width, height, message);
        this.tab = tab;
        this.onPress = onPress;
    }

    public KimiUiButton accent(int color) {
        this.accent = color;
        return this;
    }

    public void setSelected(boolean selected) { this.selected = selected; }

    @Override
    public void onPress() { onPress.onPress(this); }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        int x = getX();
        int y = getY();
        int w = getWidth();
        int h = getHeight();
        boolean hot = isHoveredOrFocused();
        int bg = tab ? (selected ? 0xF0181D23 : 0xD00B0E12) : (hot ? 0xE020252B : 0xD00D1116);
        int border = selected ? accent : (hot ? 0xFFE2E6EA : 0xFF8D959E);
        if (!active) {
            bg = 0xA0080A0D;
            border = 0xFF555B62;
        }

        // Cut-corner panel: reads rounded at Minecraft scale without a texture asset.
        g.fill(x + 2, y, x + w - 2, y + h, bg);
        g.fill(x, y + 2, x + w, y + h - 2, bg);
        g.fill(x + 2, y, x + w - 2, y + 1, border);
        g.fill(x + 2, y + h - 1, x + w - 2, y + h, border);
        g.fill(x, y + 2, x + 1, y + h - 2, border);
        g.fill(x + w - 1, y + 2, x + w, y + h - 2, border);
        g.fill(x + 1, y + 1, x + 2, y + 2, border);
        g.fill(x + w - 2, y + 1, x + w - 1, y + 2, border);
        g.fill(x + 1, y + h - 2, x + 2, y + h - 1, border);
        g.fill(x + w - 2, y + h - 2, x + w - 1, y + h - 1, border);

        int color = active ? 0xFFF1F3F5 : 0xFF777D84;
        g.drawCenteredString(net.minecraft.client.Minecraft.getInstance().font, getMessage(), x + w / 2, y + (h - 8) / 2, color);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
