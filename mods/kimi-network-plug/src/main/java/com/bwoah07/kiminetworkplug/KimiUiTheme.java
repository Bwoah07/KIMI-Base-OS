package com.bwoah07.kiminetworkplug;

import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;

/** Shared visual language for every KIMI PowerNet screen. */
public final class KimiUiTheme {
    public static final int PANEL = 0xE10A0E12;
    public static final int INNER = 0xC711161C;
    public static final int FIELD = 0xD00B0F13;
    public static final int SILVER = 0xFFD2D7DC;
    public static final int SILVER_DIM = 0xFF717A83;
    public static final int TEXT = 0xFFF2F4F6;
    public static final int MUTED = 0xFFA0A8B0;
    public static final int GREEN = 0xFF62E38D;
    public static final int ORANGE = 0xFFFFA33C;
    public static final int CYAN = 0xFF54CBD8;
    public static final int WARN = 0xFFFFC15C;

    private KimiUiTheme() {}

    public static void roundedRect(GuiGraphics g, int x, int y, int w, int h, int radius, int color) {
        if (w <= 0 || h <= 0) return;
        radius = Math.max(0, Math.min(radius, Math.min(w, h) / 2));
        if (radius <= 1) {
            g.fill(x, y, x + w, y + h, color);
            return;
        }
        double r = radius - 0.5;
        for (int row = 0; row < h; row++) {
            int inset = 0;
            if (row < radius) {
                double dy = r - row;
                inset = Math.max(0, radius - (int) Math.floor(Math.sqrt(Math.max(0.0, r * r - dy * dy))));
            } else if (row >= h - radius) {
                double dy = row - (h - radius) + 0.5;
                inset = Math.max(0, radius - (int) Math.floor(Math.sqrt(Math.max(0.0, r * r - dy * dy))));
            }
            g.fill(x + inset, y + row, x + w - inset, y + row + 1, color);
        }
    }

    public static void panel(GuiGraphics g, int x, int y, int w, int h) {
        roundedRect(g, x, y, w, h, 9, SILVER);
        roundedRect(g, x + 1, y + 1, w - 2, h - 2, 8, PANEL);
        roundedRect(g, x + 4, y + 4, w - 8, h - 8, 6, INNER);
    }

    public static void field(GuiGraphics g, int x, int y, int w, int h) {
        roundedRect(g, x, y, w, h, 5, SILVER_DIM);
        roundedRect(g, x + 1, y + 1, w - 2, h - 2, 4, FIELD);
    }

    public static void listPanel(GuiGraphics g, int x, int y, int w, int h) {
        roundedRect(g, x, y, w, h, 6, SILVER_DIM);
        roundedRect(g, x + 1, y + 1, w - 2, h - 2, 5, 0xA50A0E12);
    }

    public static void bar(GuiGraphics g, int x, int y, int w, int h, double fraction, int color) {
        fraction = Math.max(0.0, Math.min(1.0, fraction));
        roundedRect(g, x, y, w, h, Math.max(2, h / 2), 0xCC30373E);
        int filled = (int) Math.round(w * fraction);
        if (filled > 0) roundedRect(g, x, y, Math.max(h, filled), h, Math.max(2, h / 2), color);
    }

    public static void toggle(GuiGraphics g, int x, int y, boolean enabled, int accent) {
        roundedRect(g, x, y, 25, 11, 6, 0xFF636C74);
        roundedRect(g, x + 1, y + 1, 23, 9, 5, 0xFF171C21);
        int knobX = enabled ? x + 14 : x + 2;
        roundedRect(g, knobX, y + 2, 9, 7, 4, enabled ? accent : 0xFF7B838A);
    }

    public static void text(GuiGraphics g, Font font, String text, float x, float y, int color, float scale) {
        g.pose().pushPose();
        g.pose().scale(scale, scale, 1.0f);
        g.drawString(font, text, Math.round(x / scale), Math.round(y / scale), color, false);
        g.pose().popPose();
    }

    public static void rightText(GuiGraphics g, Font font, String text, float right, float y, int color, float scale) {
        float width = font.width(text) * scale;
        text(g, font, text, right - width, y, color, scale);
    }

    public static void centeredText(GuiGraphics g, Font font, String text, float centerX, float y, int color, float scale) {
        float width = font.width(text) * scale;
        text(g, font, text, centerX - width / 2.0f, y, color, scale);
    }

    public static String fit(Font font, String text, int maxWidth, float scale) {
        if (text == null || text.isBlank()) return "No block";
        int allowed = Math.max(1, Math.round(maxWidth / scale));
        if (font.width(text) <= allowed) return text;
        String ellipsis = "...";
        int ellipsisWidth = font.width(ellipsis);
        String cut = font.plainSubstrByWidth(text, Math.max(1, allowed - ellipsisWidth));
        return cut + ellipsis;
    }
}
