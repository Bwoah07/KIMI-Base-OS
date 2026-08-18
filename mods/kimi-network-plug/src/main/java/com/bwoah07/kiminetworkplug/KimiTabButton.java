package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

public final class KimiTabButton extends AbstractButton {
    public enum Icon { PLUG, NETWORK, STATS, KIMI }

    @FunctionalInterface
    public interface OnPress { void onPress(KimiTabButton button); }

    private final Icon icon;
    private final OnPress onPress;
    private boolean selected;

    public KimiTabButton(int x, int y, int width, int height, Component narration, Icon icon, OnPress onPress) {
        super(x, y, width, height, narration);
        this.icon = icon;
        this.onPress = onPress;
    }

    public void setSelected(boolean selected) {
        this.selected = selected;
    }

    @Override
    public void onPress() {
        onPress.onPress(this);
    }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        int x = getX();
        int y = getY();
        int w = getWidth();
        int h = getHeight();
        boolean hot = isHoveredOrFocused();

        int bg = selected ? 0xED11161B : hot ? 0xE8181E24 : 0xD90A0E12;
        int border = selected ? 0xFFF2F4F6 : hot ? 0xFFD1D6DB : 0xFF727A83;
        int iconColor = selected ? 0xFFF4F6F8 : hot ? 0xFFE2E6EA : 0xFFA9B0B7;

        // Compact floating cut-corner tab.
        g.fill(x + 3, y, x + w - 3, y + h, bg);
        g.fill(x, y + 3, x + w, y + h - 3, bg);
        g.fill(x + 3, y, x + w - 3, y + 1, border);
        g.fill(x + 3, y + h - 1, x + w - 3, y + h, border);
        g.fill(x, y + 3, x + 1, y + h - 3, border);
        g.fill(x + w - 1, y + 3, x + w, y + h - 3, border);
        g.fill(x + 1, y + 1, x + 3, y + 3, border);
        g.fill(x + w - 3, y + 1, x + w - 1, y + 3, border);
        g.fill(x + 1, y + h - 3, x + 3, y + h - 1, border);
        g.fill(x + w - 3, y + h - 3, x + w - 1, y + h - 1, border);

        int cx = x + w / 2;
        int cy = y + h / 2;
        switch (icon) {
            case PLUG -> drawPlug(g, cx, cy, iconColor);
            case NETWORK -> drawNetwork(g, cx, cy, iconColor);
            case STATS -> drawStats(g, cx, cy, iconColor);
            case KIMI -> drawK(g, cx, cy, iconColor);
        }
    }

    private static void drawPlug(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 5, cy - 4, cx + 3, cy + 5, c);
        g.fill(cx - 3, cy - 2, cx + 1, cy + 3, 0xFF0B0F13);
        g.fill(cx + 3, cy - 2, cx + 6, cy + 3, c);
        g.fill(cx + 6, cy - 1, cx + 8, cy + 2, c);
    }

    private static void drawNetwork(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 1, cy - 1, cx + 2, cy + 2, c);
        g.fill(cx - 7, cy - 6, cx - 4, cy - 3, c);
        g.fill(cx + 5, cy - 6, cx + 8, cy - 3, c);
        g.fill(cx - 7, cy + 4, cx - 4, cy + 7, c);
        g.fill(cx + 5, cy + 4, cx + 8, cy + 7, c);
        g.fill(cx - 5, cy - 4, cx - 1, cy - 3, c);
        g.fill(cx + 2, cy - 4, cx + 6, cy - 3, c);
        g.fill(cx - 5, cy + 4, cx - 1, cy + 5, c);
        g.fill(cx + 2, cy + 4, cx + 6, cy + 5, c);
        g.fill(cx - 1, cy - 4, cx, cy - 1, c);
        g.fill(cx + 1, cy + 2, cx + 2, cy + 5, c);
    }

    private static void drawStats(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 7, cy + 5, cx + 8, cy + 6, c);
        g.fill(cx - 6, cy, cx - 3, cy + 5, c);
        g.fill(cx - 1, cy - 4, cx + 2, cy + 5, c);
        g.fill(cx + 4, cy - 7, cx + 7, cy + 5, c);
    }

    private static void drawK(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 6, cy - 7, cx - 3, cy + 8, c);
        g.fill(cx - 3, cy - 1, cx, cy + 2, c);
        g.fill(cx, cy - 4, cx + 3, cy - 1, c);
        g.fill(cx + 3, cy - 7, cx + 6, cy - 4, c);
        g.fill(cx, cy + 2, cx + 3, cy + 5, c);
        g.fill(cx + 3, cy + 5, cx + 6, cy + 8, c);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
