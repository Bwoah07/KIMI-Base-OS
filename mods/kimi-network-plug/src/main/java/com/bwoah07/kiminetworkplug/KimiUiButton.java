package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

/** Rounded low-profile PowerNet control used by every device screen. */
public final class KimiUiButton extends AbstractButton {
    @FunctionalInterface
    public interface OnPress { void onPress(KimiUiButton button); }

    private final OnPress onPress;
    private final boolean tab;
    private int accent = KimiUiTheme.SILVER;
    private boolean selected;

    public KimiUiButton(int x, int y, int width, int height, Component message, boolean tab, OnPress onPress) {
        super(x, y, width, height, message);
        this.tab = tab;
        this.onPress = onPress;
    }

    public KimiUiButton accent(int color) { this.accent = color; return this; }
    public void setSelected(boolean selected) { this.selected = selected; }
    @Override public void onPress() { onPress.onPress(this); }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        boolean hot = isHoveredOrFocused();
        int bg = !active ? 0x70090B0E : selected ? 0xE014191E : hot ? 0xC8191E23 : 0xA20B0F13;
        int border = !active ? 0xFF4C535A : selected ? accent : hot ? 0xFFB8BEC4 : KimiUiTheme.SILVER_DIM;

        KimiUiTheme.roundedRect(g, getX(), getY(), getWidth(), getHeight(), 5, border);
        KimiUiTheme.roundedRect(g, getX() + 1, getY() + 1, getWidth() - 2, getHeight() - 2, 4, bg);
        if (selected && !tab) {
            KimiUiTheme.roundedRect(g, getX() + 2, getY() + 3, 2, Math.max(3, getHeight() - 6), 1, accent);
        }

        int color = active ? KimiUiTheme.TEXT : 0xFF727980;
        KimiUiTheme.centeredText(g, net.minecraft.client.Minecraft.getInstance().font,
                getMessage().getString(), getX() + getWidth() / 2.0f,
                getY() + (getHeight() - 7.0f) / 2.0f, color, 0.82f);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
