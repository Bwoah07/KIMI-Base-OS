package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractButton;
import net.minecraft.client.gui.narration.NarrationElementOutput;
import net.minecraft.network.chat.Component;

/** Flat PowerNet control used by every device screen. */
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

    public KimiUiButton accent(int color) { this.accent = color; return this; }
    public void setSelected(boolean selected) { this.selected = selected; }

    @Override public void onPress() { onPress.onPress(this); }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        int x = getX();
        int y = getY();
        int w = getWidth();
        int h = getHeight();
        boolean hot = isHoveredOrFocused();

        int bg = !active ? 0x50090B0E : selected ? 0xD414191E : hot ? 0xB8191E23 : 0x880B0F13;
        int line = selected ? accent : hot ? 0xFFB8BEC4 : 0xFF69727B;

        // Flat glass control: quiet fill, thin top/bottom rules, no chunky box frame.
        g.fill(x, y, x + w, y + h, bg);
        g.fill(x, y, x + w, y + 1, line);
        g.fill(x, y + h - 1, x + w, y + h, line);
        if (selected && !tab) g.fill(x, y + 2, x + 2, y + h - 2, accent);

        int color = active ? 0xFFF0F2F4 : 0xFF727980;
        g.drawCenteredString(net.minecraft.client.Minecraft.getInstance().font, getMessage(), x + w / 2, y + (h - 8) / 2, color);
    }

    @Override
    protected void updateWidgetNarration(NarrationElementOutput output) {
        defaultButtonNarrationText(output);
    }
}
