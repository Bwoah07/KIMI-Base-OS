package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

/** Flux-style row toggle: label on the left, switch on the right. */
public final class KimiToggleButton extends AbstractButton {
    @FunctionalInterface
    public interface OnPress { void onPress(KimiToggleButton button); }

    private final OnPress onPress;
    private int accent = KimiUiTheme.CYAN;
    private boolean selected;

    public KimiToggleButton(int x, int y, int width, int height, Component message, OnPress onPress) {
        super(x, y, width, height, message);
        this.onPress = onPress;
    }

    public KimiToggleButton accent(int color) { this.accent = color; return this; }
    public void setSelected(boolean selected) { this.selected = selected; }
    public boolean isSelected() { return selected; }
    @Override public void onPress() { onPress.onPress(this); }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        boolean hot = isHoveredOrFocused();
        int border = hot ? KimiUiTheme.SILVER : KimiUiTheme.SILVER_DIM;
        int bg = hot ? 0xC3181D22 : 0xA20B0F13;
        KimiUiTheme.roundedRect(g, getX(), getY(), getWidth(), getHeight(), 5, border);
        KimiUiTheme.roundedRect(g, getX() + 1, getY() + 1, getWidth() - 2, getHeight() - 2, 4, bg);
        KimiUiTheme.text(g, net.minecraft.client.Minecraft.getInstance().font, getMessage().getString(),
                getX() + 8, getY() + 5, KimiUiTheme.TEXT, 0.82f);
        KimiUiTheme.toggle(g, getX() + getWidth() - 34, getY() + 4, selected, accent);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
