package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

/**
 * Purpose-built PowerNet control. It intentionally avoids Minecraft's stone
 * button skin so every PowerNet screen keeps the same thin floating-tech look.
 */
public final class KimiUiButton extends AbstractButton {
    @FunctionalInterface
    public interface OnPress { void onPress(KimiUiButton button); }

    private final OnPress onPress;
    private final boolean tab;
    private int accent = 0xFFCFD3D8;
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

        int bg;
        int border;
        if (!active) {
            bg = 0x6E090B0E;
            border = 0xFF555B62;
        } else if (tab) {
            bg = selected ? 0xE414181D : (hot ? 0xC812161B : 0xA8080B0F);
            border = selected ? 0xFFF1F3F5 : (hot ? 0xFFD6DADF : 0xFF777F88);
        } else {
            bg = selected ? 0xC914191E : (hot ? 0xB814181D : 0x8F090C10);
            border = selected ? accent : (hot ? 0xFFD8DDE1 : 0xFF7D858E);
        }

        // One-pixel cut corners: visually rounded at Minecraft scale, but much
        // thinner and quieter than a vanilla button.
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

        if (selected && !tab) {
            g.fill(x + 2, y + 2, x + 4, y + h - 2, accent);
        }

        int color = active ? 0xFFF0F2F4 : 0xFF727980;
        g.drawCenteredString(net.minecraft.client.Minecraft.getInstance().font, getMessage(), x + w / 2, y + (h - 8) / 2, color);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
