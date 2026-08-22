package com.bwoah07.kiminetworkplug;

/** Human-readable diagnostic for the stage currently limiting a Network Plug. */
public enum PowerBottleneck {
    NONE,
    SOURCE,
    NETWORK,
    TARGET,
    NO_BLOCK
}
