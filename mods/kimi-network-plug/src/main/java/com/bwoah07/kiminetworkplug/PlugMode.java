package com.bwoah07.kiminetworkplug;

import net.minecraft.util.StringRepresentable;

public enum PlugMode implements StringRepresentable {
    DISABLED("disabled"),
    INPUT("input"),
    OUTPUT("output");

    private final String serializedName;

    PlugMode(String serializedName) {
        this.serializedName = serializedName;
    }

    public PlugMode next() {
        return switch (this) {
            case DISABLED -> INPUT;
            case INPUT -> OUTPUT;
            case OUTPUT -> DISABLED;
        };
    }

    @Override
    public String getSerializedName() {
        return serializedName;
    }
}
