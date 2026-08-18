package com.bwoah07.kiminetworkplug;

import io.netty.buffer.ByteBuf;
import net.minecraft.core.BlockPos;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.neoforged.neoforge.network.event.RegisterPayloadHandlersEvent;
import net.neoforged.neoforge.network.handling.IPayloadContext;
import net.neoforged.neoforge.network.registration.PayloadRegistrar;

public final class NetworkPlugNetworking {
    private NetworkPlugNetworking() {
    }

    public static void register(RegisterPayloadHandlersEvent event) {
        PayloadRegistrar registrar = event.registrar("1");
        registrar.playToServer(NetworkNamePayload.TYPE, NetworkNamePayload.STREAM_CODEC, NetworkPlugNetworking::handleNetworkName);
    }

    private static void handleNetworkName(NetworkNamePayload payload, IPayloadContext context) {
        if (!(context.player() instanceof ServerPlayer player)) return;
        if (!(player.containerMenu instanceof NetworkPlugMenu)) return;

        BlockPos pos = new BlockPos(payload.x(), payload.y(), payload.z());
        if (player.distanceToSqr(pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5) > 64.0) return;

        BlockEntity blockEntity = player.level().getBlockEntity(pos);
        if (blockEntity instanceof NetworkPlugBlockEntity plug) {
            plug.setNetworkName(payload.name());
        }
    }

    public record NetworkNamePayload(int x, int y, int z, String name) implements CustomPacketPayload {
        public static final Type<NetworkNamePayload> TYPE = new Type<>(
                ResourceLocation.fromNamespaceAndPath(KimiNetworkPlug.MODID, "set_network_name")
        );

        public static final StreamCodec<ByteBuf, NetworkNamePayload> STREAM_CODEC = StreamCodec.composite(
                ByteBufCodecs.VAR_INT,
                NetworkNamePayload::x,
                ByteBufCodecs.VAR_INT,
                NetworkNamePayload::y,
                ByteBufCodecs.VAR_INT,
                NetworkNamePayload::z,
                ByteBufCodecs.STRING_UTF8,
                NetworkNamePayload::name,
                NetworkNamePayload::new
        );

        @Override
        public Type<? extends CustomPacketPayload> type() {
            return TYPE;
        }
    }
}
