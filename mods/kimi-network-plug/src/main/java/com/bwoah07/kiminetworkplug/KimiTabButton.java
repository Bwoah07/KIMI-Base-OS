package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

/** Shared compact tab used by every PowerNet device. */
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
        boolean hot = isHoveredOrFocused();
        int bg = selected ? 0xF0181E24 : hot ? 0xE71A2026 : 0xE00C1116;
        int border = selected ? KimiUiTheme.TEXT : hot ? KimiUiTheme.SILVER : KimiUiTheme.SILVER_DIM;
        int iconColor = selected ? KimiUiTheme.TEXT : hot ? 0xFFDDE2E6 : 0xFFADB5BC;

        KimiUiTheme.roundedRect(g, getX(), getY(), getWidth(), getHeight(), 6, border);
        KimiUiTheme.roundedRect(g, getX() + 1, getY() + 1, getWidth() - 2, getHeight() - 2, 5, bg);

        int cx = getX() + getWidth() / 2;
        int cy = getY() + getHeight() / 2;
        switch (icon) {
            case PLUG -> drawPlug(g, cx, cy, iconColor);
            case NETWORK -> drawList(g, cx, cy, iconColor);
            case STATS -> drawStats(g, cx, cy, iconColor);
            case KIMI -> drawMonitor(g, cx, cy, iconColor);
            case CHARGER -> drawCharger(g, cx, cy, iconColor);
            case TARGETS -> drawTargets(g, cx, cy, iconColor);
        }
    }

    private static void drawPlug(GuiGraphics g, int cx, int cy, int c) {
        KimiUiTheme.roundedRect(g, cx - 7, cy - 5, 10, 10, 2, c);
        KimiUiTheme.roundedRect(g, cx - 5, cy - 3, 6, 6, 1, 0xFF0D1217);
        g.fill(cx + 3, cy - 2, cx + 7, cy + 2, c);
        g.fill(cx + 7, cy - 1, cx + 9, cy, c);
        g.fill(cx + 7, cy + 1, cx + 9, cy + 2, c);
    }

    private static void drawList(GuiGraphics g, int cx, int cy, int c) {
        for (int row = -6; row <= 6; row += 6) {
            KimiUiTheme.roundedRect(g, cx - 8, cy + row - 1, 3, 3, 1, c);
            KimiUiTheme.roundedRect(g, cx - 3, cy + row - 1, 12, 3, 1, c);
        }
    }

    private static void drawStats(GuiGraphics g, int cx, int cy, int c) {
        KimiUiTheme.roundedRect(g, cx - 8, cy + 3, 4, 6, 1, c);
        KimiUiTheme.roundedRect(g, cx - 2, cy - 2, 4, 11, 1, c);
        KimiUiTheme.roundedRect(g, cx + 4, cy - 7, 4, 16, 1, c);
    }

    private static void drawMonitor(GuiGraphics g, int cx, int cy, int c) {
        KimiUiTheme.roundedRect(g, cx - 8, cy - 6, 16, 11, 2, c);
        KimiUiTheme.roundedRect(g, cx - 6, cy - 4, 12, 7, 1, 0xFF0D1217);
        g.fill(cx - 1, cy + 5, cx + 2, cy + 8, c);
        g.fill(cx - 5, cy + 8, cx + 6, cy + 9, c);
    }

    private static void drawCharger(GuiGraphics g, int cx, int cy, int c) {
        KimiUiTheme.roundedRect(g, cx - 8, cy - 5, 16, 10, 3, c);
        KimiUiTheme.roundedRect(g, cx - 6, cy - 3, 12, 6, 2, 0xFF0D1217);
        g.fill(cx - 1, cy - 4, cx + 2, cy + 4, c);
        g.fill(cx - 4, cy - 1, cx + 5, cy + 2, c);
    }

    private static void drawTargets(GuiGraphics g, int cx, int cy, int c) {
        KimiUiTheme.roundedRect(g, cx - 8, cy - 8, 16, 16, 8, c);
        KimiUiTheme.roundedRect(g, cx - 6, cy - 6, 12, 12, 6, 0xFF0D1217);
        KimiUiTheme.roundedRect(g, cx - 3, cy - 3, 6, 6, 3, c);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
