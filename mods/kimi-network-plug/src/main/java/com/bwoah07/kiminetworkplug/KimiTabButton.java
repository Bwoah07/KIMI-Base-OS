package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

/** Compact PowerNet tab with deliberately simple, recognisable icons. */
public final class KimiTabButton extends AbstractButton {
    public enum Icon { PLUG, NETWORK, STATS, KIMI, CHARGER, TARGETS }

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

    public void setSelected(boolean selected) { this.selected = selected; }

    @Override public void onPress() { onPress.onPress(this); }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        int x = getX();
        int y = getY();
        int w = getWidth();
        int h = getHeight();
        boolean hot = isHoveredOrFocused();

        int bg = selected ? 0xF014191E : hot ? 0xE5161C22 : 0xDD0B0F13;
        int border = selected ? 0xFFF0F2F4 : hot ? 0xFFC8CDD2 : 0xFF666F78;
        int iconColor = selected ? 0xFFF4F6F8 : hot ? 0xFFDDE1E5 : 0xFFA8B0B8;

        // Quiet 2 px rounded-looking corners, no chunky Minecraft stone skin.
        g.fill(x + 3, y, x + w - 3, y + h, bg);
        g.fill(x + 1, y + 2, x + w - 1, y + h - 2, bg);
        g.fill(x, y + 4, x + w, y + h - 4, bg);
        g.fill(x + 4, y, x + w - 4, y + 1, border);
        g.fill(x + 4, y + h - 1, x + w - 4, y + h, border);
        g.fill(x, y + 4, x + 1, y + h - 4, border);
        g.fill(x + w - 1, y + 4, x + w, y + h - 4, border);
        g.fill(x + 1, y + 2, x + 2, y + 4, border);
        g.fill(x + w - 2, y + 2, x + w - 1, y + 4, border);
        g.fill(x + 1, y + h - 4, x + 2, y + h - 2, border);
        g.fill(x + w - 2, y + h - 4, x + w - 1, y + h - 2, border);

        int cx = x + w / 2;
        int cy = y + h / 2;
        switch (icon) {
            case PLUG -> drawPlug(g, cx, cy, iconColor);
            case NETWORK -> drawList(g, cx, cy, iconColor);
            case STATS -> drawStats(g, cx, cy, iconColor);
            case KIMI -> drawMonitor(g, cx, cy, iconColor);
            case CHARGER -> drawCharger(g, cx, cy, iconColor);
            case TARGETS -> drawTarget(g, cx, cy, iconColor);
        }
    }

    private static void drawPlug(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 6, cy - 5, cx + 1, cy + 6, c);
        g.fill(cx - 4, cy - 3, cx - 1, cy + 4, 0xFF0B0F13);
        g.fill(cx + 1, cy - 2, cx + 5, cy + 3, c);
        g.fill(cx + 5, cy - 1, cx + 8, cy, c);
        g.fill(cx + 5, cy + 2, cx + 8, cy + 3, c);
    }

    /** Clear list icon, intentionally matching the meaning of 'network list'. */
    private static void drawList(GuiGraphics g, int cx, int cy, int c) {
        for (int row = -5; row <= 5; row += 5) {
            g.fill(cx - 7, cy + row - 1, cx - 5, cy + row + 1, c);
            g.fill(cx - 2, cy + row - 1, cx + 8, cy + row + 1, c);
        }
    }

    private static void drawStats(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 7, cy + 6, cx + 8, cy + 7, c);
        g.fill(cx - 6, cy + 1, cx - 3, cy + 6, c);
        g.fill(cx - 1, cy - 3, cx + 2, cy + 6, c);
        g.fill(cx + 4, cy - 7, cx + 7, cy + 6, c);
    }

    private static void drawMonitor(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 7, cy - 6, cx + 8, cy + 4, c);
        g.fill(cx - 5, cy - 4, cx + 6, cy + 2, 0xFF0B0F13);
        g.fill(cx - 1, cy + 4, cx + 2, cy + 7, c);
        g.fill(cx - 5, cy + 7, cx + 6, cy + 8, c);
    }

    private static void drawCharger(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 7, cy - 5, cx + 6, cy + 6, c);
        g.fill(cx + 6, cy - 2, cx + 8, cy + 3, c);
        g.fill(cx - 5, cy - 3, cx + 4, cy + 4, 0xFF0B0F13);
        g.fill(cx - 1, cy - 2, cx + 2, cy + 3, c);
        g.fill(cx - 3, cy, cx + 4, cy + 1, c);
    }

    private static void drawTarget(GuiGraphics g, int cx, int cy, int c) {
        g.fill(cx - 6, cy - 1, cx + 7, cy + 2, c);
        g.fill(cx - 1, cy - 6, cx + 2, cy + 7, c);
        g.fill(cx - 3, cy - 3, cx + 4, cy + 4, 0xFF0B0F13);
        g.fill(cx - 1, cy - 1, cx + 2, cy + 2, c);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
